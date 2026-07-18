#Requires -Version 5.1

<#
.SYNOPSIS
    Extracts the Endgame Gear OP1 8k config tool and firmware updater.
.DESCRIPTION
    Extracts EndgameGear-OP1-8k-Tools.7z (7-Zip) to the user's Documents
    folder. These are standalone utility binaries (config tool, firmware
    updater) run manually as needed - no shortcuts or auto-launch.
.EXAMPLE
    Scripts\endgame-gear\install-op1-tools.ps1
#>

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\Common.ps1')

$archivePath = Join-Path $PSScriptRoot 'EndgameGear-OP1-8k-Tools.7z'
$destPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'EndgameGear'

$7z = Get-7zPath
Ensure-Directory -Path $destPath
Write-Info "Extracting EndgameGear-OP1-8k-Tools.7z to $destPath..."
& $7z x "-o$destPath" -y $archivePath | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "7z extraction failed with exit code $LASTEXITCODE"
}

Write-Success 'Endgame Gear OP1 8k tools extracted.'
