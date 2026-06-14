#!/usr/bin/env pwsh
#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Deploys dotfiles and sets up a Windows development environment.
.DESCRIPTION
    Canonical implementation of the dotbot bootstrap process. Installs tools via winget,
    deploys config files with hash-based change detection, and configures the environment
    non-interactively. Can be run standalone or via dotbot.
.EXAMPLE
    .\Setup-Dotfiles.ps1
.EXAMPLE
    .\Setup-Dotfiles.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Unattended,
    [switch]$SkipWingetTools,
    [switch]$SkipWSL,
    [string[]]$Target
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

function Deploy-Config {
  <#
  .SYNOPSIS
      Deploys a config file, copying only if the source differs from the destination.
  .PARAMETER Source
      Full path to the source file.
  .PARAMETER Destination
      Full path to the destination file.
  .PARAMETER Label
      Human-readable label for output messages.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [string]$Source,
    [string]$Destination,
    [string]$Label
  )

  if (-not (Test-Path $Source)) {
    Write-Warning "  [SKIP] $Label - source not found: $Source"
    return
  }

  $destDir = Split-Path $Destination -Parent
  $srcHash = (Get-FileHash $Source -Algorithm SHA256).Hash

  if (Test-Path $Destination) {
    $dstHash = (Get-FileHash $Destination -Algorithm SHA256).Hash
    if ($srcHash -eq $dstHash) {
      Write-Host "  [UP-TO-DATE] $Label" -ForegroundColor Gray
      return
    }
  }

  if ($PSCmdlet.ShouldProcess($Destination, "Deploy $Label")) {
    if (-not (Test-Path $destDir)) {
      $null = New-Item -ItemType Directory -Path $destDir -Force
    }
    Copy-Item -Path $Source -Destination $Destination -Force
    Write-Host "  [OK] $Label deployed" -ForegroundColor Green
  }
}

function Deploy-ConfigDirectory {
  <#
  .SYNOPSIS
      Deploys all files matching a filter from a source directory to a destination directory.
  .PARAMETER SourceDir
      Path to the source directory.
  .PARAMETER DestDir
      Path to the destination directory.
  .PARAMETER Filter
      File filter pattern (default: *).
  .PARAMETER Label
      Human-readable label for output messages.
  .PARAMETER Recurse
      When set, walks subdirectories and preserves relative path structure in destination.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [string]$SourceDir,
    [string]$DestDir,
    [string]$Filter = '*',
    [string]$Label,
    [switch]$Recurse
  )

  if (-not (Test-Path $SourceDir)) {
    Write-Warning "  [SKIP] $Label - source directory not found: $SourceDir"
    return
  }

  $getChildArgs = @{ Path = $SourceDir; Filter = $Filter; File = $true }
  if ($Recurse) { $getChildArgs['Recurse'] = $true }
  $files = Get-ChildItem @getChildArgs

  if ($files.Count -eq 0) {
    Write-Host "  [SKIP] $Label - no files matching '$Filter' in $SourceDir" -ForegroundColor Gray
    return
  }

  foreach ($file in $files) {
    if ($Recurse) {
      $relPath = $file.FullName.Substring($SourceDir.Length).TrimStart('\', '/')
      $dest = Join-Path $DestDir $relPath
    } else {
      $dest = Join-Path $DestDir $file.Name
    }
    Deploy-Config -Source $file.FullName -Destination $dest -Label "$Label/$($file.Name)"
  }
}

function Import-RegistryConfig {
  <#
  .SYNOPSIS
      Imports a registry file into the local registry.
  .PARAMETER Source
      Full path to the .reg file.
  .PARAMETER Label
      Human-readable label for output messages.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [string]$Source,
    [string]$Label
  )

  if (-not (Test-Path $Source)) {
    Write-Warning "  [SKIP] $Label - source not found: $Source"
    return
  }

  if ($PSCmdlet.ShouldProcess('Registry', "Import $Label")) {
    $null = & reg.exe import $Source 2>&1
    if ($LASTEXITCODE -eq 0) {
      Write-Host "  [OK] $Label imported" -ForegroundColor Green
    } else {
      Write-Warning "  [WARN] $Label - reg import exit code: $LASTEXITCODE"
    }
  }
}

