#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Backs up game configs for Arc Raiders and Black Ops 6 to dotfiles.
.DESCRIPTION
    Copies game settings, keybinds, and preferences to the user's dotfiles.
    Does NOT copy account login credentials or sensitive data.
.PARAMETER DotfilesPath
    Destination directory under which game config subdirectories are created.
.EXAMPLE
    .\Backup-GameConfig.ps1
    .\Backup-GameConfig.ps1 -DotfilesPath "$HOME\.dotfiles\config\games"
#>

[CmdletBinding()]
param(
  [string]$DotfilesPath = "$env:USERPROFILE\.dotfiles\config\games"
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

. "$PSScriptRoot\Common.ps1"

function Backup-GameConfig {
  <#
  .SYNOPSIS
      Runs the full game config backup to the specified dotfiles path.
  .PARAMETER DotfilesPath
      Root directory for backed-up configs.
  #>
  [CmdletBinding()]
  param(
    [string]$DotfilesPath = "$env:USERPROFILE\.dotfiles\config\games"
  )

  $bo6Source = "$env:USERPROFILE\Documents\Call of Duty\players"
  $bo6Dest   = "$DotfilesPath\bo6"

  $arcRaidersSource = "$env:LOCALAPPDATA\PioneerGame\Saved\SaveGames"
  $arcRaidersDest   = "$DotfilesPath\arc-raiders"

  Write-ColorOutput "[Backup] Starting game config backup..." -ForegroundColor Cyan
  Write-ColorOutput "[Backup] Destination: $DotfilesPath" -ForegroundColor Gray

  Ensure-Directory -Path $DotfilesPath

  if (Test-Path -Path $bo6Source) {
    Write-ColorOutput "[Backup] Backing up Black Ops 6 settings..." -ForegroundColor Yellow

    Ensure-Directory -Path $bo6Dest

    $playerFolders = Get-ChildItem -Path $bo6Source -Directory -ErrorAction SilentlyContinue
    foreach ($playerFolder in $playerFolders) {
      $destPlayerFolder = Join-Path -Path $bo6Dest -ChildPath $playerFolder.Name
      Ensure-Directory -Path $destPlayerFolder

      $filesToCopy = Get-ChildItem -Path $playerFolder.FullName -File -ErrorAction SilentlyContinue
      foreach ($file in $filesToCopy) {
        Copy-Item -Path $file.FullName -Destination $destPlayerFolder -Force
        Write-ColorOutput "[Backup]   Copied: $($file.Name)" -ForegroundColor Gray
      }
    }

    $rootFiles = Get-ChildItem -Path $bo6Source -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match '^s' }
    foreach ($file in $rootFiles) {
      Copy-Item -Path $file.FullName -Destination $bo6Dest -Force
      Write-ColorOutput "[Backup]   Copied: $($file.Name)" -ForegroundColor Gray
    }

    Write-ColorOutput "[Backup] Black Ops 6 backup complete!" -ForegroundColor Green
  } else {
    Write-ColorOutput "[Backup] Black Ops 6 settings not found at $bo6Source" -ForegroundColor Yellow
  }

  if (Test-Path -Path $arcRaidersSource) {
    Write-ColorOutput "[Backup] Backing up Arc Raiders settings..." -ForegroundColor Yellow

    Ensure-Directory -Path $arcRaidersDest

    $keybindsFile = Get-ChildItem -Path $arcRaidersSource -File -Filter '*KeyBindings*.sav' `
      -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($keybindsFile) {
      Copy-Item -Path $keybindsFile.FullName -Destination (Join-Path -Path $arcRaidersDest -ChildPath 'keybinds.sav') -Force
      Write-ColorOutput "[Backup]   Copied: keybinds.sav" -ForegroundColor Gray
    }

    $settingsFiles = @('GameUserSettings.ini', 'Engine.ini')
    foreach ($settingsFile in $settingsFiles) {
      $sourceFile = Get-ChildItem -Path $arcRaidersSource -File -Filter $settingsFile `
        -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($sourceFile) {
        Copy-Item -Path $sourceFile.FullName -Destination $arcRaidersDest -Force
        Write-ColorOutput "[Backup]   Copied: $settingsFile" -ForegroundColor Gray
      }
    }

    Write-ColorOutput "[Backup] Arc Raiders backup complete!" -ForegroundColor Green
  } else {
    Write-ColorOutput "[Backup] Arc Raiders settings not found at $arcRaidersSource" -ForegroundColor Yellow
  }

  Write-ColorOutput "[Backup] All game configs backed up successfully!" -ForegroundColor Green
}

if ($MyInvocation.InvocationName -ne '.') {
  Backup-GameConfig -DotfilesPath $DotfilesPath
}
