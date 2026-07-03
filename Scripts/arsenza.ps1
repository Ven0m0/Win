#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Imports the ARSENZA LOW LATENCY power plan and optionally activates it.

.DESCRIPTION
    Imports Scripts/arsenza.pow via powercfg /import.
    Pass -SetActive to switch to the plan immediately after import.

.PARAMETER SetActive
    Activate the plan after importing.

.EXAMPLE
    .\arsenza.ps1 -SetActive
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$SetActive
)

$ErrorActionPreference = 'Stop'

$planGuid = '9aebceaa-2f39-4339-9a54-749a56ee82b4'
$powFile = "$PSScriptRoot\arsenza.pow"

if (-not (Test-Path -LiteralPath $powFile)) {
    Write-Error "Power plan file not found: $powFile"
    return
}

# Check if already imported
$existing = powercfg /list 2>&1 | Select-String -SimpleMatch $planGuid
if ($existing) {
    Write-Host "Power plan already imported ($planGuid)."
}
else {
    if ($PSCmdlet.ShouldProcess($powFile, 'Import power plan')) {
        $null = powercfg /import $powFile $planGuid 2>&1
        Write-Host "Imported: ARSENZA LOW LATENCY ($planGuid)"
    }
}

if ($SetActive) {
    if ($PSCmdlet.ShouldProcess($planGuid, 'Set active power plan')) {
        $null = powercfg /setactive $planGuid 2>&1
        Write-Host "Active plan set to ARSENZA LOW LATENCY."
    }
}
