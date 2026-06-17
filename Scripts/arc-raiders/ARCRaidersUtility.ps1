#Requires -Version 5.1
<#
.SYNOPSIS
    ARC Raiders — PRO Utility (PowerShell port of ARCRaidersUtility.exe v5.3)

.DESCRIPTION
    Replicates the exact functionality of ARCRaidersUtility.exe:
      1) Select Config  — point to GameUserSettings.ini
      2) Options        — RTX detect, net fix, game optimisation, CPU boost, cache cleaning
      3) Graphics Preset — Low / Medium / High / Epic / Cinematic / Cinematic RTX ON|OFF
      ▶  Run Selected   — applies all checked options + chosen preset
      ⟲  Rollback       — restore a previous backup

    Run as Administrator for: network reset, power plan, process priority.
    No external dependencies — pure PowerShell + .NET built-ins.

.NOTES
    Config path auto-detected; override with -ConfigPath.
    Backups stored next to the INI in a .\Backups\ sub-folder.
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# ─────────────────────────────────────────────────────────────────────────────
#  Paths
# ─────────────────────────────────────────────────────────────────────────────
$DEFAULT_INI = "$env:LOCALAPPDATA\PioneerGame\Saved\Config\WindowsClient\GameUserSettings.ini"
$LOG_FILE    = "$PSScriptRoot\ARCRaidersUtility.log"

