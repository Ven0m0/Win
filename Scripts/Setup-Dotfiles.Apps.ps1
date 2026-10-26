#Requires -Version 5.1
<#
.SYNOPSIS
    Per-app and per-game path resolvers and deploys for Setup-Dotfiles.ps1.
.DESCRIPTION
    Dot-sourced by Setup-Dotfiles.ps1 right after Common.ps1, before the generic deploy engine
    (Deploy-Config etc.) is defined. That is fine: functions here resolve Deploy-Config at call
    time, after Setup-Dotfiles.ps1 has finished loading.
#>

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

    $defaultSection = $profileSections | Where-Object { $ini[$_].Contains('Default') -and $ini[$_].Default -eq '1' } | Select-Object -First 1
    if (-not $defaultSection) {
        $defaultSection = $profileSections[0]
    }
    $defaultProfile = $ini[$defaultSection]

    if (-not $defaultProfile.Contains('Path')) {
        return $null
    }

    if ($defaultProfile.Contains('IsRelative') -and $defaultProfile.IsRelative -eq '1') {
        return Join-Path (Split-Path $profilesIni -Parent) $defaultProfile.Path
    }

    return $defaultProfile.Path
}

function Get-CallOfDutyPlayersPath {
    <#
  .SYNOPSIS
      Returns the BO6 players folder when it exists. Steam and Battle.net installs share it.
  #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $playersPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Call of Duty BO6\players'
    if (Test-Path $playersPath) {
        $playersPath
    }
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

function Deploy-CallOfDutyBlackOps6Config {
    <#
  .SYNOPSIS
      Deploys the tracked BO6 settings file into every existing players folder (Steam and Battle.net).
  .PARAMETER SourceDir
      Full path to the tracked BO6 config directory.
  .PARAMETER Label
      Human-readable label for output messages.
  #>
    [CmdletBinding()]
    param(
        [string]$SourceDir,
        [string]$Label
    )

    $source = Join-Path $SourceDir 's.1.0.cod24.txt0'
    $playersPaths = @(Get-CallOfDutyPlayersPath)
    if ($playersPaths.Count -eq 0) {
        Write-Warning "  [SKIP] $Label - Call of Duty players directory not found"
        return
    }

    # The game alternates between txt0 and txt1 (s.1.0.cod24.m marks the active one), so both get
    # the same content. The .m marker is left alone.
    foreach ($playersPath in $playersPaths) {
        $folderName = Split-Path (Split-Path $playersPath -Parent) -Leaf
        foreach ($slot in 's.1.0.cod24.txt0', 's.1.0.cod24.txt1') {
            $deployParams = @{
                Source      = $source
                Destination = Join-Path $playersPath $slot
                Label       = "$Label/$folderName/$slot"
            }
            Deploy-Config @deployParams
        }

        # Keybinds live in the per-account profile folder (named by account ID, so it differs per install),
        # and only exist once the game has created the profile; skip folders without one.
        $keybindsSource = Join-Path $SourceDir 'keybinds.cod24.kb'
        $profileDirs = @(Get-ChildItem -Path $playersPath -Directory |
                Where-Object { ($_.Name -match '^\d+$') -and (Test-Path (Join-Path $_.FullName 'keybinds.cod24.kb')) })
        foreach ($profileDir in $profileDirs) {
            $deployParams = @{
                Source      = $keybindsSource
                Destination = Join-Path $profileDir.FullName 'keybinds.cod24.kb'
                Label       = "$Label/$($profileDir.Name)/keybinds.cod24.kb"
            }
            Deploy-Config @deployParams
        }
    }
}

function Resolve-QtEmulatorConfigPath {
    <#
  .SYNOPSIS
      Resolves the qt-config.ini path for a Qt-based emulator, or $null when it is not installed.
  .DESCRIPTION
      Scoop installs these emulators portable: config lives in persist\<app>\user\config.
      Otherwise falls back to %APPDATA%\<AppDataDir>\config when that directory exists.
  #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$ScoopApp,
        [Parameter(Mandatory)][string]$AppDataDir
    )

    $scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $HOME 'scoop' }
    $persist = Join-Path $scoopRoot "persist\$ScoopApp"
    if (Test-Path $persist) {
        return Join-Path $persist 'user\config\qt-config.ini'
    }
    $appData = Join-Path $env:APPDATA $AppDataDir
    if (Test-Path $appData) {
        return Join-Path $appData 'config\qt-config.ini'
    }
}
