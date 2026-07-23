#Requires -Version 5.1

<#
.SYNOPSIS
    Installs DS4Windows, with Desktop/Start Menu/Startup shortcuts.
.DESCRIPTION
    DS4Windows has no winget package. Resolves the latest official binary
    release from GitHub (ds4windowsapp/DS4Windows), downloads and extracts
    it to the user's Documents folder, then creates a shortcut to
    DS4Windows.exe on the Desktop, in the Start Menu, and in the Startup
    folder.
.EXAMPLE
    Scripts\ds4windows\install-ds4windows.ps1
#>

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\Common.ps1')

$destPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'DS4Windows'
$exePath = Join-Path $destPath 'win-x64\DS4Windows.exe'
$zipPath = Join-Path $env:TEMP 'DS4Windows.zip'

$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/ds4windowsapp/DS4Windows/releases/latest'
$asset = $release.assets |
    Where-Object { $_.name -like 'DS4Windows.*.zip' -and $_.name -ne 'DS4Windows-Official.zip' } |
    Select-Object -First 1
if (-not $asset) {
    throw 'Could not find the DS4Windows binary release asset.'
}

Write-Info "Downloading $($asset.name)..."
Get-FileFromWeb -URL $asset.browser_download_url -File $zipPath

if (Test-Path -LiteralPath $destPath) {
    Write-Info "Removing previous install at $destPath..."
    Remove-Item -LiteralPath $destPath -Recurse -Force
}
Ensure-Directory -Path $destPath
Write-Info "Extracting to $destPath..."
Expand-Archive -LiteralPath $zipPath -DestinationPath $destPath -Force
Remove-Item -LiteralPath $zipPath -Force

if (-not (Test-Path -LiteralPath $exePath)) {
    throw "DS4Windows.exe not found after extraction: $exePath"
}

$desktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'DS4Windows.lnk'
$startMenuShortcut = Join-Path ([Environment]::GetFolderPath('Programs')) 'DS4Windows.lnk'
$startupShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'DS4Windows.lnk'

New-Shortcut -ShortcutPath $desktopShortcut -TargetPath $exePath
New-Shortcut -ShortcutPath $startMenuShortcut -TargetPath $exePath
New-Shortcut -ShortcutPath $startupShortcut -TargetPath $exePath

Write-Success 'DS4Windows setup complete.'