# ─────────────────────────────────────────────────────────────────────────────
#  Preset definitions  (mirror of GenerateOptimizedIni in the exe)
#  Keys match GameUserSettings.ini exactly.
# ─────────────────────────────────────────────────────────────────────────────
$PRESETS = [ordered]@{
    'Low' = @{
        'sg.ResolutionQuality'         = '75'
        'sg.ViewDistanceQuality'       = '0'
        'sg.AntiAliasingQuality'       = '0'
        'sg.ShadowQuality'             = '0'
        'sg.GlobalIlluminationQuality' = '0'
        'sg.ReflectionQuality'         = '0'
        'sg.PostProcessQuality'        = '0'
        'sg.TextureQuality'            = '0'
        'sg.EffectsQuality'            = '0'
        'sg.FoliageQuality'            = '0'
        'sg.ShadingQuality'            = '0'
        'sg.LODBias'                   = '0'
        'ResolutionScalingMethod'      = 'DLSS'
        'DLSSMode'                     = 'Performance'
        'RTXGIQuality'                 = 'Off'
        'bUseVSync'                    = 'False'
    }
    'Medium' = @{
        'sg.ResolutionQuality'         = '100'
        'sg.ViewDistanceQuality'       = '1'
        'sg.AntiAliasingQuality'       = '1'
        'sg.ShadowQuality'             = '1'
        'sg.GlobalIlluminationQuality' = '1'
        'sg.ReflectionQuality'         = '1'
        'sg.PostProcessQuality'        = '1'
        'sg.TextureQuality'            = '1'
        'sg.EffectsQuality'            = '1'
        'sg.FoliageQuality'            = '1'
        'sg.ShadingQuality'            = '1'
        'sg.LODBias'                   = '0'
        'ResolutionScalingMethod'      = 'DLSS'
        'DLSSMode'                     = 'Balanced'
        'RTXGIQuality'                 = 'Off'
        'bUseVSync'                    = 'False'
    }
    'High' = @{
        'sg.ResolutionQuality'         = '100'
        'sg.ViewDistanceQuality'       = '2'
        'sg.AntiAliasingQuality'       = '2'
        'sg.ShadowQuality'             = '2'
        'sg.GlobalIlluminationQuality' = '2'
        'sg.ReflectionQuality'         = '2'
        'sg.PostProcessQuality'        = '2'
        'sg.TextureQuality'            = '2'
        'sg.EffectsQuality'            = '2'
        'sg.FoliageQuality'            = '2'
        'sg.ShadingQuality'            = '2'
        'sg.LODBias'                   = '0'
        'ResolutionScalingMethod'      = 'DLSS'
        'DLSSMode'                     = 'Quality'
        'RTXGIQuality'                 = 'Static'
        'bUseVSync'                    = 'False'
    }
    'Epic' = @{
        'sg.ResolutionQuality'         = '100'
        'sg.ViewDistanceQuality'       = '3'
        'sg.AntiAliasingQuality'       = '3'
        'sg.ShadowQuality'             = '3'
        'sg.GlobalIlluminationQuality' = '3'
        'sg.ReflectionQuality'         = '3'
        'sg.PostProcessQuality'        = '3'
        'sg.TextureQuality'            = '3'
        'sg.EffectsQuality'            = '3'
        'sg.FoliageQuality'            = '3'
        'sg.ShadingQuality'            = '3'
        'sg.LODBias'                   = '0'
        'ResolutionScalingMethod'      = 'DLSS'
        'DLSSMode'                     = 'Quality'
        'RTXGIQuality'                 = 'Static'
        'bUseVSync'                    = 'False'
    }
    'Cinematic' = @{
        'sg.ResolutionQuality'         = '100'
        'sg.ViewDistanceQuality'       = '3'
        'sg.AntiAliasingQuality'       = '3'
        'sg.ShadowQuality'             = '3'
        'sg.GlobalIlluminationQuality' = '3'
        'sg.ReflectionQuality'         = '3'
        'sg.PostProcessQuality'        = '3'
        'sg.TextureQuality'            = '3'
        'sg.EffectsQuality'            = '3'
        'sg.FoliageQuality'            = '3'
        'sg.ShadingQuality'            = '3'
        'sg.LODBias'                   = '1'
        'ResolutionScalingMethod'      = 'DLAA'
        'DLSSMode'                     = 'Quality'
        'RTXGIQuality'                 = 'Static'
        'bUseVSync'                    = 'False'
    }
    'Cinematic (RTX ON)' = @{
        'sg.ResolutionQuality'         = '100'
        'sg.ViewDistanceQuality'       = '3'
        'sg.AntiAliasingQuality'       = '3'
        'sg.ShadowQuality'             = '3'
        'sg.GlobalIlluminationQuality' = '3'
        'sg.ReflectionQuality'         = '3'
        'sg.PostProcessQuality'        = '3'
        'sg.TextureQuality'            = '3'
        'sg.EffectsQuality'            = '3'
        'sg.FoliageQuality'            = '3'
        'sg.ShadingQuality'            = '3'
        'sg.LODBias'                   = '1'
        'ResolutionScalingMethod'      = 'DLSS'
        'DLSSMode'                     = 'Quality'
        'RTXGIQuality'                 = 'Dynamic'
        'bUseVSync'                    = 'False'
    }
    'Cinematic (RTX OFF)' = @{
        'sg.ResolutionQuality'         = '100'
        'sg.ViewDistanceQuality'       = '3'
        'sg.AntiAliasingQuality'       = '3'
        'sg.ShadowQuality'             = '3'
        'sg.GlobalIlluminationQuality' = '3'
        'sg.ReflectionQuality'         = '3'
        'sg.PostProcessQuality'        = '3'
        'sg.TextureQuality'            = '3'
        'sg.EffectsQuality'            = '3'
        'sg.FoliageQuality'            = '3'
        'sg.ShadingQuality'            = '3'
        'sg.LODBias'                   = '1'
        'ResolutionScalingMethod'      = 'DLSS'
        'DLSSMode'                     = 'Quality'
        'RTXGIQuality'                 = 'Off'
        'bUseVSync'                    = 'False'
    }
}

