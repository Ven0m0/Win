#Requires -Version 5.1

<#
.SYNOPSIS
    Installs DLSSync, keeping DLSS/DLSS-FG/DLAA DLLs up to date across installed games.
.DESCRIPTION
    DLSSync has no winget package. Resolves the latest release from GitHub
    (xt0n1-t3ch/DLSSync), downloads the MSI installer, and installs it silently.
.EXAMPLE
    Scripts\dlssync\install-dlssync.ps1
#>

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\Common.ps1')

$msiPath = Join-Path $env:TEMP 'DLSSync.msi'

$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/xt0n1-t3ch/DLSSync/releases/latest'
$asset = $release.assets | Where-Object { $_.name -like '*_x64_en-US.msi' } | Select-Object -First 1
if (-not $asset) {
    throw 'Could not find the DLSSync MSI release asset.'
}

Write-Info "Downloading $($asset.name)..."
Get-FileFromWeb -URL $asset.browser_download_url -File $msiPath

Write-Info 'Installing DLSSync...'
Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$msiPath`" /quiet /norestart" -Wait
Remove-Item -LiteralPath $msiPath -Force

Write-Success "DLSSync $($release.tag_name) installed."