function Get-FirefoxDefaultProfilePath {
  $profilesIni = Join-Path $env:APPDATA 'Mozilla\Firefox\profiles.ini'
  if (-not (Test-Path $profilesIni)) {
    return $null
  }

  $profiles = [System.Collections.Generic.List[hashtable]]::new()
  $currentProfile = $null

  foreach ($line in [System.IO.File]::ReadLines($profilesIni)) {
    if ($line -match '^\[(?<section>[^\]]+)\]$') {
      if ($currentProfile -and $currentProfile.Section -like 'Profile*') {
        $profiles.Add($currentProfile)
      }
      $currentProfile = @{ Section = $matches.section }
      continue
    }

    if ($currentProfile -and $line -match '^(?<key>[^=]+)=(?<value>.*)$') {
      $currentProfile[$matches.key] = $matches.value
    }
  }

  if ($currentProfile -and $currentProfile.Section -like 'Profile*') {
    $profiles.Add($currentProfile)
  }

  if ($profiles.Count -eq 0) {
    return $null
  }

  $defaultProfile = $profiles | Where-Object { $_.Default -eq '1' } | Select-Object -First 1
  if (-not $defaultProfile) {
    $defaultProfile = $profiles | Select-Object -First 1
  }

  if (-not $defaultProfile.Path) {
    return $null
  }

  if ($defaultProfile.IsRelative -eq '1') {
    return Join-Path (Split-Path $profilesIni -Parent) $defaultProfile.Path
  }

  return $defaultProfile.Path
}

function Get-CallOfDutyPlayersPath {
  $playersPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Call of Duty\players'
  if (Test-Path $playersPath) {
    return $playersPath
  }

  return $null
}

function Get-StarWarsBattlefrontIIRootPath {
  return (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Star Wars Battlefront II')
}

function Get-StarWarsBattlefrontIIActiveProfilePath {
  $bf2Root = Get-StarWarsBattlefrontIIRootPath
  $profilesDir = Join-Path $bf2Root 'Profiles'
  if (-not (Test-Path $profilesDir)) {
    return $null
  }

  $globalConfigPath = Join-Path $profilesDir 'Global.con'
  if (Test-Path $globalConfigPath) {
    switch -Regex -File $globalConfigPath {
      'GlobalSettings\.setDefaultUser\s+"?(?<profileId>[^"\r\n]+)"?' {
        $profilePath = Join-Path $profilesDir $matches.profileId
        if (Test-Path $profilePath) {
          return $profilePath
        }
      }
    }
  }

  return (
    Get-ChildItem -Path $profilesDir -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -ne 'Default' } |
      Sort-Object Name |
      Select-Object -First 1 -ExpandProperty FullName
  )
}

function Set-CmdAliasAutoRun {
  <#
  .SYNOPSIS
      Configures cmd.exe AutoRun to load the tracked DOSKEY aliases.
  .PARAMETER AliasScript
      Full path to alias.cmd.
  .PARAMETER Label
      Human-readable label for output messages.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [string]$AliasScript,
    [string]$Label
  )

  if (-not (Test-Path $AliasScript)) {
    Write-Warning "  [SKIP] $Label - alias script not found: $AliasScript"
    return
  }

  $commandProcessorKey = 'HKCU:\Software\Microsoft\Command Processor'
  $autoRunSnippet = "if exist `"$AliasScript`" call `"$AliasScript`""
  $autoRunProp = Get-ItemProperty -Path $commandProcessorKey -Name AutoRun -ErrorAction SilentlyContinue
  $currentAutoRun = if ($autoRunProp) { $autoRunProp.AutoRun } else { $null }

  if ($currentAutoRun -and $currentAutoRun -match [regex]::Escape($AliasScript)) {
    Write-Host "  [UP-TO-DATE] $Label" -ForegroundColor Gray
    return
  }

  $newAutoRun = if ([string]::IsNullOrWhiteSpace($currentAutoRun)) {
    $autoRunSnippet
  } else {
    "$currentAutoRun & $autoRunSnippet"
  }

  if ($PSCmdlet.ShouldProcess($commandProcessorKey, "Configure $Label")) {
    if (-not (Test-Path $commandProcessorKey)) {
      $null = New-Item -Path $commandProcessorKey -Force
    }
    $null = New-ItemProperty -Path $commandProcessorKey -Name AutoRun -Value $newAutoRun -PropertyType String -Force
    Write-Host "  [OK] $Label configured" -ForegroundColor Green
  }
}

