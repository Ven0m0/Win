#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Installs ViGEmBus and the GMK Driver, with Desktop/Start Menu/Startup shortcuts.
.DESCRIPTION
    Uninstalls any existing ClickOnce "Gaming Mod Kits Controller Driver"
    install, installs ViGEm.ViGEmBus via winget, extracts GMKDriver.7z
    (7-Zip) to the user's Documents folder, then creates a shortcut to
    GMKDriverNetUI.exe on the Desktop, in the Start Menu, and in the
    Startup folder.
.EXAMPLE
    Scripts\gmk\install-gmk-driver.ps1
#>

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\Common.ps1')

Request-AdminElevation
Initialize-ConsoleUI -Title 'GMK Driver Setup (Administrator)'

$archivePath = Join-Path $PSScriptRoot 'GMKDriver.7z'
$oldDestPath = Join-Path $env:ProgramFiles 'GMKDriver'
$destPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'GMKDriver'
$exePath = Join-Path $destPath 'GMKDriverNetUI.exe'
$iconPath = Join-Path $destPath 'GMKlogo_transparent_square.ico'

function Uninstall-GmkDriver {
    <#
    .SYNOPSIS
        Removes the old ClickOnce-installed GMK driver, if present.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $uninstallKeys = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    $entries = Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -match 'Gaming Mod Kits' }

    if (-not $entries) {
        Write-Info 'No existing GMK driver installation found.'
        return
    }

    Stop-Process -Name 'GMKDriverNetUI' -Force -ErrorAction SilentlyContinue

    foreach ($entry in $entries) {
        if ($PSCmdlet.ShouldProcess($entry.DisplayName, 'Uninstall')) {
            Write-Info "Uninstalling existing $($entry.DisplayName)..."
            Start-Process -FilePath 'cmd.exe' -ArgumentList "/c $($entry.UninstallString)" -Wait -NoNewWindow
            Write-Success "Removed $($entry.DisplayName)"
        }
    }
}

Uninstall-GmkDriver

Invoke-Winget -Id 'ViGEm.ViGEmBus' -Name 'ViGEmBus'

if (Test-Path -LiteralPath $oldDestPath) {
    Write-Info "Removing previous install at $oldDestPath..."
    Remove-Item -LiteralPath $oldDestPath -Recurse -Force
}

$7z = Get-7zPath
Ensure-Directory -Path $destPath
Write-Info "Extracting GMKDriver.7z to $destPath..."
& $7z x "-o$destPath" -y $archivePath | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "7z extraction failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $exePath)) {
    throw "GMKDriverNetUI.exe not found after extraction: $exePath"
}

$desktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'GMK Driver.lnk'
$startMenuShortcut = Join-Path ([Environment]::GetFolderPath('Programs')) 'GMK Driver.lnk'
$startupShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'GMK Driver.lnk'

New-Shortcut -ShortcutPath $desktopShortcut -TargetPath $exePath -IconLocation $iconPath
New-Shortcut -ShortcutPath $startMenuShortcut -TargetPath $exePath -IconLocation $iconPath
New-Shortcut -ShortcutPath $startupShortcut -TargetPath $exePath -IconLocation $iconPath

Write-Success 'GMK Driver setup complete.'