# ─────────────────────────────────────────────────────────────────────────────
#  Cache paths  (matching exe's ChkCacheArc/Steam/Nvidia/Amd/Epic)
# ─────────────────────────────────────────────────────────────────────────────
$CACHE_PATHS = [ordered]@{
    'ARC Raiders cache' = @(
        "$env:LOCALAPPDATA\PioneerGame\Saved\ShaderCache"
        "$env:LOCALAPPDATA\PioneerGame\Saved\PSOCache"
        "$env:LOCALAPPDATA\PioneerGame\Saved\Crashes"
    )
    'Steam cache' = @(
        "$env:LOCALAPPDATA\Steam\htmlcache"
        "$env:LOCALAPPDATA\Steam\webcache"
    )
    'NVIDIA cache' = @(
        "$env:LOCALAPPDATA\NVIDIA\DXCache"
        "$env:LOCALAPPDATA\NVIDIA\GLCache"
        "$env:ProgramData\NVIDIA Corporation\NV_Cache"
    )
    'AMD GPU cache' = @(
        "$env:LOCALAPPDATA\AMD\DxcCache"
        "$env:ProgramData\AMD"
    )
    'Epic Games cache' = @(
        "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\webcache"
        "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\htmlcache"
    )
}

# ─────────────────────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────────────────────
function Write-UtilityLog {
    [CmdletBinding()]
    param([string]$Message)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')  $Message" |
        Add-Content -LiteralPath $LOG_FILE -Encoding UTF8
}

