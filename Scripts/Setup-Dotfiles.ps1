#!/usr/bin/env pwsh
#Requires -Version 5.1
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

. "$PSScriptRoot\Common.ps1"

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
        }
        else {
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
        }
        else {
            Write-Warning "  [WARN] $Label - reg import exit code: $LASTEXITCODE"
        }
    }
}

function Get-FirefoxDefaultProfilePath {
    $profilesIni = Join-Path $env:APPDATA 'Mozilla\Firefox\profiles.ini'
    if (-not (Test-Path $profilesIni) -or -not (Get-Module -ListAvailable -Name PsIni)) {
        return $null
    }
    Import-Module -Name PsIni -ErrorAction Stop

    $ini = Import-Ini -Path $profilesIni
    $profileSections = @($ini.Keys | Where-Object { $_ -like 'Profile*' })
    if ($profileSections.Count -eq 0) {
        return $null
    }

    $defaultSection = $profileSections | Where-Object { $ini[$_].Default -eq '1' } | Select-Object -First 1
    if (-not $defaultSection) {
        $defaultSection = $profileSections[0]
    }
    $defaultProfile = $ini[$defaultSection]

    if (-not $defaultProfile.Contains('Path')) {
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
    }
    else {
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

function Resolve-VSCodeUserDir {
    <#
  .SYNOPSIS
      Locates the User config directory for VS Code or VSCodium, whichever is installed.
  #>
    [CmdletBinding()]
    param()

    foreach ($dirName in 'Code', 'VSCodium') {
        $candidate = Join-Path $env:APPDATA "$dirName\User"
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

function Install-VSCodeExtensions {
    <#
  .SYNOPSIS
      Installs extensions listed in extensions.txt via the code/codium CLI, skipping ones already installed.
  .PARAMETER SourceDir
      Directory containing extensions.txt.
  .PARAMETER Label
      Human-readable label for output messages.
  #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$SourceDir,
        [string]$Label
    )

    $listFile = Join-Path $SourceDir 'extensions.txt'
    if (-not (Test-Path $listFile)) {
        Write-Warning "  [SKIP] $Label - extensions.txt not found: $listFile"
        return
    }

    $cli = Get-Command code, code-insiders, codium -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cli) {
        Write-Warning "  [SKIP] $Label - no code/codium CLI found on PATH"
        return
    }

    $wanted = Get-Content $listFile | Where-Object { $_ -and -not $_.StartsWith('#') }
    $installed = & $cli.Source --list-extensions
    $missing = $wanted | Where-Object { $installed -notcontains $_ }

    if (-not $missing) {
        Write-Host "  [UP-TO-DATE] $Label" -ForegroundColor Gray
        return
    }

    $failed = @()
    foreach ($ext in $missing) {
        if ($PSCmdlet.ShouldProcess($ext, "Install extension via $($cli.Name)")) {
            try {
                & $cli.Source --install-extension $ext --force 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "exit code $LASTEXITCODE" }
            } catch {
                $failed += $ext
                Write-Warning "  [SKIP] $Label - extension '$ext' failed to install: $($_.Exception.Message)"
            }
        }
    }
    $installedCount = @($missing).Count - @($failed).Count
    Write-Host "  [OK] $Label - installed $installedCount extension(s)" -ForegroundColor Green
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
        Write-Warning "  [SKIP] $($Entry.Label) - source not found: $sourcePath"
        return
    }

    switch ($Entry.Mode) {
        'file' {
            $destination = & $Entry.ResolveDestination
            if ($destination) {
                Deploy-Config -Source $sourcePath -Destination $destination -Label $Entry.Label
            }
            else {
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
            }
            else {
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

    if ($PSCmdlet.ShouldProcess($Name, 'Install via winget')) {
        Write-Host "  Installing $Name..." -ForegroundColor Gray -NoNewline
        try {
            $winget = Wait-ForWinget
            $wingetArgs = @('install', '--id', $Id, '--silent', '--accept-source-agreements', '--accept-package-agreements')
            if ($isAdmin) { $wingetArgs += @('--scope', 'machine') }
            & $winget @wingetArgs *>$null
            $ec = $LASTEXITCODE
            # 0 = success, -1978335189 (0x8A150021) = already installed at required version
            if ($ec -eq 0 -or $ec -eq -1978335189) {
                Write-Host " [OK]" -ForegroundColor Green
            }
            else {
                Write-Host ""
                Write-Warning "  [WARN] $Name - winget exit code: $ec"
            }
        }
        catch {
            Write-Host ""
            Write-Warning "  [WARN] $Name - $_"
        }
    }
}

function Install-GithubReleaseTool {
    <#
  .SYNOPSIS
      Installs a tool from its latest GitHub release asset (for tools not on winget).
  .DESCRIPTION
      Downloads the named asset from the repo's latest release and runs it silently.
      Silent switches are auto-detected from the installer via Get-SilentInstallSwitches
      (Common.ps1); pass -Switches to override when detection picks the wrong ones.
      Best-effort - warns rather than throws on failure.
  .PARAMETER Repo
      GitHub repo in 'owner/name' form.
  .PARAMETER AssetName
      Exact release asset file name to download (the installer exe).
  .PARAMETER Name
      Human-readable tool name for output messages.
  .PARAMETER Switches
      Silent-install switches to use instead of auto-detection.
  #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Repo,
        [string]$AssetName,
        [string]$Name,
        [string[]]$Switches
    )

    if ($PSCmdlet.ShouldProcess($Name, 'Install from GitHub release')) {
        Write-Host "  Installing $Name..." -ForegroundColor Gray -NoNewline
        try {
            $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
            $asset = $release.assets | Where-Object { $_.name -eq $AssetName }
            if (-not $asset) {
                Write-Host ""
                Write-Warning "  [WARN] $Name - asset '$AssetName' not found in latest release"
                return
            }
            $installerPath = Join-Path -Path $env:TEMP -ChildPath $AssetName
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath

            $installSwitches = if ($Switches) { $Switches } else { Get-SilentInstallSwitches -Path $installerPath }
            if (-not $installSwitches) {
                Write-Host ""
                Write-Warning "  [WARN] $Name - could not detect silent-install switches; pass -Switches explicitly"
                Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue
                return
            }

            Start-Process -FilePath $installerPath -ArgumentList $installSwitches -Wait
            Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue
            Write-Host " [OK]" -ForegroundColor Green
        }
        catch {
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
        $isAdmin = Test-IsAdmin
    }
    catch {
        Write-Verbose "Could not determine admin status: $($_.Exception.Message)"
    }
    if (-not $isAdmin) {
        Write-Host 'Not running as administrator - deploying user-scoped configs only.' -ForegroundColor Yellow
        Write-Host '  (admin-only steps, e.g. NVIDIA Inspector settings, will be skipped)' -ForegroundColor Yellow
    }

    # Collects deployment failures (and admin-skip notices) for the end-of-run summary.
    $deployFailures = [System.Collections.Generic.List[pscustomobject]]::new()

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
    }
    catch {
        Write-Warning "  Could not set execution policy: $_"
    }

    # ---------------------------------------------------------------------------
    # Phase 2: Install tools via winget
    # ---------------------------------------------------------------------------
    Write-Host ''
    if ($SkipWingetTools) {
        Write-Host '[2/5] Tool installation skipped (-SkipWingetTools)' -ForegroundColor Cyan
    }
    else {
        Write-Host '[2/5] Installing tools...' -ForegroundColor Cyan

        try {
            $null = Wait-ForWinget
        }
        catch {
            Write-Warning "  winget not available: $_. Install from: https://aka.ms/getwinget"
        }
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Warning '  winget not found. Install from: https://aka.ms/getwinget'
        }
        else {
            $tools = @(
                @{ id = 'Git.Git'; name = 'Git' },
                @{ id = 'Microsoft.PowerShell'; name = 'PowerShell 7+' },
                @{ id = 'Microsoft.WindowsTerminal'; name = 'Windows Terminal' },
                @{ id = 'Microsoft.VisualStudioCode'; name = 'VS Code' }
            )

            foreach ($tool in $tools) {
                Install-WingetTool -Id $tool.id -Name $tool.name
            }

            # Not on winget - installed from its latest GitHub release instead.
            Install-GithubReleaseTool -Repo 'LiteLDev/LeviLauncher' -AssetName 'LeviLauncher-amd64-installer.exe' -Name 'LeviLauncher'
        }
    }

    # ---------------------------------------------------------------------------
    # Phase 3: Deploy configs
    # ---------------------------------------------------------------------------
    Write-Host ''
    Write-Host '[3/5] Deploying configs...' -ForegroundColor Cyan

    $configRoot = Join-Path $PSScriptRoot '..\user\.dotfiles\config'
    $appData = if ($env:APPDATA) { $env:APPDATA } else { '/tmp/AppData' }
    $firefoxProfilesRoot = Join-Path $appData 'Mozilla\Firefox'

    $configManifest = @(
        @{
            Path               = 'powershell\Microsoft.PowerShell_profile.ps1'
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
            Path               = 'browser\firefox\user.js'
            Mode               = 'file'
            Label              = 'Firefox user.js'
            ResolveDestination = { $profilePath = Get-FirefoxDefaultProfilePath
                if ($profilePath) { Join-Path $profilePath 'user.js' } }
            GetSkipReason      = { "Firefox profile not found under: $firefoxProfilesRoot" }
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
                $arcPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'PioneerGame\Saved\Config\WindowsClient'
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
            Path  = 'cursors'
            Mode  = 'manual'
            Label = 'Custom cursor set'
            Note  = 'manual deployment required; run setup-cursors.cmd as admin after placing files in a suitable directory.'
        },
        @{
            Path               = 'mise\config.toml'
            Mode               = 'file'
            Label              = 'mise config'
            ResolveDestination = { Join-Path $HOME '.config\mise\config.toml' }
            GetSkipReason      = { 'mise not installed or .config directory missing' }
        },
        @{
            Path               = 'scoop\config.json'
            Mode               = 'file'
            Label              = 'Scoop config'
            ResolveDestination = { Join-Path $HOME '.config\scoop\config.json' }
            GetSkipReason      = { 'Scoop not installed or .config directory missing' }
        },
        @{
            Path               = 'psmux\.psmux.conf'
            Mode               = 'file'
            Label              = 'psmux config'
            ResolveDestination = { Join-Path $HOME '.psmux.conf' }
            GetSkipReason      = { 'psmux not installed' }
        },
        @{
            Path               = 'topgrade\topgrade.toml'
            Mode               = 'file'
            Label              = 'Topgrade config'
            ResolveDestination = { Join-Path $env:APPDATA 'topgrade.toml' }
            GetSkipReason      = { 'Topgrade not installed or %APPDATA% missing' }
        },
        @{
            Path               = 'ohmyposh\zen.toml'
            Mode               = 'file'
            Label              = 'oh-my-posh zen theme'
            ResolveDestination = { Join-Path $HOME '.config\ohmyposh\zen.toml' }
            GetSkipReason      = { 'oh-my-posh not installed' }
        },
        @{
            Path               = 'ohmyposh\cobalt2.omp.json'
            Mode               = 'file'
            Label              = 'oh-my-posh cobalt2 theme'
            ResolveDestination = { Join-Path $HOME '.config\ohmyposh\cobalt2.omp.json' }
            GetSkipReason      = { 'oh-my-posh not installed' }
        },
        @{
            Path               = 'winget-configs\settings.json'
            Mode               = 'file'
            Label              = 'Winget settings'
            ResolveDestination = {
                Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json'
            }
            GetSkipReason      = { 'Winget local state directory not found' }
        },
        @{
            Path               = 'DDU\Settings\Settings.xml'
            Mode               = 'file'
            Label              = 'DDU settings'
            ResolveDestination = { Join-Path $env:PROGRAMDATA 'DDU\Settings.xml' }
            GetSkipReason      = { 'DDU program data directory not found' }
        },
        @{
            Path               = 'obs'
            Mode               = 'directory'
            Label              = 'OBS Studio config'
            Filter             = '*'
            Recurse            = $true
            ResolveDestination = {
                $obsRoot = Join-Path $env:APPDATA 'obs-studio'
                if (Test-Path $obsRoot) { return $obsRoot }
                return $null
            }
            GetSkipReason      = { 'OBS Studio config directory (%APPDATA%\obs-studio) not found' }
        },
        @{
            Path   = 'nvidia'
            Mode   = 'script'
            Label  = 'NVIDIA Inspector settings'
            Invoke = {
                param($sourceDir, $label)
                if (-not $isAdmin) {
                    Write-Warning "  [SKIP] $label - requires administrator privileges (re-run elevated to apply)"
                    $deployFailures.Add([pscustomobject]@{ Label = $label; Error = 'Skipped - requires administrator privileges' })
                    return
                }
                $script = Join-Path $sourceDir 'nvidia-settings.ps1'
                if (Test-Path $script) {
                    & $script -Mode Apply -Unattended:$Unattended
                }
                else {
                    Write-Warning "  [SKIP] $label - nvidia-settings.ps1 not found in $sourceDir"
                }
            }
        },
        @{
            Path  = 'nvidia\msi-afterburner'
            Mode  = 'manual'
            Label = 'MSI Afterburner skin'
            Note  = 'manual deployment required; copy skin files to MSI Afterburner Skins directory.'
        },
        @{
            Path               = 'kilo\lsp.json'
            Mode               = 'file'
            Label              = 'Kilo AI LSP config'
            ResolveDestination = { Join-Path $HOME '.kilo\lsp.json' }
        },
        @{
            Path               = 'opencode\lsp.json'
            Mode               = 'file'
            Label              = 'OpenCode LSP config'
            ResolveDestination = { Join-Path $HOME '.config\opencode\lsp.json' }
        },
        @{
            Path               = 'vscode\User\settings.json'
            Mode               = 'file'
            Label              = 'VS Code / VSCodium settings'
            ResolveDestination = {
                $userDir = Resolve-VSCodeUserDir
                if ($userDir) { Join-Path $userDir 'settings.json' }
            }
            GetSkipReason      = { 'VS Code / VSCodium User directory not found' }
        },
        @{
            Path   = 'vscode'
            Mode   = 'script'
            Label  = 'VS Code / VSCodium extensions'
            Invoke = {
                param($sourceDir, $label)
                Install-VSCodeExtensions -SourceDir $sourceDir -Label $label
            }
        },
        @{
            Path  = 'games\minecraft'
            Mode  = 'manual'
            Label = 'Minecraft modpacks'
            Note  = 'manual import required; open .mrpack files with Prism Launcher or MultiMC to install.'
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
                }
                else {
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
        try {
            Invoke-ConfigManifestEntry -Entry $entry
        }
        catch {
            $err = $_
            Write-Warning "  [FAIL] $($entry.Label) - $($err.Exception.Message)"
            $deployFailures.Add([pscustomobject]@{ Label = $entry.Label; Error = $err.Exception.Message })
        }
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
    }
    else {
        Write-Host '  [UP-TO-DATE] Scripts already in PATH' -ForegroundColor Gray
    }

    # Ensure .local\bin outranks WinGet Links in the Machine PATH - Machine PATH is
    # prepended ahead of User PATH at logon, so User-scope ordering alone can't win here.
    $localBinPath = "$HOME\.local\bin"
    $wingetLinksPath = 'C:\Program Files\WinGet\Links'
    if ($isAdmin) {
        $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        $machineEntries = @($machinePath -split ';' | Where-Object { $_ -and $_ -ne $localBinPath })
        $wingetIndex = $machineEntries.IndexOf($wingetLinksPath)
        $needsFix = ($machinePath -notlike "*$localBinPath*") -or ($wingetIndex -ge 0 -and (@($machinePath -split ';').IndexOf($localBinPath)) -gt $wingetIndex)
        if ($needsFix) {
            if ($PSCmdlet.ShouldProcess('Machine PATH', "Insert $localBinPath ahead of $wingetLinksPath")) {
                if ($wingetIndex -ge 0) {
                    $machineEntries = @($machineEntries[0..($wingetIndex - 1)]) + $localBinPath + @($machineEntries[$wingetIndex..($machineEntries.Count - 1)])
                }
                else {
                    $machineEntries = @($localBinPath) + $machineEntries
                }
                [Environment]::SetEnvironmentVariable('Path', ($machineEntries -join ';'), 'Machine')
                Write-Host "  [OK] $localBinPath now precedes $wingetLinksPath in Machine PATH" -ForegroundColor Green
            }
        }
        else {
            Write-Host '  [UP-TO-DATE] .local\bin already precedes WinGet Links in Machine PATH' -ForegroundColor Gray
        }
    }
    else {
        Write-Warning '  [SKIP] Machine PATH ordering - requires administrator'
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
        @{ label = 'PowerShell profile'; ok = Test-Path $PROFILE },
        @{ label = 'Scripts directory'; ok = Test-Path $scriptsPath },
        @{ label = 'Scripts in PATH'; ok = ($updatedPath -like "*$scriptsPath*") },
        @{ label = 'Execution policy (User)'
            ok   = (Get-ExecutionPolicy -Scope CurrentUser) -notin @('Restricted', 'Undefined')
        }
    )

    foreach ($check in $checks) {
        if ($check.ok) {
            Write-Host "  [OK] $($check.label)" -ForegroundColor Green
        }
        else {
            Write-Host "  [!!] $($check.label)" -ForegroundColor Red
        }
    }

    if ($deployFailures.Count -gt 0) {
        Write-Host ''
        Write-Host 'STEPS THAT FAILED (fix manually):' -ForegroundColor Red
        foreach ($f in $deployFailures) {
            Write-Host "  [FAIL] $($f.Label): $($f.Error)" -ForegroundColor Red
        }
    }
    else {
        Write-Host ''
        Write-Host '  All config deployments succeeded.' -ForegroundColor Green
    }

    Write-Host ''
    Write-Host 'Bootstrap complete. Restart your terminal to apply the new profile.' -ForegroundColor Cyan
    Write-Host ''

    return [pscustomobject]@{ FailureCount = $deployFailures.Count }
}

if ($MyInvocation.InvocationName -ne '.') {
    $bootstrapResult = Start-Bootstrap @PSBoundParameters
    $failureCount = if ($bootstrapResult -and $bootstrapResult.PSObject.Properties['FailureCount']) {
        $bootstrapResult.FailureCount
    }
    else {
        0
    }
    exit ([int]($failureCount -gt 0))
}
