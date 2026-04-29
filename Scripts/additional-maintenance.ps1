#Requires -Version 5.1

#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Additional Safe Windows Maintenance Script
.DESCRIPTION
    Additional safe Windows maintenance tasks that can always be run:
    1. DISM Component Store Analysis and Cleanup
    2. System Cache Rebuilds (Font, Icon, Thumbnail)
    3. Store Cache Clear
    4. BITS Queue Cleanup
    5. Temp File Cleanup
    6. DNS Client Cache Clear
    7. System Restore Point Creation
.PARAMETER DryRun
    Show what would run without executing
.PARAMETER NoRestorePoint
    Don't create a system restore point
#>

function Start-AdditionalMaintenance {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$DryRun,
        [switch]$NoRestorePoint
    )

    $ErrorActionPreference = 'Continue'
    $ProgressPreference = 'SilentlyContinue'

    # Import common functions
    . "$PSScriptRoot\Common.ps1"

    # Initialize logging
    Clear-Log
    $Results = @{}
    $StartTime = Get-Date

    Write-Header "Additional Safe Windows Maintenance"

    # 1. Create System Restore Point (optional but recommended)
    if ($NoRestorePoint) {
        Write-Info "Skipping restore point creation"
        $Results['SystemRestorePoint'] = 'SKIPPED'
    } else {
        Invoke-Operation -Name 'SystemRestorePoint' -Results $Results -DryRun:$DryRun `
        -Result 'CREATED' -Action {
            Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description "Pre-Maintenance-$(Get-Date -Format 'yyyyMMdd')" `
            -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        }
    }

    # 2. DISM Component Store Analysis
    Write-Info "=== DISM Component Store Analysis ==="
    Invoke-Operation -Name 'DISM_ComponentAnalysis' -Results $Results -DryRun:$DryRun -Result 'COMPLETE' `
        -Action {} -Command 'DISM' -ArgumentList '/Online /Cleanup-Image /AnalyzeComponentStore'
    Invoke-Operation -Name 'DISM_ComponentCleanup' -Results $Results -DryRun:$DryRun -Result 'COMPLETE' `
        -Action {} -Command 'DISM' -ArgumentList '/Online /Cleanup-Image /StartComponentCleanup'

    # 3. Clear Windows Store Cache
    Invoke-Operation -Name 'StoreCacheClear' -Results $Results -DryRun:$DryRun -Result 'CLEARED' `
        -Action {} -Command 'wsreset.exe' -ArgumentList '-i'

    # 4. Clear BITS Queue
    Invoke-Operation -Name 'BITSClear' -Results $Results -DryRun:$DryRun -Result 'CLEARED' -Action {
        Import-Module BitsTransfer -ErrorAction SilentlyContinue
        Get-BitsTransfer -AllUsers | Remove-BitsTransfer -ErrorAction SilentlyContinue
    }

    # 5. Rebuild Font Cache
    Invoke-Operation -Name 'FontCache' -Results $Results -DryRun:$DryRun -Result 'REBUILT' -Action {
        Invoke-ServiceOperation -Name 'FontCache' -Action {
            $fontCachePath = "$env:SystemRoot\ServiceProfiles\LocalService\AppData\Local\FontCache"
            if (Test-Path $fontCachePath) {
                Clear-PathSafe -Path "$fontCachePath\*"
            }
        }
    }

    # 6. Clear Icon Cache
    Invoke-Operation -Name 'IconCache' -Results $Results -DryRun:$DryRun -Result 'CLEARED' -Action {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        $iconCachePath = "$env:LOCALAPPDATA\IconCache.db"
        if (Test-Path $iconCachePath) {
            Clear-PathSafe -Path $iconCachePath
        }
        $thumbCachePath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db"
        Clear-PathSafe -Path $thumbCachePath
        Start-Process explorer
    }

    # 7. Clear Thumbnail Cache
    Invoke-Operation -Name 'ThumbCache' -Results $Results -DryRun:$DryRun -Result 'CLEARED' -Action {
        $thumbPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
        Clear-PathSafe -Path "$thumbPath\thumbcache_*.db"
    }

    # 8. Clear DNS Client Cache
    Invoke-Operation -Name 'DNSCache' -Results $Results -DryRun:$DryRun -Result 'CLEARED' -Action { `
        Clear-DnsClientCache -ErrorAction Stop `
    }

    # 9. Clear Temp Files
    Invoke-Operation -Name 'TempFiles' -Results $Results -DryRun:$DryRun `
        -Result 'CLEARED' -Action {
        $tempPaths = @(
            $env:TEMP,
            "$env:SystemRoot\Temp",
            "$env:LOCALAPPDATA\Temp"
        )
        $cleared = 0
        foreach ($path in $tempPaths) {
            if (Test-Path $path) {
                Clear-PathSafe -Path $path -Recurse
                $cleared++
            }
        }
        Write-Success "Temp files cleaned from $cleared locations"
    }

    # Display summary
    Show-Summary -Results $Results -StartTime $StartTime

    # Write log file
    $logFileName = "maintenance-log-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    $logFile = Join-Path $PSScriptRoot $logFileName
    $logContent = Get-Log
    $logContent | Out-File -FilePath $logFile
    Write-Info "Log written to: $logFile"

    Write-Warn "NOTE: Some changes may require a restart to take full effect."
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-AdditionalMaintenance @PSBoundParameters
    exit $LASTEXITCODE
}
