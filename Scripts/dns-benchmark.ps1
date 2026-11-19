#Requires -Version 5.1

<#
.SYNOPSIS
  Benchmarks DNS resolvers (Cloudflare, Cloudflare Malware, AdGuard DNS) over IPv4 and IPv6.
.DESCRIPTION
  Sends raw UDP DNS A queries (no Resolve-DnsName overhead) and times each reply. Servers are
  interleaved: in every round each domain (shuffled) is queried against every live server (shuffled),
  so network drift hits all servers equally instead of favouring whichever ran in a quiet period.
  A warm-up pass (each domain once per server, not counted) fills the resolver caches first; a server
  with no warm-up success is reported as 'unreachable' and skipped. Failed queries are counted, not
  fatal. Read-only: no admin, no system changes. Returns objects sorted by median, then P90.
.PARAMETER Domain
  Domains to resolve. Defaults to ten popular domains.
.PARAMETER Rounds
  Measured rounds per domain (excludes the warm-up pass). Default 10.
.PARAMETER TimeoutMs
  Per-query timeout in milliseconds (100-10000). Default 1000.
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
  [ValidateRange(1, 100)][int]$Rounds = 10,
  [ValidateRange(100, 10000)][int]$TimeoutMs = 1000,
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


function Send-DnsQuery {
  <#
  .SYNOPSIS
    Sends one raw UDP DNS A query and returns the reply time in ms, or $null on failure.
  #>
  [CmdletBinding()]
  [OutputType([double])]
  param(
    [Parameter(Mandatory)][string]$Address,
    [Parameter(Mandatory)][string]$Name,
    [ValidateRange(1, 60000)][int]$TimeoutMs = 1000,
    # Test hook; real queries always use 53.
    [ValidateRange(1, 65535)][int]$Port = 53
  )

  # shortcut: UDP only, no TCP retry on TC bit; fine for A records of normal domains
  $ip = [System.Net.IPAddress]::Parse($Address)
  $id = Get-Random -Minimum 0 -Maximum 65536
  $hi = [byte]($id -shr 8)
  $lo = [byte]($id -band 0xFF)
  $query = [System.Collections.Generic.List[byte]]::new()
  # Header: ID, flags RD, QDCOUNT 1, no answer/authority/additional records.
  $query.AddRange([byte[]]@($hi, $lo, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0))
  foreach ($label in $Name.TrimEnd('.').Split('.')) {
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($label)
    $query.Add([byte]$bytes.Length)
    $query.AddRange($bytes)
  }
  $query.AddRange([byte[]]@(0, 0, 1, 0, 1))  # root label, QTYPE A, QCLASS IN
  $packet = $query.ToArray()

  $udp = $null
  try {
    $udp = [System.Net.Sockets.UdpClient]::new($ip.AddressFamily)
    $udp.Connect($ip, $Port)
    $remote = [System.Net.IPEndPoint]::new($ip, $Port)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $null = $udp.Send($packet, $packet.Length)
    while ($true) {
      $left = $TimeoutMs - [int]$sw.ElapsedMilliseconds
      if ($left -le 0) { return $null }
      $udp.Client.ReceiveTimeout = $left
      $reply = $udp.Receive([ref]$remote)
      # A late reply to an earlier query carries another ID: keep waiting.
      if ($reply.Length -ge 12 -and $reply[0] -eq $hi -and $reply[1] -eq $lo) {
        $sw.Stop()
        if (($reply[3] -band 0x0F) -eq 0) { return $sw.Elapsed.TotalMilliseconds }
        return $null
      }
    }
  } catch {
    return $null  # timeout, no route, ICMP unreachable
  } finally {
    if ($udp) { $udp.Dispose() }
  }
}


function Get-LatencyStats {
  [CmdletBinding()]
  param([double[]]$Time)

  if (-not $Time) { return $null }
  $s = $Time | Sort-Object
  $mid = [int][math]::Floor($s.Count / 2)
  $median = if ($s.Count % 2) { $s[$mid] } else { ($s[$mid - 1] + $s[$mid]) / 2 }
  $avg = ($s | Measure-Object -Average).Average
  $variance = ($s | ForEach-Object { ($_ - $avg) * ($_ - $avg) } | Measure-Object -Average).Average
  [pscustomobject]@{
    MinMs = [math]::Round($s[0], 1)
    MedianMs = [math]::Round($median, 1)
    P90Ms = [math]::Round($s[[math]::Ceiling(0.9 * $s.Count) - 1], 1)
    AvgMs = [math]::Round($avg, 1)
    MaxMs = [math]::Round($s[-1], 1)
    JitterMs = [math]::Round([math]::Sqrt($variance), 1)
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
      P90Ms = $stats.P90Ms
      AvgMs = $stats.AvgMs
      MaxMs = $stats.MaxMs
      JitterMs = $stats.JitterMs
    }
  } | Sort-Object @{ Expression = { $null -eq $_.MedianMs } }, MedianMs
}


