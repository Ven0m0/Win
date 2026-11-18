#Requires -Version 5.1

<#
.SYNOPSIS
  Benchmarks DNS resolvers (Cloudflare, Cloudflare Malware, AdGuard DNS) over IPv4 and IPv6.
.DESCRIPTION
  Times Resolve-DnsName for every server x domain x round. One extra warm-up round per server is
  run first and not counted, so results reflect the resolver cache rather than cold recursion.
  Failed queries are counted, not fatal; a server with no successful query is reported as
  'unreachable'. Read-only: no admin, no system changes. Returns objects sorted by median.
.PARAMETER Domain
  Domains to resolve. Defaults to ten popular domains.
.PARAMETER Rounds
  Measured rounds per domain (excludes the warm-up round). Default 5.
.PARAMETER Server
  Override the built-in server list with custom IPv4/IPv6 addresses (Provider = 'Custom').
.PARAMETER AddServer
  Extra resolver addresses benchmarked in addition to the built-in list (Provider = 'Custom').
.PARAMETER PassThru
  Also emit the per-server result objects to the pipeline (the tables are always printed).
.EXAMPLE
  .\dns-benchmark.ps1
.EXAMPLE
  .\dns-benchmark.ps1 -AddServer 9.9.9.9, 2620:fe::fe
.EXAMPLE
  .\dns-benchmark.ps1 -Rounds 2 -PassThru | Export-Csv dns.csv -NoTypeInformation
.EXAMPLE
  .\dns-benchmark.ps1 -Server 9.9.9.9, 2620:fe::fe -Domain example.com
#>
[CmdletBinding()]
param(
  [string[]]$Domain = @(
    'google.com', 'youtube.com', 'facebook.com', 'amazon.com', 'wikipedia.org',
    'reddit.com', 'github.com', 'microsoft.com', 'netflix.com', 'cloudflare.com'
  ),
  [ValidateRange(1, 100)][int]$Rounds = 5,
  [ValidateScript({ [System.Net.IPAddress]::TryParse($_, [ref]$null) })][string[]]$Server,
  [ValidateScript({ [System.Net.IPAddress]::TryParse($_, [ref]$null) })][string[]]$AddServer,
  [switch]$PassThru
)

. "$PSScriptRoot\Common.ps1"

$script:DefaultServers = @(
  @{ Provider = 'Cloudflare'; Address = '1.1.1.1' }
  @{ Provider = 'Cloudflare'; Address = '1.0.0.1' }
  @{ Provider = 'Cloudflare'; Address = '2606:4700:4700::1111' }
  @{ Provider = 'Cloudflare'; Address = '2606:4700:4700::1001' }
  @{ Provider = 'Cloudflare Malware'; Address = '1.1.1.2' }
  @{ Provider = 'Cloudflare Malware'; Address = '1.0.0.2' }
  @{ Provider = 'Cloudflare Malware'; Address = '2606:4700:4700::1112' }
  @{ Provider = 'Cloudflare Malware'; Address = '2606:4700:4700::1002' }
  @{ Provider = 'AdGuard DNS'; Address = '94.140.14.14' }
  @{ Provider = 'AdGuard DNS'; Address = '94.140.15.15' }
  @{ Provider = 'AdGuard DNS'; Address = '2a10:50c0::ad1:ff' }
  @{ Provider = 'AdGuard DNS'; Address = '2a10:50c0::ad2:ff' }
)


function Get-LatencyStats {
  [CmdletBinding()]
  param([double[]]$Time)

  if (-not $Time) { return $null }
  $s = $Time | Sort-Object
  $mid = [int][math]::Floor($s.Count / 2)
  $median = if ($s.Count % 2) { $s[$mid] } else { ($s[$mid - 1] + $s[$mid]) / 2 }
  [pscustomobject]@{
    MinMs = [math]::Round($s[0], 1)
    MedianMs = [math]::Round($median, 1)
    AvgMs = [math]::Round(($s | Measure-Object -Average).Average, 1)
    MaxMs = [math]::Round($s[-1], 1)
  }
}