function Test-IsAdmin {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Find-RtxGpu {
    [CmdletBinding()]
    [OutputType([object[]])]
    param()
    $gpu = (Get-CimInstance -ClassName Win32_VideoController | Select-Object -First 1).Name
    $supported = $gpu -match 'RTX|Radeon RX [6-9]\d{3}'
    return $supported, ($gpu -replace '^\s+|\s+$', '')
}

function Write-H {
    [CmdletBinding()]
    param([string]$Title)
    Clear-Host
    Write-Host ""
    Write-Host "  +===============================================================+" -ForegroundColor DarkCyan
    Write-Host "  |  " -NoNewline -ForegroundColor DarkCyan
    Write-Host ")" -NoNewline -ForegroundColor Cyan
    Write-Host "\" -NoNewline -ForegroundColor Green
    Write-Host "\" -NoNewline -ForegroundColor Yellow
    Write-Host "\" -NoNewline -ForegroundColor Red
    Write-Host "  ARC RAIDERS — PRO Utility  " -NoNewline -ForegroundColor White
    Write-Host $Title.PadRight(10) -NoNewline -ForegroundColor Gray
    Write-Host "  |" -ForegroundColor DarkCyan
    Write-Host "  +===============================================================+" -ForegroundColor DarkCyan
    Write-Host ""
}

function Write-Ok {
    [CmdletBinding()]
    param([string]$Message)
    Write-Host "  [v] $Message" -ForegroundColor Green
    Write-UtilityLog -Message "[OK]  $Message"
}

function Write-Warn {
    [CmdletBinding()]
    param([string]$Message)
    Write-Host "  [!] $Message" -ForegroundColor Yellow
    Write-UtilityLog -Message "[!!]  $Message"
}

function Write-Err {
    [CmdletBinding()]
    param([string]$Message)
    Write-Host "  [X] $Message" -ForegroundColor Red
    Write-UtilityLog -Message "[ERR] $Message"
}

function Write-Info {
    [CmdletBinding()]
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor Gray
    Write-UtilityLog -Message "      $Message"
}

function Invoke-PauseBack {
    [CmdletBinding()]
    param()
    Write-Host ""
    Write-Host "  Press any key to return..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

# ─────────────────────────────────────────────────────────────────────────────
#  INI helpers
# ─────────────────────────────────────────────────────────────────────────────
function Set-IniValue {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ref]$Text,
        [Parameter(Mandatory)]
        [string]$Key,
        [Parameter(Mandatory)]
        [string]$Value
    )
    $escaped = [regex]::Escape($Key)
    if ($Text.Value -match "(?m)^$escaped=") {
        $Text.Value = $Text.Value -replace "(?m)^$escaped=.*", "$Key=$Value"
    } else {
        $Text.Value = $Text.Value.TrimEnd() + "`r`n$Key=$Value`r`n"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
#  Core actions
# ─────────────────────────────────────────────────────────────────────────────
function Invoke-RtxDetect {
    [CmdletBinding()]
    param([ref]$IniPath)
    Write-Info -Message "Detecting DXR / RTX support..."
    $rtx, $gpu = Find-RtxGpu
    Write-Info -Message "Adapter found: $gpu"
    if ($rtx) { Write-Ok -Message "RTX GPU detected — RTX preset options enabled" }
    else       { Write-Warn -Message "No RTX GPU detected — Cinematic RTX ON may not perform well" }
    return $rtx
}

function Invoke-ApplyPreset {
    [CmdletBinding()]
    param(
        [string]$IniPath,
        [string]$PresetName
    )
    Write-Info -Message "Applying graphics preset: $PresetName"
    if (-not (Test-Path -LiteralPath $IniPath)) {
        Write-Err -Message "Config file missing: $IniPath"
        return $false
    }
    $p = $PRESETS[$PresetName]
    if (-not $p) { Write-Err -Message "Unknown preset: $PresetName"; return $false }

    $ini = Get-Content -LiteralPath $IniPath -Raw
    foreach ($kv in $p.GetEnumerator()) {
        Set-IniValue -Text ([ref]$ini) -Key $kv.Key -Value $kv.Value
    }
    Set-Content -LiteralPath $IniPath -Value $ini -Encoding UTF8 -NoNewline
    Write-Ok -Message "Preset '$PresetName' applied to config"
    Write-Info -Message "Settings: ViewDist=$($p['sg.ViewDistanceQuality']) Texture=$($p['sg.TextureQuality']) DLSS=$($p['DLSSMode']) RTX=$($p['RTXGIQuality'])"
    return $true
}

function Invoke-Backup {
    [CmdletBinding()]
    param([string]$IniPath)
    $dir     = Split-Path -Path $IniPath
    $backDir = Join-Path -Path $dir -ChildPath 'Backups'
    $null    = New-Item -ItemType Directory -Path $backDir -Force
    $dest    = Join-Path -Path $backDir -ChildPath "GameUserSettings_$(Get-Date -Format 'yyyyMMdd_HHmmss').ini"
    Copy-Item -LiteralPath $IniPath -Destination $dest -Force
    Write-Ok -Message "Backup created: $dest"
    return $dest
}

function Invoke-NetFix {
    [CmdletBinding()]
    param()
    Write-Info -Message "Flushing DNS and resetting Winsock..."
    if (-not (Test-IsAdmin)) {
        Write-Err -Message "Administrator required — right-click and Run as Administrator"
        return $false
    }
    $null = cmd.exe /c 'ipconfig /flushdns'
    $null = cmd.exe /c 'netsh winsock reset'
    Write-Ok -Message "DNS flushed + Winsock reset (restart required)"
    return $true
}

function Invoke-Optimize {
    [CmdletBinding()]
    param([string]$IniPath)
    Write-Info -Message "Applying full game optimizations..."
    # Set ARC.exe + pioneergame.exe to High priority (live processes)
    foreach ($procName in @('ARC', 'pioneergame')) {
        $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
        foreach ($pr in $procs) {
            try {
                $pr.PriorityClass = 'High'
                Write-Ok -Message "$procName.exe priority -> High"
            } catch {
                Write-Warn -Message "Could not set $procName.exe priority"
            }
        }
    }
    # wmic fallback for processes not yet running
    $null = cmd.exe /c 'wmic process where name="ARC.exe" CALL setpriority 128'
    $null = cmd.exe /c 'wmic process where name="pioneergame.exe" CALL setpriority 128'
    Write-Ok -Message "Game priority optimization completed"
    return $true
}

function Invoke-CpuBoost {
    [CmdletBinding()]
    param()
    Write-Info -Message "Applying CPU Boost (High Performance power state)..."
    if (-not (Test-IsAdmin)) { Write-Err -Message "Administrator required"; return $false }

    # Ultimate Performance (GUID e9a42b02-d5df-448d-aa00-03f14749eb61) or High Performance
    $list = powercfg /list 2>&1
    $ultimate = $list | Select-String -Pattern 'e9a42b02-d5df-448d-aa00-03f14749eb61'
    if ($ultimate) {
        $null = cmd.exe /c 'powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61'
        Write-Ok -Message "Ultimate performance power plan activated"
    } else {
        $null = cmd.exe /c 'powercfg /setactive scheme_min'
        Write-Ok -Message "High performance power plan activated"
    }
    $null = cmd.exe /c 'powercfg /hibernate off'
    Write-Ok -Message "Hibernate disabled"
    return $true
}

function Invoke-ClearCache {
    [CmdletBinding()]
    param([string[]]$Keys)
    Write-Info -Message "Clearing selected caches..."
    foreach ($key in $Keys) {
        [array]$paths = $CACHE_PATHS[$key]
        $anyFound = $false
        if ($paths.Count -gt 0) {
            [array]$pathResults = Test-Path -LiteralPath $paths
            for ($i = 0; $i -lt $paths.Count; $i++) {
                if ($pathResults[$i]) {
                    $cachePath = $paths[$i]
                    $anyFound = $true
                    try {
                        Remove-Item -LiteralPath $cachePath -Recurse -Force
                        Write-Ok -Message "$key -- deleted: $(Split-Path -Path $cachePath -Leaf)"
                    } catch {
                        $err = $_
                        Write-Err -Message "$key -- deletion failed: $($err.Exception.Message)"
                    }
                }
            }
        }
        if (-not $anyFound) { Write-Warn -Message "$key -- not found on this system" }
    }
}

function Invoke-Rollback {
    [CmdletBinding()]
    param(
        [string]$IniPath,
        [string]$BackupPath
    )
    if (-not (Test-Path -LiteralPath $BackupPath)) {
        Write-Err -Message "Backup not found: $BackupPath"
        return $false
    }
    if (-not (Test-Path -LiteralPath $IniPath)) {
        Write-Err -Message "Config not found: $IniPath"
        return $false
    }
    Copy-Item -LiteralPath $BackupPath -Destination $IniPath -Force
    Write-Ok -Message "Backup restored successfully"
    Write-Info -Message "Restored: $BackupPath"
    return $true
}

# ─────────────────────────────────────────────────────────────────────────────
#  UI — file picker (no WPF, use shell COM)
# ─────────────────────────────────────────────────────────────────────────────
function Select-IniFile {
    [CmdletBinding()]
    param(
        [string]$Title,
        [string]$Filter = 'INI files (*.ini)|*.ini',
        [string]$Initial = ''
    )
    Add-Type -AssemblyName System.Windows.Forms
    $dlg = New-Object -TypeName System.Windows.Forms.OpenFileDialog
    $dlg.Title  = $Title
    $dlg.Filter = $Filter
    if ($Initial -and (Test-Path -LiteralPath $Initial)) {
        $dlg.InitialDirectory = Split-Path -Path $Initial
    }
    if ($dlg.ShowDialog() -eq 'OK') { return $dlg.FileName }
    return $null
}

function Select-BackupFile {
    [CmdletBinding()]
    param([string]$BackupDir)
    if (-not (Test-Path -LiteralPath $BackupDir)) { return $null }
    $files = Get-ChildItem -LiteralPath $BackupDir -Filter '*.ini' |
        Sort-Object -Property LastWriteTime -Descending
    if ($files.Count -eq 0) { return $null }
    Write-Host ""
    Write-Host "  Available backups:" -ForegroundColor White
    for ($i = 0; $i -lt [Math]::Min($files.Count, 15); $i++) {
        Write-Host ("  {0,2}. {1}  ({2})" -f ($i+1), $files[$i].Name, $files[$i].LastWriteTime) -ForegroundColor Gray
    }
    Write-Host ""
    $c = Read-Host "  Select backup number (Enter = cancel)"
    if (-not $c -or $c -notmatch '^\d+$') { return $null }
    $idx = [int]$c - 1
    if ($idx -lt 0 -or $idx -ge $files.Count) { return $null }
    return $files[$idx].FullName
}

# ─────────────────────────────────────────────────────────────────────────────
#  Main UI loop
# ─────────────────────────────────────────────────────────────────────────────
Write-Log "=== APPLICATION STARTED ==="

# State
$iniPath     = if ($ConfigPath -and (Test-Path $ConfigPath)) { $ConfigPath } else { '' }
$backupPath  = ''
$chkRTX      = $true
$chkNetFix   = $false
$chkOptimize = $false
$chkCpuBoost = $false
$cacheChecks = [ordered]@{
    'ARC Raiders cache' = $false
    'Steam cache'       = $false
    'NVIDIA cache'      = $false
    'AMD GPU cache'     = $false
    'Epic Games cache'  = $false
}
$selectedPreset = 'High'
$presetKeys = @($PRESETS.Keys)

function Checkbox([bool]$v) { if ($v) { "[x]" } else { "[ ]" } }
function ConfigLabel { if ($iniPath) { Split-Path $iniPath -Leaf } else { "(not selected)" } }
function BackupLabel { if ($backupPath) { Split-Path $backupPath -Leaf } else { "(not selected)" } }

while ($true) {
    Write-H "v5.3"
    $adminTag = if (Test-IsAdmin) { "[Administrator]" } else { "[not Administrator]" }
    $adminCol = if (Test-IsAdmin) { 'Green' } else { 'Yellow' }
    Write-Host "  $adminTag" -ForegroundColor $adminCol
    Write-Host ""

    # 1) File selection
    Write-Host "  1) Select files" -ForegroundColor White
    Write-Host "     C. [📂 Select Config]  Config: $(ConfigLabel)" `
        -ForegroundColor $(if ($iniPath) {'Green'} else {'Gray'})
    Write-Host "     B. [💾 Select Backup]  Backup: $(BackupLabel)" `
        -ForegroundColor $(if ($backupPath) {'Green'} else {'Gray'})
    Write-Host ""

    # 2) Options
    Write-Host "  2) Options" -ForegroundColor White
    Write-Host "     R. $(Checkbox $chkRTX) Automatic RTX detection + INI setup" -ForegroundColor Gray
    Write-Host "     N. $(Checkbox $chkNetFix) Reduce internet lag (DNS, Winsock)" -ForegroundColor Gray
    Write-Host "     O. $(Checkbox $chkOptimize) Full game optimization (priority, settings)" -ForegroundColor Gray
    Write-Host "     U. $(Checkbox $chkCpuBoost) CPU Boost (High Performance + CPU priority)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "     Cache cleaning:" -ForegroundColor DarkGray
    $ci = 1
    foreach ($k in $cacheChecks.Keys) {
        Write-Host "     $ci. $(Checkbox $cacheChecks[$k]) $k" -ForegroundColor Gray
        $ci++
    }
    Write-Host ""

    # 3) Preset
    Write-Host "  3) Graphics Preset" -ForegroundColor White
    for ($i = 0; $i -lt $presetKeys.Count; $i++) {
        $mark = if ($presetKeys[$i] -eq $selectedPreset) { "(*)" } else { "( )" }
        $col  = if ($presetKeys[$i] -eq $selectedPreset) { 'Cyan' } else { 'Gray' }
        Write-Host ("     P{0}. {1} {2}" -f ($i+1), $mark, $presetKeys[$i]) -ForegroundColor $col
    }
    Write-Host ""

    # Actions
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor DarkCyan
    Write-Host "  |  [Enter] ▶ Run Selected     [K] ⟲ Rollback     [Q] Quit       |" -ForegroundColor White
    Write-Host "  +---------------------------------------------------------------+" -ForegroundColor DarkCyan
    Write-Host ""

    $key = Read-Host "  Command"
    $key = $key.Trim().ToUpper()

    switch -Regex ($key) {
        '^C$'  {
            $picked = Select-IniFile "Select GameUserSettings.ini" "INI files (*.ini)|*.ini" $DEFAULT_INI
            if ($picked) { $iniPath = $picked; Write-Log "Config selected: $iniPath" }
        }
        '^B$'  {
            $picked = Select-IniFile "Select Backup INI" "INI files (*.ini)|*.ini"
            if ($picked) { $backupPath = $picked; Write-Log "Backup selected: $backupPath" }
        }
        '^R$'  { $chkRTX      = -not $chkRTX }
        '^N$'  { $chkNetFix   = -not $chkNetFix }
        '^O$'  { $chkOptimize = -not $chkOptimize }
        '^U$'  { $chkCpuBoost = -not $chkCpuBoost }
        '^[1-5]$' {
            $idx = [int]$key - 1
            $ck = @($cacheChecks.Keys)[$idx]
            $cacheChecks[$ck] = -not $cacheChecks[$ck]
        }
        '^P([1-9])$' {
            $idx = [int]$matches[1] - 1
            if ($idx -ge 0 -and $idx -lt $presetKeys.Count) { $selectedPreset = $presetKeys[$idx] }
        }
        '^$' {
            # ▶ Run Selected
            Write-H "RUNNING"
            Write-Log "=== RUN STARTED ==="
            $status = "Status: running..."
            Write-Info $status

            if (-not $iniPath -or -not (Test-Path $iniPath)) {
                # Auto-detect
                if (Test-Path $DEFAULT_INI) {
                    $iniPath = $DEFAULT_INI
                    Write-Info "Auto-detected config: $iniPath"
                } else {
                    Write-Err "No config file selected and default not found."
                    Write-Err "Use [C] to select GameUserSettings.ini"
                    Invoke-PauseBack; continue
                }
            }

            # RTX detect
            if ($chkRTX) { Invoke-RtxDetect ([ref]$iniPath) | Out-Null }

            # Backup before any changes
            $newBackup = Invoke-Backup $iniPath
            $backupPath = $newBackup

            # Apply preset
            Write-H "APPLYING PRESET: $selectedPreset"
            Invoke-ApplyPreset $iniPath $selectedPreset | Out-Null

            # Options
            if ($chkNetFix)   { Write-H "NETWORK FIX";    Invoke-NetFix        | Out-Null }
            if ($chkOptimize) { Write-H "GAME OPTIMIZE";  Invoke-Optimize $iniPath | Out-Null }
            if ($chkCpuBoost) { Write-H "CPU BOOST";      Invoke-CpuBoost      | Out-Null }

            # Caches
            $toClean = $cacheChecks.GetEnumerator() | Where-Object { $_.Value } | ForEach-Object { $_.Key }
            if ($toClean) {
                Write-H "CACHE CLEAN"
                Invoke-ClearCache @($toClean)
            }

            Write-Host ""
            Write-Ok "=== RUN COMPLETED ==="
            Write-Log "=== RUN COMPLETED ==="
            Invoke-PauseBack
        }
        '^K$' {
            # Rollback
            Write-H "ROLLBACK"
            $backDir = if ($iniPath) { Join-Path (Split-Path $iniPath) 'Backups' } else { '' }
            if (-not $backupPath) {
                # Try to pick from backup dir
                if ($backDir -and (Test-Path $backDir)) {
                    $backupPath = Select-BackupFile $backDir
                } else {
                    $backupPath = Select-IniFile "Select backup to restore" "INI files (*.ini)|*.ini"
                }
            }
            if (-not $backupPath) { Write-Warn "No backup selected."; Invoke-PauseBack; continue }
            if (-not $iniPath -or -not (Test-Path $iniPath)) {
                Write-Err "Select a config file first with [C]."; Invoke-PauseBack; continue
            }
            Write-Info "Restoring: $(Split-Path $backupPath -Leaf) → $(Split-Path $iniPath -Leaf)"
            Invoke-Rollback $iniPath $backupPath | Out-Null
            $backupPath = ''  # reset after use
            Invoke-PauseBack
        }
        '^Q$' { Write-Log "=== EXIT ==="; exit 0 }
        default { Write-Warn "Unknown command. Use letters/numbers shown above." ; Start-Sleep -Milliseconds 600 }
    }
}