function Invoke-DnsBenchmark {
  [CmdletBinding()]
  param(
    [string[]]$Domain,
    [int]$Rounds,
    [int]$TimeoutMs = 1000,
    [string[]]$Server,
    [string[]]$AddServer
  )

  $custom = @(
    @($Server) + @($AddServer) | Where-Object { $_ } | ForEach-Object {
      @{ Provider = 'Custom'; Address = $_ }
    }
  )
  $defs = if ($Server) { $custom } else { @($script:DefaultServers) + $custom }
  $targets = @(
    foreach ($t in $defs) {
      $family = [System.Net.IPAddress]::Parse($t.Address).AddressFamily
      [pscustomobject]@{
        Provider = $t.Provider
        Address = $t.Address
        Family = $(if ($family -eq 'InterNetworkV6') { 'IPv6' } else { 'IPv4' })
        Samples = [System.Collections.Generic.List[double]]::new()
        Fail = 0
        Total = 0
        Live = $false
      }
    }
  )

  # Warm-up (not counted): fills resolver caches and finds dead servers, which would otherwise cost
  # Rounds x Domains x TimeoutMs each.
  Write-Info "Warm-up: $($targets.Count) servers x $(@($Domain).Count) domains"
  foreach ($d in $Domain) {
    foreach ($t in $targets) {
      if ($null -ne (Send-DnsQuery -Address $t.Address -Name $d -TimeoutMs $TimeoutMs)) { $t.Live = $true }
    }
  }
  $live = @($targets | Where-Object { $_.Live })

  if ($live.Count) {
    for ($round = 1; $round -le $Rounds; $round++) {
      $progress = @{
        Activity = 'DNS benchmark'
        Status = "Round $round of $Rounds"
        PercentComplete = [int](100 * ($round - 1) / $Rounds)
      }
      Write-Progress @progress
      foreach ($d in @($Domain | Get-Random -Count @($Domain).Count)) {
        foreach ($t in @($live | Get-Random -Count $live.Count)) {
          $ms = Send-DnsQuery -Address $t.Address -Name $d -TimeoutMs $TimeoutMs
          $t.Total++
          if ($null -ne $ms) { $t.Samples.Add($ms) } else { $t.Fail++ }
        }
      }
    }
    Write-Progress -Activity 'DNS benchmark' -Completed
  }

  $results = foreach ($t in $targets) {
    $stats = Get-LatencyStats -Time $t.Samples
    if (-not $stats) { Write-Warn "$($t.Address) unreachable (no IPv6 route?)" }
    [pscustomobject][ordered]@{
      Provider = $t.Provider
      Server = $t.Address
      Family = $t.Family
      MinMs = $stats.MinMs
      MedianMs = $stats.MedianMs
      P90Ms = $stats.P90Ms
      AvgMs = $stats.AvgMs
      MaxMs = $stats.MaxMs
      JitterMs = $stats.JitterMs
      FailPct = $(if ($t.Live) { [math]::Round(100 * $t.Fail / [math]::Max($t.Total, 1), 1) } else { 100 })
      Status = $(if ($stats) { 'ok' } else { 'unreachable' })
      Samples = $t.Samples.ToArray()
    }
  }
  # Unreachable rows (null median) sort last.
  $results | Sort-Object @{ Expression = { $null -eq $_.MedianMs } }, MedianMs, P90Ms
}


if ($MyInvocation.InvocationName -ne '.') {
  Write-Header 'DNS Benchmark'
  $bench = @{
    Domain = $Domain
    Rounds = $Rounds
    TimeoutMs = $TimeoutMs
    Server = $Server
    AddServer = $AddServer
  }
  $sorted = Invoke-DnsBenchmark @bench
  $cols = 'Provider', 'Server', 'Family', 'MinMs', 'MedianMs', 'P90Ms', 'AvgMs', 'MaxMs', 'JitterMs', 'FailPct',
    'Status'
  $sorted | Format-Table -Property $cols -AutoSize | Out-String | Write-Host
  Write-Host 'Per provider (all servers pooled):'
  Get-ProviderSummary -Result $sorted | Format-Table -AutoSize | Out-String | Write-Host
  if ($PassThru) { $sorted | Select-Object -Property $cols }
}
