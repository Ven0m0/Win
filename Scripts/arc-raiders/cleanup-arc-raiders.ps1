#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Arc Raiders + system cleanup: caches, logs, temp files, shader caches,
    DNS flush, memory trim, disk optimization.
#>
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

. "$PSScriptRoot\ArcRaidersCommon.ps1"

# Skip main when dot-sourced (e.g. by Pester tests) — the cleanup below deletes
# caches, runs DISM, and mutates registry/privileges on the live system.
if ($MyInvocation.InvocationName -eq '.') { return }

# ── Arc Raiders ───────────────────────────────────────────────────────────────
Write-Host "`n[Arc Raiders]"
Invoke-GlobClean "$env:LOCALAPPDATA\PioneerGame\Saved\*.upipelinecache"
Invoke-GlobClean "$env:LOCALAPPDATA\PioneerGame\Saved\CollectedShaderCode\*"
Invoke-GlobClean "$env:LOCALAPPDATA\PioneerGame\Saved\Crashes\*"
Invoke-GlobClean "$env:LOCALAPPDATA\PioneerGame\Saved\Logs\*"
Invoke-GlobClean "$env:LOCALAPPDATA\PioneerGame\Saved\Config\CrashReportClient\*"

# ── Windows Logs / Temp / Prefetch ────────────────────────────────────────────
Write-Host "`n[Windows]"
Invoke-GlobClean "$env:windir\*.log"
Invoke-GlobClean "$env:windir\*.tmp"
Invoke-GlobClean "$env:windir\Temp\*"
Invoke-GlobClean "$env:windir\Logs\*"
Invoke-GlobClean "$env:windir\Prefetch\*"
Invoke-GlobClean "$env:TEMP\*"
Invoke-GlobClean "$env:LOCALAPPDATA\cache\*"

# ── Steam cache ───────────────────────────────────────────────────────────────
Write-Host "`n[Steam]"
$steamRunning = Get-Process -Name 'steam' -ErrorAction SilentlyContinue
if ($steamRunning) {
    Write-Host "  Steam is running — stopping it now..."
    $steamRunning | Stop-Process -Force
    Start-Sleep -Seconds 3
    Write-Host "  Steam stopped."
}

$steamPath = $null
foreach ($reg in @('HKCU:\Software\Valve\Steam', 'HKLM:\Software\Wow6432Node\Valve\Steam')) {
    try {
        $p = (Get-ItemProperty $reg -ErrorAction Stop).SteamPath
        if ($p) { $steamPath = $p -replace '/', '\'; break }
    }
    catch { Write-Verbose "Steam path lookup failed: $_" }
}

if ($steamPath) {
    Invoke-GlobClean "$steamPath\appcache\httpcache\*"
    Invoke-GlobClean "$steamPath\appcache\stats\*"
    Invoke-GlobClean "$steamPath\logs\*"
    Invoke-GlobClean "$steamPath\steamapps\shadercache\*"
    Invoke-GlobClean "$env:LOCALAPPDATA\Steam\htmlcache\*"
    Write-Host "  Steam path: $steamPath"
}
else {
    Write-Host "  Steam path not found — skipped."
}

# ── NVIDIA Shader / Compute Caches ────────────────────────────────────────────
Write-Host "`n[NVIDIA caches]"
Invoke-GlobClean "$env:APPDATA\NVIDIA\ComputeCache\*"
Invoke-GlobClean "$env:LOCALAPPDATA\NVIDIA\DXCache\*"
Invoke-GlobClean "$env:LOCALAPPDATA\NVIDIA\GLCache\*"
Invoke-GlobClean "$env:LOCALAPPDATA\D3DSCache\*"
Invoke-GlobClean "$env:LOCALAPPDATA\NVIDIA Corporation\NV_Cache\*"

$nvidiaLocalLow = [System.IO.Path]::Combine(
    [Environment]::GetFolderPath('UserProfile'),
    'AppData', 'LocalLow', 'NVIDIA'
)
Invoke-GlobClean "$nvidiaLocalLow\PerDriverVersion\DXCache\*"
Invoke-GlobClean "$nvidiaLocalLow\PerDriverVersion\VkCache\*"
Invoke-GlobClean "$nvidiaLocalLow\*"

# ── AMD / Intel Shader Caches ─────────────────────────────────────────────────
Write-Host "`n[AMD/Intel caches]"
foreach ($entry in @(
        'AMD\DX9Cache', 'AMD\DxCache', 'AMD\DxcCache', 'AMD\GLCache', 'AMD\OglCache', 'AMD\VkCache',
        'Intel\ShaderCache'
    )) {
    Invoke-GlobClean "$env:LOCALAPPDATA\$entry\*"
}
Invoke-GlobClean "$([System.IO.Path]::Combine([Environment]::GetFolderPath('UserProfile'), 'AppData', 'LocalLow', 'Intel', 'ShaderCache'))\*"

# ── DNS ───────────────────────────────────────────────────────────────────────
Write-Host "`n[DNS] Flushing..."
ipconfig /flushdns | Out-Null
Write-Host "  DNS cache flushed."

# ── DISM WIM cleanup ──────────────────────────────────────────────────────────
Write-Host "`n[DISM] Cleaning WIM..."
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 |
    Select-String -Pattern 'The operation completed|Error' | ForEach-Object { Write-Host "  $_" }

# ── DirectX / Adapter cache rebuild ───────────────────────────────────────────
Write-Host "`n[DirectX] Rebuilding caches..."
foreach ($exe in @(
        (Join-Path $env:SystemRoot 'System32\directxdatabaseupdater.exe'),
        (Join-Path $env:SystemRoot 'System32\dxgiadaptercache.exe')
    )) {
    if (Test-Path $exe) {
        Start-Process $exe -WindowStyle Hidden
        Write-Host "  Started: $(Split-Path $exe -Leaf)"
    }
}

# ── Second-pass temp (post-DX rebuild) ────────────────────────────────────────
Write-Host "`n[Temp 2nd pass]"
Invoke-GlobClean "$env:windir\Temp\*"
Invoke-GlobClean "$env:TEMP\*"

# ── Memory: trim working sets + standby list ──────────────────────────────────
Write-Host "`n[Memory] Trimming..."

Invoke-MemoryTrim -TypeName 'ArcCleanupMemTrim'

rundll32.exe advapi32.dll, ProcessIdleTasks
Write-Host "  Idle tasks queued."

[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
[System.GC]::Collect()

# ── Disk Optimization ─────────────────────────────────────────────────────────
Write-Host "`n[Disk] Optimizing fixed volumes..."
Optimize-FixedVolume

# ── Summary ───────────────────────────────────────────────────────────────────
Write-ArcSummary
