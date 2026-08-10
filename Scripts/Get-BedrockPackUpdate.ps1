#Requires -Version 5.1
<#
.SYNOPSIS
  Reports which Minecraft Bedrock packs installed in LeviLauncher have a newer release upstream.
.DESCRIPTION
  LeviLauncher has no update mechanism for third-party behavior and resource packs, and Minecraft
  stores imported packs in base64-named folders without recording where they came from. This script
  reads every installed pack's manifest, joins it to the hand-maintained source map in
  bedrock-packs.psd1 by pack UUID, and compares the upstream release date against the pack's install
  date.

  It is read-only: nothing under the pack root is created, modified, or deleted.

  Upstream lookups are driven by the URL in the source map:
    curseforge.com/minecraft-bedrock/addons/<slug>  checked via the keyless cfwidget API
    github.com/<owner>/<repo>                       checked via the GitHub releases API
    anything else                                   reported as CHECK for a manual visit

  Comparison is on release date rather than version string: CurseForge reports the game version a
  file targets, not the pack's own version, so version strings are not comparable.
.PARAMETER Version
  LeviLauncher instance to inspect, e.g. '1.26.40.05'. Defaults to the newest installed instance.
.PARAMETER PackRoot
  Full path to a com.mojang directory, bypassing instance resolution entirely.
.PARAMETER SourceMap
  Path to the .psd1 source map. Defaults to bedrock-packs.psd1 beside this script.
.PARAMETER AsObject
  Emit the result objects instead of a formatted table and summary.
.EXAMPLE
  .\Get-BedrockPackUpdate.ps1
  Checks every pack in the newest instance and prints a table sorted with problems first.
.EXAMPLE
  .\Get-BedrockPackUpdate.ps1 -Version 1.26.33.01
  Checks the older instance instead of the newest one.
.EXAMPLE
  .\Get-BedrockPackUpdate.ps1 -AsObject | Where-Object Status -eq 'UNMAPPED'
  Lists just the packs still missing a source URL, for filling in bedrock-packs.psd1.
.OUTPUTS
  System.Management.Automation.PSCustomObject
