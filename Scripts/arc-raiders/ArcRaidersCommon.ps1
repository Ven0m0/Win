#Requires -Version 5.1
<#
.SYNOPSIS
    Shared helpers for Arc Raiders scripts (game-boost, cleanup, start, skip-videos).
.DESCRIPTION
    Centralizes duplicated process-control, Steam-discovery, and VDF/disk-optimization
    patterns used across all Arc Raiders scripts. File-glob-removal and memory-trim
    helpers live in Common.ps1 (Remove-Glob, Set-ContentNoNewline, Invoke-MemoryTrim).
#>

. "$PSScriptRoot\..\Common.ps1"

# ── Discovery ─────────────────────────────────────────────────────────────────

function Find-ArcRaidersInstallPath {
    <#
    .SYNOPSIS
        Locate the Arc Raiders installation directory.
    #>
    [CmdletBinding()]
    param()

    $steamPath = Get-SteamPath
    if ($steamPath) {
        $candidate = Join-Path $steamPath 'steamapps\common\Arc Raiders\PioneerGame'
        if (Test-Path $candidate) {
            return Split-Path $candidate -Parent
        }
    }

    $pf86 = ${env:ProgramFiles(x86)}
    $candidate = Join-Path $pf86 'Steam\steamapps\common\Arc Raiders\PioneerGame'
    if (Test-Path $candidate) {
        return Split-Path $candidate -Parent
    }

    $candidate = Join-Path $env:ProgramFiles 'Epic Games\Arc Raiders\PioneerGame'
    if (Test-Path $candidate) {
        return Split-Path $candidate -Parent
    }

    if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot '..\PioneerGame'))) {
        return (Join-Path $PSScriptRoot '..')
    }

    return $null
}

# ── Process / Game Helpers ────────────────────────────────────────────────────

function Test-RunningAsAdmin {
    <#
    .SYNOPSIS
        Check if the current process is elevated.
    #>
    [CmdletBinding()]
    param()
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Set-GameProcessPriority {
    <#
    .SYNOPSIS
        Set priority class for matching game processes.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string[]]$GameNames = @('PioneerGame'),
        [System.Diagnostics.ProcessPriorityClass]$Priority = 'High'
    )

    foreach ($name in $GameNames) {
        $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
        foreach ($pr in $procs) {
            if ($PSCmdlet.ShouldProcess("$name (PID $($pr.Id))", "Set priority to $Priority")) {
                try {
                    $pr.PriorityClass = $Priority
                    Write-Host "  $name.exe priority -> $Priority"
                }
                catch {
                    Write-Verbose "Could not set $name.exe priority: $_"
                }
            }
        }
    }
}

function Get-ArcRaidersGameProcess {
    <#
    .SYNOPSIS
        Find the running Arc Raiders process.
    #>
    [CmdletBinding()]
    param()
    foreach ($name in @('PioneerGame')) {
        $p = Get-Process -Name $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($p) { return $p }
    }
    return $null
}

# ── VDF / Steam Config Helpers ────────────────────────────────────────────────

function Set-VdfValue {
    <#
    .SYNOPSIS
        Ensure a nested VDF path exists and optionally set a value.
    #>
    param(
        [hashtable]$Vdf,
        [string]$Path,
        [string]$Value
    )
    $s = $Path -split '\\', 2
    $key = $s[0]
    $recurse = if ($s.Count -gt 1) { $s[1] } else { $null }
    if ($key -and $Vdf.Keys -notcontains $key) { $Vdf[$key] = [ordered]@{} }
    if ($recurse) { Set-VdfValue $Vdf[$key] $recurse $Value }
}

# ── Disk Optimization ─────────────────────────────────────────────────────────

function Optimize-FixedVolume {
    <#
    .SYNOPSIS
        Issue ReTrim (SSD/NVMe) or Defrag (HDD) on all fixed volumes.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $physicalDisks = @(Get-PhysicalDisk -ErrorAction SilentlyContinue)
    Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter } | ForEach-Object {
        $dl = $_.DriveLetter
        $med = try {
            $diskId = (Get-Partition -DriveLetter $dl -ErrorAction SilentlyContinue |
                    Get-Disk -ErrorAction SilentlyContinue).UniqueId
            if ($diskId) {
                ($physicalDisks | Where-Object { $_.UniqueId -eq $diskId } | Select-Object -First 1).MediaType
            }
            else {
                'Unspecified'
            }
        }
        catch { 'Unspecified' }

        Write-Host "  ${dl}: ($($_.FileSystem), $med)"
        if ($med -ne 'HDD') {
            if ($PSCmdlet.ShouldProcess("${dl}:", 'ReTrim')) {
                Optimize-Volume -DriveLetter $dl -ReTrim -Verbose:$false
            }
        }
        else {
            if ($PSCmdlet.ShouldProcess("${dl}:", 'Defrag')) {
                Optimize-Volume -DriveLetter $dl -Defrag -Verbose:$false
            }
        }
    }
}

# ── Output ────────────────────────────────────────────────────────────────────

$script:ARC_TOTAL_SIZE = 0
$script:ARC_TOTAL_COUNT = 0

function Invoke-GlobClean {
    <#
    .SYNOPSIS
        Remove files matching a glob pattern, tallying size/count into the shared Arc Raiders totals.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Pattern)
    Remove-Glob -Pattern $Pattern -TotalSize ([ref]$script:ARC_TOTAL_SIZE) -TotalCount ([ref]$script:ARC_TOTAL_COUNT)
}

function Write-ArcSummary {
    [CmdletBinding()]
    param()

    $mb = [math]::Round($script:ARC_TOTAL_SIZE / 1MB, 2)
    Write-Host ""
    Write-Host "══════════════════════════════════════"
    Write-Host " Cleaned: $($script:ARC_TOTAL_COUNT) item(s), ${mb} MB freed."
    Write-Host "══════════════════════════════════════"
}