function Deploy-StarWarsBattlefrontIIConfig {
  <#
  .SYNOPSIS
      Deploys Star Wars Battlefront II (2017) configs into the root config folder and active profile.
  .PARAMETER SourceDir
      Full path to the tracked Star Wars Battlefront II (2017) config directory.
  .PARAMETER Label
      Human-readable label for output messages.
  #>
  [CmdletBinding()]
  param(
    [string]$SourceDir,
    [string]$Label
  )

  if (-not (Test-Path $SourceDir)) {
    return
  }

  $bf2Root = Get-StarWarsBattlefrontIIRootPath
  if (-not (Test-Path $bf2Root)) {
    Write-Warning "  [SKIP] $Label - Star Wars Battlefront II (2017) config directory not found: $bf2Root"
    return
  }

  $activeProfilePath = Get-StarWarsBattlefrontIIActiveProfilePath
  if (-not $activeProfilePath) {
    $profilesDir = Join-Path $bf2Root 'Profiles'
    Write-Warning "  [SKIP] $Label - active Star Wars Battlefront II (2017) profile not found under: $profilesDir"
    return
  }

  $rootFiles = @('BootOptions', 'user.cfg')
  foreach ($fileName in $rootFiles) {
    $sourcePath = Join-Path $SourceDir $fileName
    if (Test-Path $sourcePath) {
      Deploy-Config -Source $sourcePath -Destination (Join-Path $bf2Root $fileName) -Label "$Label/$fileName"
    }
  }

  $profileOptionsPath = Join-Path $SourceDir 'ProfileOptions_profile'
  if (Test-Path $profileOptionsPath) {
    $deployParams = @{
      Source      = $profileOptionsPath
      Destination = Join-Path $activeProfilePath 'ProfileOptions_profile'
      Label       = "$Label/ProfileOptions_profile"
    }
    Deploy-Config @deployParams
  }
}

function Invoke-ConfigManifestEntry {
  <#
  .SYNOPSIS
      Resolves and applies a manifest-driven config deployment entry.
  .PARAMETER Entry
      Manifest entry describing the deployment action.
  #>
  [CmdletBinding()]
  param(
    [hashtable]$Entry
  )

  $sourcePath = Join-Path $configRoot $Entry.Path
  if (-not (Test-Path $sourcePath)) {
    return
  }

  switch ($Entry.Mode) {
    'file' {
      $destination = & $Entry.ResolveDestination
      if ($destination) {
        Deploy-Config -Source $sourcePath -Destination $destination -Label $Entry.Label
      } else {
        Write-Warning "  [SKIP] $($Entry.Label) - $(& $Entry.GetSkipReason)"
      }
    }
    'directory' {
      $destination = & $Entry.ResolveDestination
      if ($destination) {
        $dirArgs = @{
          SourceDir = $sourcePath
          DestDir   = $destination
          Filter    = $Entry.Filter
          Label     = $Entry.Label
        }
        if ($Entry.ContainsKey('Recurse') -and $Entry.Recurse) { $dirArgs['Recurse'] = $true }
        Deploy-ConfigDirectory @dirArgs
      } else {
        Write-Warning "  [SKIP] $($Entry.Label) - $(& $Entry.GetSkipReason)"
      }
    }
    'registry' {
      Import-RegistryConfig -Source $sourcePath -Label $Entry.Label
    }
    'manual' {
      Write-Warning "  [MANUAL] $($Entry.Label) - $($Entry.Note)"
    }
    'script' {
      & $Entry.Invoke $sourcePath $Entry.Label
    }
  }
}