# One row per provider: raw samples of all its servers (IPv4 + IPv6) pooled, so the median is exact.
function Get-ProviderSummary {
  [CmdletBinding()]
  param([Parameter(Mandatory)][object[]]$Result)

  $Result | Group-Object -Property Provider | ForEach-Object {
    $pooled = @($_.Group | ForEach-Object { $_.Samples })
    $stats = Get-LatencyStats -Time $pooled
    [pscustomobject][ordered]@{
      Provider = $_.Name
      MinMs = $stats.MinMs
      MedianMs = $stats.MedianMs
      AvgMs = $stats.AvgMs
      MaxMs = $stats.MaxMs
    }
  } | Sort-Object @{ Expression = { $null -eq $_.MedianMs } }, MedianMs
}


function Measure-DnsServer {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Provider,
    [Parameter(Mandatory)][string]$Address,
    [Parameter(Mandatory)][string[]]$Domain,
    [int]$Rounds = 5
  )

  $isV6 = [System.Net.IPAddress]::Parse($Address).AddressFamily -eq 'InterNetworkV6'
  $family = if ($isV6) { 'IPv6' } else { 'IPv4' }
  $query = @{
    Server = $Address
    Type = 'A'
    DnsOnly = $true
    NoHostsFile = $true
    ErrorAction = 'Stop'
    QuickTimeout = $true  # Resolve-DnsName has no timeout param; this is its only (~1 s) limit
  }

  $times = [System.Collections.Generic.List[double]]::new()
  $fail = 0
  $total = 0
  foreach ($round in 0..$Rounds) {
    foreach ($d in $Domain) {
      $sw = [System.Diagnostics.Stopwatch]::StartNew()
      $ok = $true
      try { $null = Resolve-DnsName -Name $d @query } catch { $ok = $false }
      $sw.Stop()
      if ($round -eq 0) { continue }  # warm-up, not counted
      $total++
      if ($ok) { $times.Add($sw.Elapsed.TotalMilliseconds) } else { $fail++ }
    }
  }

  $stats = Get-LatencyStats -Time $times
  [pscustomobject][ordered]@{
    Provider = $Provider
    Server = $Address
    Family = $family
    MinMs = $stats.MinMs
    MedianMs = $stats.MedianMs
    AvgMs = $stats.AvgMs
    MaxMs = $stats.MaxMs
    FailPct = [math]::Round(100 * $fail / [math]::Max($total, 1), 1)
    Status = $(if ($stats) { 'ok' } else { 'unreachable' })
    Samples = $times.ToArray()
  }
}


function Invoke-DnsBenchmark {
  [CmdletBinding()]
  param([string[]]$Domain, [int]$Rounds, [string[]]$Server, [string[]]$AddServer)

  $custom = @(
    @($Server) + @($AddServer) | Where-Object { $_ } | ForEach-Object {
      @{ Provider = 'Custom'; Address = $_ }
    }
  )
  $targets = if ($Server) { $custom } else { @($script:DefaultServers) + $custom }
  $results = foreach ($t in $targets) {
    Write-Info "Testing $($t.Provider) $($t.Address)"
    $r = Measure-DnsServer -Provider $t.Provider -Address $t.Address -Domain $Domain -Rounds $Rounds
    if ($r.Status -eq 'unreachable') { Write-Warn "$($t.Address) unreachable (no IPv6 route?)" }
    $r
  }
  # Unreachable rows (null median) sort last.
  $results | Sort-Object @{ Expression = { $null -eq $_.MedianMs } }, MedianMs
}


if ($MyInvocation.InvocationName -ne '.') {
  Write-Header 'DNS Benchmark'
  $sorted = Invoke-DnsBenchmark -Domain $Domain -Rounds $Rounds -Server $Server -AddServer $AddServer
  $cols = 'Provider', 'Server', 'Family', 'MinMs', 'MedianMs', 'AvgMs', 'MaxMs', 'FailPct', 'Status'
  $sorted | Format-Table -Property $cols -AutoSize | Out-String | Write-Host
  Write-Host 'Per provider (all servers pooled):'
  Get-ProviderSummary -Result $sorted | Format-Table -AutoSize | Out-String | Write-Host
  if ($PassThru) { $sorted | Select-Object -Property $cols }
}
