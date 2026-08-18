#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Trims working sets of all processes, purges the standby memory list, and clears temp folders.
.DESCRIPTION
    Reports free RAM before/after and calls Common.ps1's Invoke-MemoryTrim, then clears the
    per-user and system temp folders to reclaim disk space.
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

foreach ($tempPath in @($env:TEMP, "$env:SystemRoot\Temp")) {
    $before = Get-FolderSize -Path $tempPath -Unit B
    if ($PSCmdlet.ShouldProcess($tempPath, 'Clear temp folder')) {
        Clear-DirectorySafe -Path $tempPath
    }
    $after = Get-FolderSize -Path $tempPath -Unit B
    Write-Success "$tempPath : $(Format-Size ($before - $after)) freed"
}