#>
[CmdletBinding()]
[OutputType([pscustomobject])]
param (
  # LeviLauncher instance version; newest installed instance when omitted
  [string]$Version,

  # Explicit com.mojang path, bypassing instance resolution
  [string]$PackRoot,

  # Source map to load
  [string]$SourceMap = (Join-Path -Path $PSScriptRoot -ChildPath 'bedrock-packs.psd1'),

  # Return objects rather than a table
  [switch]$AsObject
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

. "$PSScriptRoot\Common.ps1"

# Windows PowerShell 5.1 still defaults to TLS 1.0 for some hosts
if ($PSVersionTable.PSVersion.Major -lt 6) {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

$packKinds = @{
  behavior_packs             = 'BP'
  resource_packs             = 'RP'
  development_behavior_packs = 'BP-dev'
  development_resource_packs = 'RP-dev'
}


function ConvertFrom-JsonComment {
  <#
  .SYNOPSIS
    Strips // and /* */ comments from JSONC text without touching comment-like content in strings.
  .PARAMETER Text
    Raw manifest text.
  .EXAMPLE
    ConvertFrom-JsonComment -Text '/* by someone */ { "a": "https://x" }'
    Returns ' { "a": "https://x" }' - the URL survives because strings match first.
  .OUTPUTS
    System.String
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param (
    # Raw JSONC text
    [Parameter(Mandatory)]
    [AllowEmptyString()]
    [string]$Text
  )
  process {
    # The string alternative is listed first so that // inside a quoted value (a URL, typically)
    # is captured as a string and handed back untouched rather than treated as a comment.
    [regex]::Replace(
      $Text,
      '("(?:\\.|[^"\\])*")|/\*[\s\S]*?\*/|//[^\r\n]*',
      { param($m) if ($m.Groups[1].Success) { $m.Value } else { '' } }
    )
  }
}


function Get-PackDisplayName {
  <#
  .SYNOPSIS
    Removes Minecraft section-sign colour codes from a pack name.
  .PARAMETER Name
    Raw header.name from a manifest.
  .EXAMPLE
    Get-PackDisplayName -Name "`u{00a7}2Mutant `u{00a7}3Creatures"
    Returns 'Mutant Creatures'.
  .OUTPUTS
    System.String
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param (
    # Name possibly containing section-sign codes
    [AllowEmptyString()]
    [AllowNull()]
    [string]$Name
  )
  process {
    ($Name -replace '\u00a7.', '').Trim()
  }
}


function Resolve-PackRoot {
  <#
  .SYNOPSIS
    Resolves the com.mojang directory for a LeviLauncher instance.
  .PARAMETER Version
    Instance version to use; the newest version-shaped directory when omitted.
  .EXAMPLE
    Resolve-PackRoot
    Returns the com.mojang path of the newest installed instance.
  .OUTPUTS
    System.String
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param (
    # Instance version, or empty for newest
    [AllowEmptyString()]
    [string]$Version
  )
  process {
    $base = Join-Path -Path $env:APPDATA -ChildPath 'levilauncher.exe'
    $configPath = Join-Path -Path $base -ChildPath 'config.json'
    if (Test-Path -LiteralPath $configPath) {
      $baseRoot = (Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json).base_root
      if ($baseRoot) { $base = $baseRoot }
    }

    $versionsDir = Join-Path -Path $base -ChildPath 'versions'
    if (-not (Test-Path -LiteralPath $versionsDir)) {
      throw "LeviLauncher versions directory not found: $versionsDir"
    }

    if ($Version) {
      $instance = Join-Path -Path $versionsDir -ChildPath $Version
      if (-not (Test-Path -LiteralPath $instance)) {
        throw "Instance '$Version' not found under $versionsDir"
      }
    } else {
      $newest = Get-ChildItem -LiteralPath $versionsDir -Directory |
        ForEach-Object {
          $parsed = $null
          if ([version]::TryParse($_.Name, [ref]$parsed)) {
            [pscustomobject]@{ Path = $_.FullName; Version = $parsed }
          }
        } |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1
      if (-not $newest) {
        throw "No version-shaped instance directories under $versionsDir"
      }
      $instance = $newest.Path
    }

    Join-Path -Path $instance -ChildPath 'Minecraft Bedrock\Users\Shared\games\com.mojang'
  }
}


function Get-InstalledPack {
  <#
  .SYNOPSIS
    Reads every installed pack manifest under a com.mojang directory.
  .PARAMETER Path
    The com.mojang directory to enumerate.
  .EXAMPLE
    Get-InstalledPack -Path 'C:\...\com.mojang'
    Returns one object per pack with its UUID, display name and install date.
  .OUTPUTS
    System.Management.Automation.PSCustomObject
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param (
    # com.mojang directory
    [Parameter(Mandatory)]
    [string]$Path
  )
  process {
    foreach ($kind in $packKinds.Keys) {
      $dir = Join-Path -Path $Path -ChildPath $kind
      if (-not (Test-Path -LiteralPath $dir)) { continue }

      foreach ($packDir in Get-ChildItem -LiteralPath $dir -Directory) {
        $manifestPath = Join-Path -Path $packDir.FullName -ChildPath 'manifest.json'
        if (-not (Test-Path -LiteralPath $manifestPath)) {
          # Very old packs use pack_manifest.json instead
          $manifestPath = Join-Path -Path $packDir.FullName -ChildPath 'pack_manifest.json'
          if (-not (Test-Path -LiteralPath $manifestPath)) {
            Write-Warn "No manifest in $($packDir.Name), skipping"
            continue
          }
        }

        try {
          $raw = Get-Content -LiteralPath $manifestPath -Raw
          $manifest = ConvertFrom-JsonComment -Text $raw | ConvertFrom-Json
        } catch {
          $err = $_
          Write-Warn "Unreadable manifest in $($packDir.Name): $($err.Exception.Message)"
          continue
        }

        [pscustomobject]@{
          Kind      = $packKinds[$kind]
          Folder    = $packDir.Name
          Uuid      = [string]$manifest.header.uuid
          Name      = Get-PackDisplayName -Name $manifest.header.name
          Installed = (Get-Item -LiteralPath $manifestPath).LastWriteTime
        }
      }
    }
  }
}


function Get-CurseForgeRelease {
  <#
  .SYNOPSIS
    Fetches the newest published file for a CurseForge Bedrock project via cfwidget.
  .PARAMETER ProjectPath
    Class and slug, e.g. 'minecraft-bedrock/addons/commander-api'. Bedrock packs are spread across
    several classes - addons, texture-packs and scripts have all been seen - so the class cannot be
    assumed.
  .EXAMPLE
    Get-CurseForgeRelease -ProjectPath 'minecraft-bedrock/addons/commander-api'
    Returns the upload date and filename of the project's current download.
  .OUTPUTS
    System.Management.Automation.PSCustomObject
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param (
    # minecraft-bedrock/<class>/<slug>
    [Parameter(Mandatory)]
    [string]$ProjectPath
  )
  process {
    $uri = "https://api.cfwidget.com/$ProjectPath"
    $result = $null
    # cfwidget answers 202 while it queues a project it has never been asked about before
    foreach ($attempt in 1..3) {
      if (-not $result) {
        $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 20
        if ($response.StatusCode -eq 200) {
          $download = ($response.Content | ConvertFrom-Json).download
          $result = [pscustomobject]@{
            Date  = [datetime]$download.uploaded_at
            Label = $download.name
          }
        } else {
          Write-Verbose "cfwidget queued $ProjectPath (attempt $attempt), waiting"
          Start-Sleep -Seconds 3
        }
      }
    }
    if (-not $result) { throw "cfwidget did not return '$ProjectPath' after 3 attempts" }
    $result
  }
}


function Get-GitHubRelease {
  <#
  .SYNOPSIS
    Fetches the latest GitHub release for a repository.
  .PARAMETER Repository
    Repository in owner/name form.
  .EXAMPLE
    Get-GitHubRelease -Repository 'PowerShell/PowerShell'
    Returns the publish date and tag of the latest release.
  .OUTPUTS
    System.Management.Automation.PSCustomObject
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param (
    # owner/name
    [Parameter(Mandatory)]
    [string]$Repository
  )
  process {
    $headers = @{ 'User-Agent' = 'Get-BedrockPackUpdate' }
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest" `
      -Headers $headers -TimeoutSec 20
    [pscustomobject]@{
      Date  = [datetime]$release.published_at
      Label = $release.tag_name
    }
  }
}


function Get-UpstreamRelease {
  <#
  .SYNOPSIS
    Dispatches to the right upstream lookup for a source URL.
  .PARAMETER Url
    Project URL from the source map.
  .EXAMPLE
    Get-UpstreamRelease -Url 'https://www.curseforge.com/minecraft-bedrock/addons/commander-api'
    Returns the release date and label; returns nothing for URLs with no API.
  .OUTPUTS
    System.Management.Automation.PSCustomObject
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param (
    # Source URL
    [Parameter(Mandatory)]
    [string]$Url
  )
  process {
    # The class segment varies - addons, texture-packs and scripts all host Bedrock packs - so match
    # it rather than assuming 'addons'. A /members/<user>/projects URL has no class and falls through.
    if ($Url -match 'curseforge\.com/(minecraft-bedrock/[^/?#]+/[^/?#]+)') {
      Get-CurseForgeRelease -ProjectPath $Matches[1]
    } elseif ($Url -match 'github\.com/([^/?#]+/[^/?#]+)') {
      Get-GitHubRelease -Repository ($Matches[1] -replace '\.git$', '')
    }
  }
}


$root = if ($PackRoot) { $PackRoot } else { Resolve-PackRoot -Version $Version }
if (-not (Test-Path -LiteralPath $root)) {
  throw "Pack root not found: $root"
}

$sources = if (Test-Path -LiteralPath $SourceMap) {
  Import-PowerShellDataFile -LiteralPath $SourceMap
} else {
  Write-Warn "Source map not found: $SourceMap - every pack will report UNMAPPED"
  @{}
}

Write-Header 'Bedrock pack updates'
Write-Info $root

$lookupFailed = $false
$results = foreach ($pack in Get-InstalledPack -Path $root) {
  $entry = $sources[$pack.Uuid]
  $name = if ($entry -and $entry.Name) { $entry.Name } else { $pack.Name }
  if (-not $name) { $name = $pack.Folder }

  if (-not $entry) {
    $query = [uri]::EscapeDataString($name)
    [pscustomobject]@{
      Status    = 'UNMAPPED'
      Kind      = $pack.Kind
      Name      = $name
      Installed = $pack.Installed
      Latest    = $null
      # Unfiltered by class on purpose - Bedrock packs live under addons, texture-packs and scripts
      Url       = "https://www.curseforge.com/minecraft-bedrock/search?search=$query"
    }
    continue
  }

  try {
    $upstream = Get-UpstreamRelease -Url $entry.Url
  } catch {
    $err = $_
    Write-Verbose "Lookup failed for '$name': $($err.Exception.Message)"
    $upstream = $null
    $lookupFailed = $true
  }

  if (-not $upstream) {
    # Either the URL has no API behind it, or the lookup threw
    [pscustomobject]@{
      Status    = if ($lookupFailed) { 'ERROR' } else { 'CHECK' }
      Kind      = $pack.Kind
      Name      = $name
      Installed = $pack.Installed
      Latest    = $null
      Url       = $entry.Url
    }
    $lookupFailed = $false
    continue
  }

  [pscustomobject]@{
    Status    = if ($upstream.Date -gt $pack.Installed) { 'OUTDATED' } else { 'current' }
    Kind      = $pack.Kind
    Name      = $name
    Installed = $pack.Installed
    Latest    = $upstream.Date
    Url       = $entry.Url
  }
}

if ($AsObject) {
  $results
} else {
  $order = @{ OUTDATED = 0; ERROR = 1; CHECK = 2; UNMAPPED = 3; current = 4 }
  $sorted = $results | Sort-Object -Property @{ Expression = { $order[$_.Status] } }, Name

  # URLs are too long to share a table with the rest, so they go in a list underneath
  $sorted | Format-Table -Property Status, Kind, Name,
    @{ Name = 'Installed'; Expression = { $_.Installed.ToString('yyyy-MM-dd') } },
    @{ Name = 'Latest'; Expression = { if ($_.Latest) { $_.Latest.ToString('yyyy-MM-dd') } else { '' } } } -AutoSize

  foreach ($row in $sorted | Where-Object { $_.Status -ne 'current' }) {
    "  {0,-8} {1}`n           {2}" -f $row.Status, $row.Name, $row.Url
  }

  $checked = @($results | Where-Object { $_.Latest }).Count
  $outdated = @($results | Where-Object { $_.Status -eq 'OUTDATED' }).Count
  $unmapped = @($results | Where-Object { $_.Status -eq 'UNMAPPED' }).Count
  if ($outdated -gt 0) {
    Write-Warn "$outdated of $checked automatically checked packs are outdated"
  } elseif ($checked -gt 0) {
    Write-Success "$checked packs checked automatically, none outdated"
  } else {
    Write-Warn 'No pack could be checked automatically - none of them map to a CurseForge or GitHub URL'
  }
  Write-Info "$($results.Count - $checked) of $($results.Count) packs need a manual look ($unmapped with no source URL yet)"
}
