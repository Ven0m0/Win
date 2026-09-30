#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Stops background services, trims working sets, purges the standby list, and clears temp folders.
.DESCRIPTION
    Stops WSearch and DoSvc (not disabled; they return on next boot), then reports free RAM
    before/after around Common.ps1's Invoke-MemoryTrim and clears the per-user and system
    temp folders.
.EXAMPLE
    .\clear-memory.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param ()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Common.ps1"

# Stop only - startup type is untouched, so both services come back on next boot.
# DoSvc is trigger-started and may restart on its own when an update/Store download begins.
foreach ($serviceName in @('WSearch', 'DoSvc')) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq 'Running' -and $PSCmdlet.ShouldProcess($serviceName, 'Stop service')) {
        try {
            Stop-Service -Name $serviceName -Force
            Write-Info "Stopped service: $serviceName"
        } catch {
            Write-Warn "Could not stop ${serviceName}: $($_.Exception.Message)"
        }
    }
}

if ($PSCmdlet.ShouldProcess('All processes', 'Trim working sets and purge standby list')) {
    $memBefore = (Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory
    Write-Info "Free RAM before: $(Format-Size ($memBefore * 1KB))"

    Invoke-MemoryTrim -TypeName 'ClearMemoryTrim'
    Start-Sleep -Milliseconds 500

    $memAfter = (Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory
    $memFreed = ($memAfter - $memBefore) * 1KB
    Write-Success "Free RAM after: $(Format-Size ($memAfter * 1KB))  (+$(Format-Size $memFreed) freed)"
}

foreach ($tempPath in @($env:TEMP, "$env:SystemRoot\Temp")) {
    $before = Get-FolderSize -Path $tempPath -Unit B
    if ($PSCmdlet.ShouldProcess($tempPath, 'Clear temp folder')) {
        Clear-DirectorySafe -Path $tempPath
    }
    $after = Get-FolderSize -Path $tempPath -Unit B
    Write-Success "$tempPath : $(Format-Size ($before - $after)) freed"
}