function Install-WingetTool {
  <#
  .SYNOPSIS
      Installs a package via winget. Treats exit codes 0 and -1978335189 (already installed) as success.
  .DESCRIPTION
      Uses Wait-ForWinget from Common.ps1 to ensure winget is available before invoking.
  .PARAMETER Id
      Winget package identifier.
  .PARAMETER Name
      Human-readable tool name for output messages.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [string]$Id,
    [string]$Name
  )

  $winget = Wait-ForWinget

  if ($PSCmdlet.ShouldProcess($Name, 'Install via winget')) {
    Write-Host "  Installing $Name..." -ForegroundColor Gray -NoNewline
    try {
      $wingetArgs = @('install', '--id', $Id, '--silent', '--accept-source-agreements', '--accept-package-agreements')
      if ($isAdmin) { $wingetArgs += @('--scope', 'machine') }
      & $winget @wingetArgs *>$null
      $ec = $LASTEXITCODE
      # 0 = success, -1978335189 (0x8A150021) = already installed at required version
      if ($ec -eq 0 -or $ec -eq -1978335189) {
        Write-Host " [OK]" -ForegroundColor Green
      } else {
        Write-Host ""
        Write-Warning "  [WARN] $Name - winget exit code: $ec"
      }
    } catch {
      Write-Host ""
      Write-Warning "  [WARN] $Name - $_"
    }
  }
}

