#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Run gaming optimizations: fullscreen settings, MPO, shader cache cleanup, DLSS updates.
.DESCRIPTION
    Comprehensive gaming performance tuning for Windows. Applies registry tweaks
    for fullscreen optimization, Multiplane Overlay (MPO), clears shader caches,
    and can force-update DLSS to latest version across game directories.
    Wraps existing scripts in Scripts/ for one-click execution.
.PARAMETER FullscreenOnly
    Only apply fullscreen/GameConfig registry tweaks.
.PARAMETER ClearShaderCacheOnly
    Only clear shader caches (Steam, temp, GPU).
.PARAMETER UpdateDLSSOnly
    Only force-update DLSS to latest version.
.PARAMETER NoRestorePoint
    Skip creating a system restore point before changes.
.PARAMETER WhatIf
    Show what would change without modifying system.
.EXAMPLE
    .\Optimize-Gaming.ps1
    # Applies all gaming optimizations with restore point
.EXAMPLE
    .\Optimize-Gaming.ps1 -ClearShaderCacheOnly -WhatIf
#>
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'All')]
param(
    [Parameter(ParameterSetName = 'Fullscreen')]
    [switch]$FullscreenOnly,

    [Parameter(ParameterSetName = 'ShaderCache')]
    [switch]$ClearShaderCacheOnly,

    [Parameter(ParameterSetName = 'DLSS')]
    [switch]$UpdateDLSSOnly,

    [switch]$NoRestorePoint,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = $PWD
if ($PSScriptRoot -like "*.kilo/commands/*") {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

Write-Host '=== Gaming Optimization Suite ===' -ForegroundColor Cyan

# Elevation check (most gaming tweaks need admin)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Host '  [INFO] Some optimizations require admin. Relaunching as administrator...' -ForegroundColor Yellow
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    $shell = if ($pwshCmd) { $pwshCmd.Source } else { 'PowerShell.exe' }
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process $shell -ArgumentList $argList -Verb RunAs
    exit 0
}

# Create restore point unless suppressed
if (-not $NoRestorePoint -and $PSCmdlet.ParameterSetName -eq 'All') {
    $rpDesc = "Before gaming optimizations - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    Write-Host "  Creating restore point: $rpDesc" -ForegroundColor Cyan
    try {
        Checkpoint-Computer -Description $rpDesc -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Host '  Restore point created.' -ForegroundColor Green
    } catch {
        Write-Warning "  Failed to create restore point: $_"
    }
}

$actionsRun = 0

# --- Fullscreen/MPO Optimization ---
if ($PSCmdlet.ParameterSetName -eq 'All' -or $FullscreenOnly) {
    Write-Host '`n[1/3] Fullscreen & MPO Optimization' -ForegroundColor Cyan
    $gamingDisplayScript = Join-Path $repoRoot 'Scripts/gaming-display.ps1'
    $gpuDisplayScript = Join-Path $repoRoot 'Scripts/gpu-display-manager.ps1'

    if (Test-Path $gamingDisplayScript) {
        if ($PSCmdlet.ShouldProcess('gaming-display.ps1', 'Apply fullscreen tweaks')) {
            pwsh -NoLogo -NoProfile -File $gamingDisplayScript -WhatIf:$WhatIf
            if ($LASTEXITCODE -eq 0) { $actionsRun++ }
        }
    } else {
        Write-Warning "  Script not found: $gamingDisplayScript"
    }

    if (Test-Path $gpuDisplayScript) {
        if ($PSCmdlet.ShouldProcess('gpu-display-manager.ps1', 'Apply GPU settings')) {
            pwsh -NoLogo -NoProfile -File $gpuDisplayScript -WhatIf:$WhatIf
            if ($LASTEXITCODE -eq 0) { $actionsRun++ }
        }
    } else {
        Write-Warning "  Script not found: $gpuDisplayScript"
    }
}

# --- Shader Cache Cleanup ---
if ($PSCmdlet.ParameterSetName -eq 'All' -or $ClearShaderCacheOnly) {
    Write-Host '`n[2/3] Shader Cache Cleanup' -ForegroundColor Cyan
    $shaderCacheScript = Join-Path $repoRoot 'Scripts/shader-cache.ps1'

    if (Test-Path $shaderCacheScript) {
        if ($PSCmdlet.ShouldProcess('shader-cache.ps1', 'Clear shader caches')) {
            pwsh -NoLogo -NoProfile -File $shaderCacheScript -WhatIf:$WhatIf
            if ($LASTEXITCODE -eq 0) { $actionsRun++ }
        }
    } else {
        # Fallback: manual cleanup
        Write-Host '  shader-cache.ps1 not found, running manual cleanup...' -ForegroundColor Yellow
        $cachePaths = @(
            "$env:LOCALAPPDATA\Temp",
            "$env:APPDATA\Steam\shadercache",
            "$env:LOCALAPPDATA\NVIDIA\NvCache",
            "$env:LOCALAPPDATA\AMD\Vulkan"
        )
        foreach ($path in $cachePaths) {
            if (Test-Path $path) {
                Write-Host "  Cleaning: $path" -ForegroundColor Gray
                try {
                    Remove-Item "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                } catch { }
            }
        }
        $actionsRun++
    }
}

# --- DLSS Update ---
if ($PSCmdlet.ParameterSetName -eq 'All' -or $UpdateDLSSOnly) {
    Write-Host '`n[3/3] DLSS Force-Latest' -ForegroundColor Cyan
    $dlssScript = Join-Path $repoRoot 'Scripts/DLSS-force-latest.ps1'

    if (Test-Path $dlssScript) {
        if ($PSCmdlet.ShouldProcess('DLSS-force-latest.ps1', 'Update DLSS DLLs')) {
            pwsh -NoLogo -NoProfile -File $dlssScript -WhatIf:$WhatIf
            if ($LASTEXITCODE -eq 0) { $actionsRun++ }
        }
    } else {
        Write-Warning "  Script not found: $dlssScript"
    }
}

Write-Host '' -ForegroundColor Cyan
if ($WhatIf) {
    Write-Host '  WhatIf mode — no changes made.' -ForegroundColor Yellow
} else {
    Write-Host "  Completed: $actionsRun action(s) executed" -ForegroundColor Green
}
