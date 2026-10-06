#Requires -Version 5.1
<#
.SYNOPSIS
  Reports which Minecraft Bedrock packs and mods installed in LeviLauncher have a newer release
  upstream.
.DESCRIPTION
  LeviLauncher has no update mechanism for third-party behavior/resource packs or native mods.
  Minecraft stores imported packs in base64-named folders, and mods live under a folder named after
  the DLL they hijack - neither records where it came from. This script reads every installed pack
  and mod manifest, joins it to the hand-maintained source map in bedrock-packs.psd1 (by pack UUID,
  or by mod name), and compares the upstream release date against the install date.

  Without -Update it is read-only: nothing under the pack or mod root is created, modified, or
  deleted. Packs with no map entry are matched to a source automatically: a project URL in their
  manifest, a same-named entry in the map (a re-release with a new UUID), or a CurseForge API
  search. The search needs a key: $env:CURSEFORGE_API_KEY, or the 'curseforge' custom field on the
  Bitwarden item 'api-keys' when the vault is unlocked ($env:BW_SESSION = bw unlock --raw).

  With -Update it also:
    1. Appends every auto-matched pack to bedrock-packs.psd1, keeping the file's comments.
    2. Downloads each OUTDATED pack once per project (keyless CurseForge download endpoint or a
       GitHub release asset), unpacks .mcaddon/.mcpack archives, and matches the contents to the
       installed packs by UUID, then by pack type and name.
    3. Moves each old pack folder into -BackupPath and puts the new one in its place.
    4. Repoints world_behavior_packs.json / world_resource_packs.json entries at the new UUID and
       version, backing each file up first.
  Mods, CHECK URLs and low-confidence search hits (CANDIDATE) are never installed. Use -WhatIf to
  preview.

  Upstream lookups are driven by the URL in the source map:
    curseforge.com/minecraft-bedrock/addons/<slug>  checked via the keyless cfwidget API
    github.com/<owner>/<repo>                       checked via the GitHub releases API
    anything else                                   reported as CHECK for a manual visit

  Comparison is on release date rather than version string: CurseForge reports the game version a
  file targets, not the pack's own version, and mod manifests carry no reliable version at all, so
  version strings are not comparable.
.PARAMETER Version
  LeviLauncher instance to inspect, e.g. '1.26.40.05'. Defaults to the newest installed instance.
.PARAMETER PackRoot
  Full path to a com.mojang directory, bypassing instance resolution entirely.
.PARAMETER ModRoot
  Full path to a LeviLauncher instance's mods directory, bypassing instance resolution entirely.
.PARAMETER SourceMap
  Path to the .psd1 source map. Defaults to bedrock-packs.psd1 beside this script.
.PARAMETER AsObject
  Emit the result objects instead of a formatted table and summary.
.PARAMETER Update
  Map newly detected packs and install available updates.
.PARAMETER BackupPath
  Where replaced packs and world files are kept, one timestamped folder per run.
.PARAMETER SkipWorlds
  Leave world pack references alone.
.EXAMPLE
  .\Get-BedrockPackUpdate.ps1 -Update -WhatIf
  Shows what would be mapped, downloaded and replaced without touching anything.
.EXAMPLE
  .\Get-BedrockPackUpdate.ps1 -Update
  Maps new packs, installs every available update, and fixes world references.
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
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
[OutputType([pscustomobject])]
param (
  # LeviLauncher instance version; newest installed instance when omitted
  [string]$Version,

  # Explicit com.mojang path, bypassing instance resolution
  [string]$PackRoot,

  # Explicit mods directory, bypassing instance resolution
  [string]$ModRoot,

  # Source map to load
  [string]$SourceMap = (Join-Path -Path $PSScriptRoot -ChildPath 'bedrock-packs.psd1'),

  # Return objects rather than a table
  [switch]$AsObject,

  # Map new packs and install available updates; without it the script is read-only
  [switch]$Update,

  # Backup location for replaced packs and world files (-Update only)
  [string]$BackupPath = (Join-Path -Path $env:USERPROFILE -ChildPath 'Documents\bedrock-pack-backup'),

  # Do not rewrite world pack references (-Update only)
  [switch]$SkipWorlds
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


function Get-ManifestPackType {
  <#
  .SYNOPSIS
    Classifies a parsed manifest as a resource pack (RP) or behavior pack (BP).
  .PARAMETER Manifest
    Parsed manifest.json.
  .PARAMETER Fallback
    Value to use when the manifest lists no modules.
  .EXAMPLE
    Get-ManifestPackType -Manifest $manifest -Fallback 'BP'
    Returns 'RP' when any module has type 'resources'.
  .OUTPUTS
    System.String
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param (
    # Parsed manifest
    [Parameter(Mandatory)]
    [psobject]$Manifest,

    # Used when there are no modules
    [Parameter(Mandatory)]
    [string]$Fallback
  )
  process {
    $moduleTypes = @($Manifest.modules | ForEach-Object { $_.type })
    if ($moduleTypes -contains 'resources') {
      'RP'
    } elseif ($moduleTypes.Count -gt 0) {
      'BP'
    } else {
      $Fallback
    }
  }
}


function Resolve-Instance {
  <#
  .SYNOPSIS
    Resolves the root directory of a LeviLauncher instance.
  .PARAMETER Version
    Instance version to use; the newest version-shaped directory when omitted.
  .EXAMPLE
    Resolve-Instance
    Returns the path of the newest installed instance.
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

    $instance
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
          Kind        = $packKinds[$kind]
          PackType    = Get-ManifestPackType -Manifest $manifest -Fallback ($packKinds[$kind] -replace '-dev$', '')
          Folder      = $packDir.Name
          Path        = $packDir.FullName
          Uuid        = [string]$manifest.header.uuid
          Name        = Get-PackDisplayName -Name $manifest.header.name
          Version     = @($manifest.header.version) -join '.'
          Authors     = @($manifest.metadata.authors) -join ', '
          ManifestUrl = [string]$manifest.metadata.url
          Installed   = (Get-Item -LiteralPath $manifestPath).LastWriteTime
        }
      }
    }
  }
}