function Start-Bootstrap {
  [CmdletBinding(SupportsShouldProcess)]
  param(
      [switch]$Unattended,
      [switch]$SkipWingetTools,
      [switch]$SkipWSL,
      [string[]]$Target
  )

  # $Unattended and $SkipWSL are accepted for forward-compatibility and passed
  # through from the outer param block; they are not yet implemented.
  if ($Unattended) { Write-Verbose 'Unattended mode requested (not yet implemented).' }
  if ($SkipWSL) { Write-Verbose 'SkipWSL requested; WSL config entry will still appear in manifest but can be excluded via -Target.' }

  # ---------------------------------------------------------------------------
  # Admin elevation
  # ---------------------------------------------------------------------------
  $isAdmin = $false
  try {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
      [Security.Principal.WindowsBuiltInRole]::Administrator
    )
  } catch {
    Write-Verbose "Could not determine admin status: $($_.Exception.Message)"
  }
  if (-not $isAdmin -and (Get-Variable IsWindows -ValueOnly -ErrorAction SilentlyContinue)) {
    Write-Host 'Relaunching as administrator...' -ForegroundColor Yellow
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    $shell = if ($pwshCmd) { $pwshCmd.Source } else { 'PowerShell.exe' }
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($WhatIfPreference) { $argList += ' -WhatIf' }
    Start-Process -FilePath $shell -ArgumentList $argList -Verb RunAs
    return
  }

  # ---------------------------------------------------------------------------
  # Phase 1: Prerequisites & execution policy
  # ---------------------------------------------------------------------------
  Write-Host ''
  Write-Host '[1/5] Setting execution policy...' -ForegroundColor Cyan

  try {
    if ($PSCmdlet.ShouldProcess('CurrentUser execution policy', 'Set to RemoteSigned')) {
      Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
      Write-Host '  [OK] Execution policy set to RemoteSigned (CurrentUser)' -ForegroundColor Green
    }
  } catch {
    Write-Warning "  Could not set execution policy: $_"
  }

  # ---------------------------------------------------------------------------
  # Phase 2: Install tools via winget
  # ---------------------------------------------------------------------------
  Write-Host ''
  if ($SkipWingetTools) {
      Write-Host '[2/5] Tool installation skipped (-SkipWingetTools)' -ForegroundColor Cyan
  } else {
      Write-Host '[2/5] Installing tools...' -ForegroundColor Cyan

      try {
          $null = Wait-ForWinget
      } catch {
          Write-Warning "  winget not available: $_. Install from: https://aka.ms/getwinget"
      }
      if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
          Write-Warning '  winget not found. Install from: https://aka.ms/getwinget'
      } else {
          $tools = @(
              @{ id = 'Git.Git';                    name = 'Git' },
              @{ id = 'Microsoft.PowerShell';       name = 'PowerShell 7+' },
              @{ id = 'Microsoft.WindowsTerminal';  name = 'Windows Terminal' },
              @{ id = 'Microsoft.VisualStudioCode'; name = 'VS Code' }
          )

          foreach ($tool in $tools) {
              Install-WingetTool -Id $tool.id -Name $tool.name
          }
      }
  }

  # ---------------------------------------------------------------------------
  # Phase 3: Deploy configs
  # ---------------------------------------------------------------------------
  Write-Host ''
  Write-Host '[3/5] Deploying configs...' -ForegroundColor Cyan

  $appData = if ($env:APPDATA) { $env:APPDATA } else { '/tmp/AppData' }
  $firefoxProfilesRoot = Join-Path $appData 'Mozilla\Firefox'

  $configManifest = @(
    @{
      Path               = 'powershell\profile.ps1'
      Mode               = 'file'
      Label              = 'PowerShell profile'
      ResolveDestination = { $PROFILE }
    },
    @{
      Path               = 'windows-terminal\settings.json'
      Mode               = 'file'
      Label              = 'Windows Terminal settings'
      ResolveDestination = {
        Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Filter 'Microsoft.WindowsTerminal_*' -Directory -ErrorAction SilentlyContinue |
          Select-Object -First 1 | ForEach-Object { Join-Path -Path $_.FullName -ChildPath 'LocalState\settings.json' }
      }
      GetSkipReason      = { 'Windows Terminal package directory not found' }
    },
    @{
      Path               = 'bleachbit\cleaners'
      Mode               = 'directory'
      Label              = 'BleachBit cleaners'
      Filter             = '*.xml'
      ResolveDestination = { "$env:APPDATA\BleachBit\cleaners" }
    },
    @{
      Path               = 'firefox\user.js'
      Mode               = 'file'
      Label              = 'Firefox user.js'
    ResolveDestination = { $profilePath = Get-FirefoxDefaultProfilePath
      if ($profilePath) { Join-Path $profilePath 'user.js' } }
      GetSkipReason      = { "Firefox profile not found under: $firefoxProfilesRoot" }
    },
    @{
      Path  = 'brave\brave_debloater.reg'
      Mode  = 'registry'
      Label = 'Brave policies'
    },
    @{
      Path  = 'nvidia'
      Mode  = 'manual'
      Label = 'NVIDIA assets'
    Note  = 'manual deployment required; the folder contains mixed scripts, ' +
      'profiles, docs, and registry assets for install.'
    },
    @{
      Path   = 'cmd'
      Mode   = 'script'
      Label  = 'CMD aliases'
      Invoke = {
        param($sourceDir, $label)
        Set-CmdAliasAutoRun -AliasScript (Join-Path $sourceDir 'alias.cmd') -Label $label
      }
    },
    @{
      Path   = 'games\bf2'
      Mode   = 'script'
      Label  = 'Star Wars Battlefront II (2017) configs'
      Invoke = {
        param($sourceDir, $label)
        Deploy-StarWarsBattlefrontIIConfig -SourceDir $sourceDir -Label $label
      }
    },
    @{
      Path               = 'games\bo6'
      Mode               = 'directory'
      Label              = 'Call of Duty Black Ops 6 configs'
      Filter             = '*'
      Recurse            = $true
      ResolveDestination = { Get-CallOfDutyPlayersPath }
      GetSkipReason      = { 'Call of Duty players directory not found' }
    },
    @{
      Path               = 'games\arc-raiders'
      Mode               = 'directory'
      Label              = 'Arc Raiders configs'
      Filter             = '*'
      ResolveDestination = {
        $arcPath = Join-Path -Path ([Environment]::GetFolderPath('LocalApplicationData')) -ChildPath 'ArcRaiders\Saved\Config\WindowsNoEditor'
        if (Test-Path $arcPath) { return $arcPath }
        $arcPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'ArcRaiders\Saved\Config\WindowsNoEditor'
        if (Test-Path $arcPath) { return $arcPath }
        return $null
      }
      GetSkipReason      = { 'Arc Raiders config directory not found' }
    },
    @{
      Path               = 'games\fortnite'
      Mode               = 'directory'
      Label              = 'Fortnite configs'
      Filter             = '*.ini'
      ResolveDestination = {
        $fortnitePath = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'FortniteGame\Saved\Config\WindowsClient'
        if (Test-Path $fortnitePath) { return $fortnitePath }
        return $null
      }
      GetSkipReason      = { 'Fortnite config directory not found' }
    },
    @{
      Path   = 'cursors'
      Mode   = 'manual'
      Label  = 'Custom cursor set'
      Note   = 'manual deployment required; run setup-cursors.cmd as admin after placing files in a suitable directory.'
    },
    @{
      Path  = 'mise\config.toml'
      Mode  = 'file'
      Label = 'mise config'
      ResolveDestination = { Join-Path $HOME '.config\mise\config.toml' }
      GetSkipReason      = { 'mise not installed or .config directory missing' }
    },
    @{
      Path   = 'scoop\config.json'
      Mode   = 'file'
      Label  = 'Scoop config'
      ResolveDestination = { Join-Path $HOME '.config\scoop\config.json' }
      GetSkipReason      = { 'Scoop not installed or .config directory missing' }
    },
    @{
      Path   = 'winget-configs\settings.json'
      Mode   = 'file'
      Label  = 'Winget settings'
      ResolveDestination = {
        Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json'
      }
      GetSkipReason      = { 'Winget local state directory not found' }
    },
    @{
      Path   = 'DDU\Settings\Settings.xml'
      Mode   = 'file'
      Label  = 'DDU settings'
      ResolveDestination = { Join-Path $env:PROGRAMDATA 'DDU\Settings.xml' }
      GetSkipReason      = { 'DDU program data directory not found' }
    },
    @{
      Path   = 'nvidia-inspector'
      Mode   = 'manual'
      Label  = 'NVIDIA Inspector settings'
      Note   = 'manual deployment required; import via NVIDIA Inspector GUI or apply the bundled .nip profile.'
    },
    @{
      Path   = 'msi-afterburner'
      Mode   = 'manual'
      Label  = 'MSI Afterburner skin'
      Note   = 'manual deployment required; copy skin files to MSI Afterburner Skins directory.'
    },
    @{
      Path   = 'wsl'
      Mode   = 'script'
      Label  = 'WSL config'
      Invoke = {
        param($sourceDir, $label)
        # Deploy .wslconfig to Windows host (controls WSL2 VM resources)
        $wslConfigHost = Join-Path $HOME '.wslconfig'
        $wslConfHostFile = Join-Path $sourceDir '.wslconfig'
        if (Test-Path $wslConfHostFile) {
          if ($PSCmdlet.ShouldProcess($wslConfigHost, "Deploy $label host config")) {
            Copy-Item -Path $wslConfHostFile -Destination $wslConfigHost -Force
            Write-Host "  [OK] $label host config deployed to ~\.wslconfig" -ForegroundColor Green
          }
        } else {
          Write-Warning "  [SKIP] $label - .wslconfig not found in source: $sourceDir"
        }
        # Deploy wsl.conf to user's WSL directory for manual transfer
        $wslConfFile = Join-Path $sourceDir 'wsl.conf'
        $wslDeployPath = Join-Path $HOME '.config\wsl.conf'
        if (Test-Path $wslConfFile) {
          if ($PSCmdlet.ShouldProcess($wslDeployPath, "Stage $label distro config")) {
            $wslConfigDir = Split-Path -Path $wslDeployPath -Parent
            if (-not (Test-Path $wslConfigDir)) {
              $null = New-Item -ItemType Directory -Path $wslConfigDir -Force
            }
            Copy-Item -Path $wslConfFile -Destination $wslDeployPath -Force
            Write-Host "  [OK] $label distro config staged to ~/.config/wsl.conf" -ForegroundColor Green
            Write-Host "  [INFO] To apply: copy ~/.config/wsl.conf to /etc/wsl.conf inside WSL" -ForegroundColor Yellow
          }
        }
      }
    }
  )

  foreach ($entry in $configManifest) {
    if ($Target -and $Target -notcontains $entry.Label) { continue }
    Invoke-ConfigManifestEntry -Entry $entry
  }

  # ---------------------------------------------------------------------------
  # Phase 4: PATH + directory setup
  # ---------------------------------------------------------------------------
  Write-Host ''
  Write-Host '[4/5] Configuring PATH and directories...' -ForegroundColor Cyan

  $scriptsPath = Join-Path $HOME 'Scripts'
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')

  if (-not $userPath) { $userPath = '' }

  if ($userPath -notlike "*$scriptsPath*") {
    if ($PSCmdlet.ShouldProcess('User PATH', "Add $scriptsPath")) {
      $newPath = ($userPath.TrimEnd(';') + ";$scriptsPath").TrimStart(';')
      [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
      Write-Host "  [OK] Added Scripts to PATH" -ForegroundColor Green
    }
  } else {
    Write-Host '  [UP-TO-DATE] Scripts already in PATH' -ForegroundColor Gray
  }

  $commonDirs = @(
    "$HOME\.local\bin",
    "$HOME\.cache",
    "$HOME\Projects"
  )

  foreach ($dir in $commonDirs) {
    if (-not (Test-Path $dir)) {
      if ($PSCmdlet.ShouldProcess($dir, 'Create directory')) {
        $null = New-Item -ItemType Directory -Path $dir -Force
        Write-Host "  [OK] Created $dir" -ForegroundColor Green
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Phase 5: Verification summary
  # ---------------------------------------------------------------------------
  Write-Host ''
  Write-Host '[5/5] Verification summary' -ForegroundColor Cyan

  $updatedPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  $checks = @(
    @{ label = 'PowerShell profile';      ok = Test-Path $PROFILE },
    @{ label = 'Scripts directory';       ok = Test-Path $scriptsPath },
    @{ label = 'Scripts in PATH';         ok = ($updatedPath -like "*$scriptsPath*") },
  @{ label = 'Execution policy (User)'
    ok = (Get-ExecutionPolicy -Scope CurrentUser) -notin @('Restricted', 'Undefined') }
  )

  foreach ($check in $checks) {
    if ($check.ok) {
      Write-Host "  [OK] $($check.label)" -ForegroundColor Green
    } else {
      Write-Host "  [!!] $($check.label)" -ForegroundColor Red
    }
  }

  Write-Host ''
  Write-Host 'Bootstrap complete. Restart your terminal to apply the new profile.' -ForegroundColor Cyan
  Write-Host ''
}

if ($MyInvocation.InvocationName -ne '.') {
  Start-Bootstrap @PSBoundParameters
  $ec = Get-Variable -Name LASTEXITCODE -ValueOnly -ErrorAction SilentlyContinue
  if ($null -ne $ec) { exit $ec } else { exit 0 }
}