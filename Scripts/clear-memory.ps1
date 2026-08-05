#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Trims working sets of all processes and purges the standby memory list.
.DESCRIPTION
    Reports free RAM before/after and calls Common.ps1's Invoke-MemoryTrim.
.EXAMPLE
    .\clear-memory.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param ()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Common.ps1"

$memBefore = (Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory
Write-Info "Free RAM before: $(Format-Size ($memBefore * 1KB))"

Invoke-MemoryTrim -TypeName 'ClearMemoryTrim'
Start-Sleep -Milliseconds 500

$memAfter = (Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory
$memFreed = ($memAfter - $memBefore) * 1KB
Write-Success "Free RAM after: $(Format-Size ($memAfter * 1KB))  (+$(Format-Size $memFreed) freed)"