function Get-InstalledMod {
  <#
  .SYNOPSIS
    Reads every installed mod manifest under a LeviLauncher instance's mods directory.
  .PARAMETER Path
    The mods directory to enumerate.
  .EXAMPLE
    Get-InstalledMod -Path 'C:\...\1.26.40.05\mods'
    Returns one object per mod with its name (used as the map key) and install date.
  .OUTPUTS
    System.Management.Automation.PSCustomObject
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param (
    # mods directory
    [Parameter(Mandatory)]
    [string]$Path
  )
  process {
    foreach ($modDir in Get-ChildItem -LiteralPath $Path -Directory) {
      $manifestPath = Join-Path -Path $modDir.FullName -ChildPath 'manifest.json'
      if (-not (Test-Path -LiteralPath $manifestPath)) {
        Write-Warn "No manifest in $($modDir.Name), skipping"
        continue
      }

      try {
        $raw = Get-Content -LiteralPath $manifestPath -Raw
        $manifest = ConvertFrom-JsonComment -Text $raw | ConvertFrom-Json
      } catch {
        $err = $_
        Write-Warn "Unreadable manifest in $($modDir.Name): $($err.Exception.Message)"
        continue
      }

      # Mod manifests carry no UUID; the folder is named after the DLL being hijacked, not the
      # project, so the manifest name (falling back to the folder) is the map key instead.
      $name = if ($manifest.name) { [string]$manifest.name } else { $modDir.Name }

      [pscustomobject]@{
        Kind        = 'Mod'
        PackType    = 'Mod'
        Folder      = $modDir.Name
        Path        = $modDir.FullName
        Uuid        = $name
        Name        = $name
        Version     = ''
        Authors     = ''
        ManifestUrl = ''
        Installed   = (Get-Item -LiteralPath $manifestPath).LastWriteTime
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
          $project = $response.Content | ConvertFrom-Json
          $download = $project.download
          # The keyless download endpoint redirects to the CDN, so no API key is needed to install
          $downloadUrl = if ($project.id -and $download.id) {
            "https://www.curseforge.com/api/v1/mods/$($project.id)/files/$($download.id)/download"
          }
          $result = [pscustomobject]@{
            Date        = [datetime]$download.uploaded_at
            Label       = $download.name
            FileName    = $download.name
            DownloadUrl = $downloadUrl
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
    $asset = @($release.assets) |
      Where-Object { $_.name -match '\.(mcaddon|mcpack|zip)$' } |
      Select-Object -First 1
    [pscustomobject]@{
      Date        = [datetime]$release.published_at
      Label       = $release.tag_name
      FileName    = $asset.name
      DownloadUrl = $asset.browser_download_url
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


function ConvertTo-PackKey {
  <#
  .SYNOPSIS
    Reduces a pack name to a comparable key, so a re-release matches its earlier version.
  .PARAMETER Name
    Pack display name.
  .EXAMPLE
    ConvertTo-PackKey -Name 'Feather FPS Boost V11 (BP)'
    Returns 'featherfpsboost'.
  .OUTPUTS
    System.String
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param (
    # Pack name, possibly with colour codes, (BP)/(RP) tags and version markers
    [AllowEmptyString()]
    [AllowNull()]
    [string]$Name
  )
  process {
    $key = Get-PackDisplayName -Name $Name
    $key = $key -replace '\[[^\]]*\]|\((?:BP|RP)\)|\b(?:BP|RP)\b|\bv\d+(?:\.\d+)*\b', ''
    ($key -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
  }
}


function Search-CurseForgeProject {
  <#
  .SYNOPSIS
    Searches CurseForge Bedrock projects through the official API.
  .PARAMETER Text
    Search text, a pack name or an author.
  .PARAMETER ApiKey
    CurseForge API key; sent only as a request header.
  .EXAMPLE
    Search-CurseForgeProject -Text 'Craftable Spawners' -ApiKey $env:CURSEFORGE_API_KEY
    Returns matching projects with their authors and website URL.
  .OUTPUTS
    System.Management.Automation.PSCustomObject
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param (
    # Search text
    [Parameter(Mandatory)]
    [string]$Text,

    # API key
    [Parameter(Mandatory)]
    [string]$ApiKey
  )
  process {
    # 78022 is CurseForge's game id for Minecraft Bedrock
    $uri = 'https://api.curseforge.com/v1/mods/search?gameId=78022&pageSize=20&searchFilter=' +
      [uri]::EscapeDataString($Text)
    $response = Invoke-RestMethod -Uri $uri -Headers @{ 'x-api-key' = $ApiKey } -TimeoutSec 20
    foreach ($mod in $response.data) {
      [pscustomobject]@{
        Name    = [string]$mod.name
        Url     = [string]$mod.links.websiteUrl
        Authors = @($mod.authors | ForEach-Object { $_.name })
      }
    }
  }
}


function Get-CurseForgeApiKey {
  <#
  .SYNOPSIS
    Returns the CurseForge API key from $env:CURSEFORGE_API_KEY, else from Bitwarden.
  .DESCRIPTION
    Bitwarden is only queried when the vault is unlocked for this session ($env:BW_SESSION set, from
    `bw unlock --raw`): the key is the custom field 'curseforge' on the item 'api-keys'. The result,
    including a miss, is cached for the run so bw is called at most once.
  .EXAMPLE
    Get-CurseForgeApiKey
    Returns the key, or nothing when neither source has one.
  .OUTPUTS
    System.String
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param ()
  process {
    if ($env:CURSEFORGE_API_KEY) { return $env:CURSEFORGE_API_KEY }
    if ($null -ne $script:CurseForgeKey) { return $script:CurseForgeKey }

    $script:CurseForgeKey = ''
    if ($env:BW_SESSION -and (Get-Command -Name bw -ErrorAction SilentlyContinue)) {
      try {
        $item = & bw get item 'api-keys' 2> $null | ConvertFrom-Json
        $field = @($item.fields) | Where-Object { $_.name -eq 'curseforge' } | Select-Object -First 1
        if ($field.value) { $script:CurseForgeKey = [string]$field.value }
      } catch {
        $err = $_
        Write-Verbose "Bitwarden lookup failed: $($err.Exception.Message)"
      }
    }
    $script:CurseForgeKey
  }
}


function Find-PackSource {
  <#
  .SYNOPSIS
    Finds an upstream URL for an installed pack that has no source map entry.
  .DESCRIPTION
    Tries, in order: a project URL in the pack's own manifest, a sibling map entry with the same
    name key (a re-release with a fresh UUID), then a CurseForge API search when a key is available
    (see Get-CurseForgeApiKey). A weak search hit is returned as 'candidate' for a human to
    confirm.
  .PARAMETER Pack
    Installed pack object from Get-InstalledPack.
  .PARAMETER Sources
    Loaded source map.
  .EXAMPLE
    Find-PackSource -Pack $pack -Sources $sources
    Returns Source ('manifest', 'sibling', 'search' or 'candidate') and Url, or nothing.
  .OUTPUTS
    System.Management.Automation.PSCustomObject
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param (
    # Installed pack
    [Parameter(Mandatory)]
    [pscustomobject]$Pack,

    # Source map
    [Parameter(Mandatory)]
    [hashtable]$Sources
  )
  process {
    $apiUrl = 'curseforge\.com/minecraft-bedrock/[^/?#]+/[^/?#]+|github\.com/[^/?#]+/[^/?#]+'
    if ($Pack.ManifestUrl -match $apiUrl) {
      return [pscustomobject]@{ Source = 'manifest'; Url = $Pack.ManifestUrl }
    }

    $packKey = ConvertTo-PackKey -Name $Pack.Name
    if (-not $packKey) { return }

    foreach ($entry in $Sources.Values) {
      if ($entry.Url -and (ConvertTo-PackKey -Name $entry.Name) -eq $packKey) {
        return [pscustomobject]@{ Source = 'sibling'; Url = $entry.Url }
      }
    }

    # Mods live on GitHub, and CurseForge has no mod class for them
    if ($Pack.Kind -eq 'Mod') { return }
    $apiKey = Get-CurseForgeApiKey
    if (-not $apiKey) { return }

    $author = ($Pack.Authors -split ',')[0].Trim()
    $hits = @(Search-CurseForgeProject -Text $Pack.Name -ApiKey $apiKey)
    if ($hits.Count -eq 0 -and $author) {
      $hits = @(Search-CurseForgeProject -Text $author -ApiKey $apiKey)
    }

    # ponytail: name-key equality plus author match; add fuzzy scoring only if real packs miss
    foreach ($hit in $hits) {
      $hitKey = ConvertTo-PackKey -Name $hit.Name
      $authorMatch = $author -and ($hit.Authors -contains $author)
      if ($hitKey -eq $packKey -or ($authorMatch -and $hitKey -and $hitKey.Contains($packKey))) {
        return [pscustomobject]@{ Source = 'search'; Url = $hit.Url }
      }
    }
    if ($hits.Count -gt 0) {
      [pscustomobject]@{ Source = 'candidate'; Url = $hits[0].Url }
    }
  }
}


function New-PackResult {
  <#
  .SYNOPSIS
    Builds one result row, carrying the pack fields the updater needs.
  .PARAMETER Pack
    Installed pack object.
  .PARAMETER Status
    OUTDATED, current, ERROR, CHECK, CANDIDATE or UNMAPPED.
  .PARAMETER Source
    How the URL was found: map, manifest, sibling, search, candidate or none.
  .PARAMETER Name
    Display name.
  .PARAMETER Url
    Source URL.
  .PARAMETER Upstream
    Upstream release object, if any.
  .EXAMPLE
    New-PackResult -Pack $pack -Status 'CHECK' -Source 'map' -Name 'X' -Url 'https://x'
    Returns the result row.
  .OUTPUTS
    System.Management.Automation.PSCustomObject
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param (
    # Installed pack
    [Parameter(Mandatory)]
    [pscustomobject]$Pack,

    # Status
    [Parameter(Mandatory)]
    [string]$Status,

    # Source
    [Parameter(Mandatory)]
    [string]$Source,

    # Name
    [Parameter(Mandatory)]
    [string]$Name,

    # Url
    [Parameter(Mandatory)]
    [string]$Url,

    # Upstream release
    [pscustomobject]$Upstream
  )
  process {
    [pscustomobject]@{
      Status      = $Status
      Source      = $Source
      Kind        = $Pack.Kind
      PackType    = $Pack.PackType
      Name        = $Name
      Installed   = $Pack.Installed
      Latest      = if ($Upstream) { $Upstream.Date } else { $null }
      Url         = $Url
      Uuid        = $Pack.Uuid
      Version     = $Pack.Version
      Path        = $Pack.Path
      FileName    = if ($Upstream) { $Upstream.FileName } else { $null }
      DownloadUrl = if ($Upstream) { $Upstream.DownloadUrl } else { $null }
    }
  }
}


function Add-PackSourceEntry {
  <#
  .SYNOPSIS
    Appends a source entry to the .psd1 map as text, preserving existing comments and layout.
  .PARAMETER Path
    Source map file.
  .PARAMETER Key
    Pack UUID, or mod name.
  .PARAMETER Name
    Display name.
  .PARAMETER Url
    Upstream project URL.
  .EXAMPLE
    Add-PackSourceEntry -Path .\bedrock-packs.psd1 -Key $uuid -Name 'X' -Url 'https://github.com/a/b'
    Adds the entry unless the key is already present; restores the file if the result does not parse.
  .OUTPUTS
    System.Boolean
  #>
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([bool])]
  param (
    # Map file
    [Parameter(Mandatory)]
    [string]$Path,

    # UUID or mod name
    [Parameter(Mandatory)]
    [string]$Key,

    # Display name
    [Parameter(Mandatory)]
    [string]$Name,

    # Source URL
    [Parameter(Mandatory)]
    [string]$Url
  )
  process {
    $text = Get-Content -LiteralPath $Path -Raw
    $quotedKey = "'" + ($Key -replace "'", "''") + "'"
    if ($text.Contains($quotedKey)) { return $false }
    if (-not $PSCmdlet.ShouldProcess($Path, "Map '$Name'")) { return $false }

    $close = $text.LastIndexOf('}')
    if ($close -lt 0) { throw "Source map has no closing brace: $Path" }

    $safeName = $Name -replace "'", "''"
    $safeUrl = $Url -replace "'", "''"
    $block = "`n  # Auto-discovered $(Get-Date -Format 'yyyy-MM-dd')`n" +
      "  $quotedKey = @{ Name = '$safeName'; Url = '$safeUrl' }`n"
    $updated = $text.Insert($close, $block)

    $utf8 = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
    [System.IO.File]::WriteAllText($Path, $updated, $utf8)
    try {
      $null = Import-PowerShellDataFile -LiteralPath $Path
    } catch {
      $err = $_
      [System.IO.File]::WriteAllText($Path, $text, $utf8)
      throw "Map edit for '$Name' broke $Path, restored: $($err.Exception.Message)"
    }
    $true
  }
}


function Expand-PackArchive {
  <#
  .SYNOPSIS
    Unpacks a .mcaddon/.mcpack/.zip, including archives nested inside it, and lists the packs found.
  .PARAMETER Path
    Archive to unpack.
  .PARAMETER Destination
    Empty working directory.
  .EXAMPLE
    Expand-PackArchive -Path .\addon.mcaddon -Destination $env:TEMP\work
    Returns one object per manifest.json found, with its directory, UUID, version and pack type.
  .OUTPUTS
    System.Management.Automation.PSCustomObject
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param (
    # Archive file
    [Parameter(Mandatory)]
    [string]$Path,

    # Working directory
    [Parameter(Mandatory)]
    [string]$Destination
  )
  process {
    # Windows PowerShell 5.1 Expand-Archive refuses anything but .zip, so use the .NET class
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Path, (Join-Path -Path $Destination -ChildPath 'root'))

    $seen = @{}
    do {
      $nested = @(Get-ChildItem -LiteralPath $Destination -Recurse -File |
          Where-Object { $_.Extension -in '.mcpack', '.mcaddon', '.zip' -and -not $seen[$_.FullName] })
      foreach ($file in $nested) {
        $seen[$file.FullName] = $true
        [System.IO.Compression.ZipFile]::ExtractToDirectory($file.FullName, "$($file.FullName).d")
      }
    } while ($nested.Count -gt 0)

    foreach ($manifestFile in Get-ChildItem -LiteralPath $Destination -Recurse -Filter 'manifest.json') {
      try {
        $manifest = ConvertFrom-JsonComment -Text (Get-Content -LiteralPath $manifestFile.FullName -Raw) |
          ConvertFrom-Json
      } catch {
        Write-Verbose "Unreadable manifest in archive: $($manifestFile.FullName)"
        continue
      }
      if (-not $manifest.header.uuid) { continue }
      [pscustomobject]@{
        Dir      = $manifestFile.DirectoryName
        Uuid     = [string]$manifest.header.uuid
        Version  = @($manifest.header.version | ForEach-Object { [int]$_ })
        Name     = Get-PackDisplayName -Name $manifest.header.name
        PackType = Get-ManifestPackType -Manifest $manifest -Fallback 'BP'
      }
    }
  }
}


function Find-PackMatch {
  <#
  .SYNOPSIS
    Picks the unpacked pack that replaces an installed one.
  .PARAMETER Installed
    Result row for the installed pack.
  .PARAMETER Candidate
    Packs unpacked from the downloaded archive.
  .PARAMETER GroupSize
    Installed packs of the same pack type that share this download.
  .EXAMPLE
    Find-PackMatch -Installed $row -Candidate $unpacked -GroupSize 1
    Matches by UUID, then by pack type plus name key, then by being the only one of its type.
  .OUTPUTS
    System.Management.Automation.PSCustomObject
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param (
    # Installed pack
    [Parameter(Mandatory)]
    [pscustomobject]$Installed,

    # Unpacked packs
    [Parameter(Mandatory)]
    [object[]]$Candidate,

    # Same-type installed packs sharing the download
    [Parameter(Mandatory)]
    [int]$GroupSize
  )
  process {
    $byUuid = @($Candidate | Where-Object { $_.Uuid -eq $Installed.Uuid })
    if ($byUuid.Count -eq 1) { return $byUuid[0] }

    $sameType = @($Candidate | Where-Object { $_.PackType -eq $Installed.PackType })
    $key = ConvertTo-PackKey -Name $Installed.Name
    $byName = @($sameType | Where-Object { $key -and (ConvertTo-PackKey -Name $_.Name) -eq $key })
    if ($byName.Count -eq 1) { return $byName[0] }

    if ($sameType.Count -eq 1 -and $GroupSize -eq 1) { return $sameType[0] }
  }
}


function Install-PackUpdate {
  <#
  .SYNOPSIS
    Replaces an installed pack folder with a new one, keeping the old one in a backup folder.
  .PARAMETER OldPath
    Installed pack folder.
  .PARAMETER NewPath
    Unpacked replacement folder.
  .PARAMETER BackupDir
    Run-specific backup directory.
  .EXAMPLE
    Install-PackUpdate -OldPath $old -NewPath $new -BackupDir $backup
    Moves $old into $backup, then copies $new to $old and stamps its manifest with the current time.
  .OUTPUTS
    None
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param (
    # Installed folder
    [Parameter(Mandatory)]
    [string]$OldPath,

    # Replacement folder
    [Parameter(Mandatory)]
    [string]$NewPath,

    # Backup directory
    [Parameter(Mandatory)]
    [string]$BackupDir
  )
  process {
    if (-not $PSCmdlet.ShouldProcess($OldPath, 'Replace pack')) { return }

    $kindDir = Split-Path -Path $OldPath -Parent
    $backupTarget = Join-Path -Path (Join-Path -Path $BackupDir -ChildPath (Split-Path -Path $kindDir -Leaf)) `
      -ChildPath (Split-Path -Path $OldPath -Leaf)
    $null = New-Item -ItemType Directory -Path (Split-Path -Path $backupTarget -Parent) -Force
    Move-Item -LiteralPath $OldPath -Destination $backupTarget

    try {
      Copy-Item -LiteralPath $NewPath -Destination $OldPath -Recurse
    } catch {
      $err = $_
      # Put the old pack back rather than leave the game without it
      if (Test-Path -LiteralPath $OldPath) { Remove-Item -LiteralPath $OldPath -Recurse -Force }
      Move-Item -LiteralPath $backupTarget -Destination $OldPath
      throw "Copy failed, old pack restored: $($err.Exception.Message)"
    }

    # The report compares the manifest timestamp to the upload date; zip entries carry the old one
    (Get-Item -LiteralPath (Join-Path -Path $OldPath -ChildPath 'manifest.json')).LastWriteTime = Get-Date
  }
}


function Update-WorldPackReference {
  <#
  .SYNOPSIS
    Points every world's pack list at a replaced pack's new UUID and version.
  .PARAMETER Root
    com.mojang directory.
  .PARAMETER OldUuid
    UUID of the pack that was replaced.
  .PARAMETER NewUuid
    UUID of the replacement.
  .PARAMETER NewVersion
    Version triplet of the replacement.
  .PARAMETER BackupDir
    Run-specific backup directory; each edited file is copied here first.
  .EXAMPLE
    Update-WorldPackReference -Root $root -OldUuid $a -NewUuid $b -NewVersion 1, 2, 0 -BackupDir $backup
    Rewrites pack_id/version in each world file that referenced $a.
  .OUTPUTS
    System.Int32
  #>
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([int])]
  param (
    # com.mojang directory
    [Parameter(Mandatory)]
    [string]$Root,

    # Old UUID
    [Parameter(Mandatory)]
    [string]$OldUuid,

    # New UUID
    [Parameter(Mandatory)]
    [string]$NewUuid,

    # New version
    [Parameter(Mandatory)]
    [int[]]$NewVersion,

    # Backup directory
    [Parameter(Mandatory)]
    [string]$BackupDir
  )
  process {
    $edited = 0
    $worlds = Join-Path -Path $Root -ChildPath 'minecraftWorlds'
    if (Test-Path -LiteralPath $worlds) {
      $files = Get-ChildItem -LiteralPath $worlds -Directory |
        ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -File -Filter 'world_*_packs.json' }
      foreach ($file in $files) {
        $entries = @(Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json)
        $hits = @($entries | Where-Object { $_.pack_id -eq $OldUuid })
        if ($hits.Count -eq 0) { continue }
        if (-not $PSCmdlet.ShouldProcess($file.FullName, "Repoint $OldUuid")) { continue }

        $worldBackup = Join-Path -Path (Join-Path -Path $BackupDir -ChildPath 'worlds') -ChildPath $file.Directory.Name
        $null = New-Item -ItemType Directory -Path $worldBackup -Force
        Copy-Item -LiteralPath $file.FullName -Destination $worldBackup

        foreach ($hit in $hits) {
          $hit.pack_id = $NewUuid
          $hit.version = $NewVersion
        }
        # -InputObject keeps a one-element list a JSON array
        $json = ConvertTo-Json -InputObject @($entries) -Depth 5
        $utf8 = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
        [System.IO.File]::WriteAllText($file.FullName, $json, $utf8)
        $edited++
      }
    }
    $edited
  }
}


function Invoke-PackUpdate {
  <#
  .SYNOPSIS
    Downloads, matches and installs the updates for one shared download URL.
  .PARAMETER Group
    OUTDATED result rows that share one DownloadUrl.
  .PARAMETER Root
    com.mojang directory.
  .PARAMETER MapPath
    Source map to record changed UUIDs in.
  .PARAMETER BackupDir
    Run-specific backup directory.
  .PARAMETER SkipWorldRefs
    Do not rewrite world pack lists.
  .EXAMPLE
    Invoke-PackUpdate -Group $rows -Root $root -MapPath $map -BackupDir $backup
    Installs the update and returns one summary row per replaced pack.
  .OUTPUTS
    System.Management.Automation.PSCustomObject
  #>
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([pscustomobject])]
  param (
    # Rows sharing a download
    [Parameter(Mandatory)]
    [object[]]$Group,

    # com.mojang directory
    [Parameter(Mandatory)]
    [string]$Root,

    # Source map
    [Parameter(Mandatory)]
    [string]$MapPath,

    # Backup directory
    [Parameter(Mandatory)]
    [string]$BackupDir,

    # Skip world edits
    [switch]$SkipWorldRefs
  )
  process {
    $first = $Group[0]
    if (-not $PSCmdlet.ShouldProcess($first.DownloadUrl, "Download and install $($Group.Count) pack(s)")) {
      return
    }

    $work = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([guid]::NewGuid().ToString())
    $null = New-Item -ItemType Directory -Path $work
    try {
      $archive = Join-Path -Path $work -ChildPath 'download.bin'
      Invoke-WebRequest -Uri $first.DownloadUrl -OutFile $archive -UseBasicParsing -TimeoutSec 120
      $unpacked = @(Expand-PackArchive -Path $archive -Destination (Join-Path -Path $work -ChildPath 'x'))

      foreach ($row in $Group) {
        $sameType = @($Group | Where-Object { $_.PackType -eq $row.PackType })
        $match = Find-PackMatch -Installed $row -Candidate $unpacked -GroupSize $sameType.Count
        if (-not $match) {
          Write-Warn "No unambiguous replacement for '$($row.Name)' in $($first.FileName), skipped"
          continue
        }

        Install-PackUpdate -OldPath $row.Path -NewPath $match.Dir -BackupDir $BackupDir
        $worldFiles = 0
        if (-not $SkipWorldRefs) {
          $worldFiles = Update-WorldPackReference -Root $Root -OldUuid $row.Uuid -NewUuid $match.Uuid `
            -NewVersion $match.Version -BackupDir $BackupDir
        }
        if ($match.Uuid -ne $row.Uuid) {
          $null = Add-PackSourceEntry -Path $MapPath -Key $match.Uuid -Name $row.Name -Url $row.Url
        }
        [pscustomobject]@{ Name = $row.Name; OldUuid = $row.Uuid; NewUuid = $match.Uuid; Worlds = $worldFiles }
      }
    } finally {
      Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}


function Invoke-UpdateRun {
  <#
  .SYNOPSIS
    Maps newly detected packs into the source map and installs every available update.
  .PARAMETER Result
    Rows produced by the report.
  .PARAMETER Root
    com.mojang directory.
  .PARAMETER MapPath
    Source map to extend.
  .PARAMETER BackupPath
    Base backup directory; a timestamped folder is created under it.
  .PARAMETER SkipWorldRefs
    Do not rewrite world pack lists.
  .EXAMPLE
    Invoke-UpdateRun -Result $results -Root $root -MapPath $map -BackupPath $backup
    Writes new map entries, installs updates, and prints what still needs a manual look.
  .OUTPUTS
    None
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param (
    # Report rows
    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [object[]]$Result,

    # com.mojang directory
    [Parameter(Mandatory)]
    [string]$Root,

    # Source map
    [Parameter(Mandatory)]
    [string]$MapPath,

    # Backup base directory
    [Parameter(Mandatory)]
    [string]$BackupPath,

    # Skip world edits
    [switch]$SkipWorldRefs
  )
  process {
    $backupDir = Join-Path -Path $BackupPath -ChildPath (Get-Date -Format 'yyyyMMdd-HHmmss')
    Write-Header 'Bedrock pack update'

    $mapped = 0
    foreach ($row in $Result | Where-Object { $_.Source -in 'manifest', 'sibling', 'search' }) {
      if (Add-PackSourceEntry -Path $MapPath -Key $row.Uuid -Name $row.Name -Url $row.Url) {
        Write-Info "Mapped $($row.Name) -> $($row.Url) ($($row.Source))"
        $mapped++
      }
    }

    $outdated = @($Result | Where-Object { $_.Status -eq 'OUTDATED' })
    $installable = @($outdated | Where-Object { $_.DownloadUrl -and $_.Kind -ne 'Mod' })
    $done = @()
    foreach ($group in $installable | Group-Object -Property DownloadUrl) {
      try {
        $done += @(Invoke-PackUpdate -Group $group.Group -Root $Root -MapPath $MapPath `
            -BackupDir $backupDir -SkipWorldRefs:$SkipWorldRefs)
      } catch {
        $err = $_
        Write-Warn "Update from $($group.Name) failed: $($err.Exception.Message)"
      }
    }

    foreach ($row in $done) {
      Write-Success "Updated $($row.Name) ($($row.Worlds) world file(s) repointed)"
    }
    Write-Info "$mapped newly mapped, $($done.Count) of $($outdated.Count) outdated packs installed"
    if ($done.Count -gt 0) { Write-Info "Backups: $backupDir" }

    $manual = @($Result | Where-Object {
        $_.Status -in 'OUTDATED', 'CHECK', 'CANDIDATE', 'UNMAPPED', 'ERROR' -and $_.Name -notin $done.Name
      })
    foreach ($row in $manual) {
      Write-Warn ("{0,-9} {1} - {2}" -f $row.Status, $row.Name, $row.Url)
    }
  }
}


# Dot-sourcing (tests do this) loads the functions without running a check
if ($MyInvocation.InvocationName -eq '.') { return }

if ($PackRoot -or $ModRoot) {
  $instance = $null
} else {
  $instance = Resolve-Instance -Version $Version
}

$root = if ($PackRoot) { $PackRoot } else { Join-Path -Path $instance -ChildPath 'Minecraft Bedrock\Users\Shared\games\com.mojang' }
if (-not (Test-Path -LiteralPath $root)) {
  throw "Pack root not found: $root"
}

$modRoot = if ($ModRoot) { $ModRoot } elseif ($instance) { Join-Path -Path $instance -ChildPath 'mods' } else { $null }

$sources = if (Test-Path -LiteralPath $SourceMap) {
  Import-PowerShellDataFile -LiteralPath $SourceMap
} else {
  Write-Warn "Source map not found: $SourceMap - every pack will report UNMAPPED"
  @{}
}

Write-Header 'Bedrock pack updates'
Write-Info $root

$lookupFailed = $false
# Packs that share a URL (a pack's BP and RP are usually one CurseForge project) share one lookup.
$upstreamCache = @{}
$installed = @(Get-InstalledPack -Path $root)
if ($modRoot -and (Test-Path -LiteralPath $modRoot)) {
  $installed += @(Get-InstalledMod -Path $modRoot)
} else {
  Write-Verbose "No mods directory, skipping mod checks: $modRoot"
}

$results = foreach ($pack in $installed) {
  $entry = $sources[$pack.Uuid]
  $name = if ($entry -and $entry.Name) { $entry.Name } else { $pack.Name }
  if (-not $name) { $name = $pack.Folder }
  $source = 'map'

  if (-not $entry) {
    $found = $null
    try {
      $found = Find-PackSource -Pack $pack -Sources $sources
    } catch {
      $err = $_
      Write-Verbose "Source search failed for '$name': $($err.Exception.Message)"
    }

    if ($found -and $found.Source -ne 'candidate') {
      $entry = @{ Name = $name; Url = $found.Url }
      $source = $found.Source
    } else {
      $query = [uri]::EscapeDataString($name)
      $searchUrl = if ($found) {
        $found.Url
      } elseif ($pack.Kind -eq 'Mod') {
        "https://github.com/search?q=$query&type=repositories"
      } else {
        # Unfiltered by class on purpose - Bedrock packs live under addons, texture-packs and scripts
        "https://www.curseforge.com/minecraft-bedrock/search?search=$query"
      }
      $status = if ($found) { 'CANDIDATE' } else { 'UNMAPPED' }
      New-PackResult -Pack $pack -Status $status -Source $(if ($found) { 'candidate' } else { 'none' }) `
        -Name $name -Url $searchUrl
      continue
    }
  }

  if ($upstreamCache.ContainsKey($entry.Url)) {
    $upstream = $upstreamCache[$entry.Url]
  } else {
    try {
      $upstream = Get-UpstreamRelease -Url $entry.Url
      $upstreamCache[$entry.Url] = $upstream
    } catch {
      $err = $_
      Write-Verbose "Lookup failed for '$name': $($err.Exception.Message)"
      $upstream = $null
      $lookupFailed = $true
    }
  }

  if (-not $upstream) {
    # Either the URL has no API behind it, or the lookup threw
    $status = if ($lookupFailed) { 'ERROR' } else { 'CHECK' }
    New-PackResult -Pack $pack -Status $status -Source $source -Name $name -Url $entry.Url
    $lookupFailed = $false
    continue
  }

  $status = if ($upstream.Date -gt $pack.Installed) { 'OUTDATED' } else { 'current' }
  New-PackResult -Pack $pack -Status $status -Source $source -Name $name -Url $entry.Url -Upstream $upstream
}

if ($AsObject) {
  $results
} else {
  $order = @{ OUTDATED = 0; ERROR = 1; CHECK = 2; CANDIDATE = 3; UNMAPPED = 4; current = 5 }
  $sorted = $results | Sort-Object -Property @{ Expression = { $order[$_.Status] } }, Name

  # URLs are too long to share a table with the rest, so they go in a list underneath
  $sorted | Format-Table -Property Status, Source, Kind, Name,
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
  $autoMapped = @($results | Where-Object { $_.Source -in 'manifest', 'sibling', 'search' }).Count
  if ($autoMapped -gt 0) {
    Write-Info "$autoMapped packs auto-matched to a source; re-run with -Update to save and install"
  }
  Write-Info "$($results.Count - $checked) of $($results.Count) packs need a manual look ($unmapped with no source URL yet)"
}

if ($Update) {
  Invoke-UpdateRun -Result @($results) -Root $root -MapPath $SourceMap -BackupPath $BackupPath `
    -SkipWorldRefs:$SkipWorlds
}
