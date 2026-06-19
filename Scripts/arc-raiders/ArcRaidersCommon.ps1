#Requires -Version 5.1
<#
.SYNOPSIS
    Shared helpers for Arc Raiders scripts (game-boost, cleanup, start, skip-videos).
.DESCRIPTION
    Centralizes duplicated process-control, memory-trimming, Steam-discovery,
    file-glob-removal, and error-handling patterns used across all Arc Raiders scripts.
#>

# ── Discovery ─────────────────────────────────────────────────────────────────

function Find-SteamPath {
    <#
    .SYNOPSIS
        Locate the Steam installation directory from registry or default paths.
    #>
    [CmdletBinding()]
    param()

    $steamPath = $null
    try {
        $steamPath = Get-ItemProperty 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction Stop `
        | Select-Object -ExpandProperty SteamPath
    }
    catch { Write-Verbose "ArcRaidersCommon: HKCU Steam lookup failed: $_" }
    if (-not $steamPath) {
        try {
            $steamPath = Get-ItemProperty 'HKLM:\Software\Wow6432Node\Valve\Steam' -Name InstallPath -ErrorAction Stop `
            | Select-Object -ExpandProperty InstallPath
        }
        catch { Write-Verbose "ArcRaidersCommon: HKLM Steam lookup failed: $_" }
    }
    if ($steamPath) {
        $steamPath = $steamPath -replace '/', '\'
    }
    return $steamPath
}

function Find-ArcRaidersInstallPath {
    <#
    .SYNOPSIS
        Locate the Arc Raiders installation directory.
    #>
    [CmdletBinding()]
    param()

    $steamPath = Find-SteamPath
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

# ── File Cleanup ──────────────────────────────────────────────────────────────

function Remove-Glob {
    <#
    .SYNOPSIS
        Remove files matching a glob pattern and track total size/count.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,
        [ref]$TotalSize,
        [ref]$TotalCount
    )

    $items = Get-Item -Path $Pattern -Force -ErrorAction SilentlyContinue
    foreach ($item in $items) {
        $sz = 0
        if ($item.PSIsContainer) {
            try {
                $dirInfo = [System.IO.DirectoryInfo]::new($item.FullName)
                foreach ($f in $dirInfo.EnumerateFiles('*', [System.IO.SearchOption]::AllDirectories)) {
                    $sz += $f.Length
                }
            }
            catch {
                $sz = (Get-ChildItem -LiteralPath $item.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
                        Measure-Object Length -Sum).Sum
            }
        }
        else {
            $sz = $item.Length
        }
        if ($TotalSize) { $TotalSize.Value += [long]$sz }
        if ($TotalCount) { $TotalCount.Value++ }
        if ($PSCmdlet.ShouldProcess($item.FullName, 'Remove')) {
            Remove-Item $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Host "  DEL  $($item.FullName)"
    }
}

# ── Memory Utilities ──────────────────────────────────────────────────────────

function Invoke-MemoryTrim {
    <#
    .SYNOPSIS
        Trim working sets of all processes and purge the standby list.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$TypeName = 'MemUtil'
    )

    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class $TypeName {
    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr h);
    [DllImport("ntdll.dll")]
    public static extern uint NtSetSystemInformation(int infoClass, IntPtr buf, int len);

    public static void TrimAll() {
        foreach (var p in System.Diagnostics.Process.GetProcesses()) {
            try {
                IntPtr h = OpenProcess(0x1F0FFF, false, p.Id);
                if (h != IntPtr.Zero) { EmptyWorkingSet(h); CloseHandle(h); }
            } catch { System.Diagnostics.Debug.WriteLine("TrimAll process failed: " + p.ProcessName); }
        }
    }
    public static void PurgeStandby() {
        IntPtr buf = Marshal.AllocHGlobal(4);
        Marshal.WriteInt32(buf, 4);
        NtSetSystemInformation(80, buf, 4);
        Marshal.FreeHGlobal(buf);
    }
}
"@ -ErrorAction SilentlyContinue

    if ($PSCmdlet.ShouldProcess('All processes', 'Trim working sets')) {
        try {
            $method = [type]$TypeName
            $method::TrimAll()
            Write-Host "  Working sets trimmed."
        }
        catch {
            Write-Verbose "Working set trim skipped: $_"
        }
    }

    if ($PSCmdlet.ShouldProcess('Standby list', 'Purge')) {
        try {
            $method = [type]$TypeName
            $method::PurgeStandby()
            Write-Host "  Standby list purged."
        }
        catch {
            Write-Verbose "Standby purge skipped: $_"
        }
    }
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
        [string[]]$GameNames = @('ARC', 'pioneergame', 'ARC-Win64-Shipping'),
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
    foreach ($name in @('ARC', 'pioneergame', 'ARC-Win64-Shipping')) {
        $p = Get-Process -Name $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($p) { return $p }
    }
    return $null
}

# ── VDF / Steam Config Helpers ────────────────────────────────────────────────

function Set-ContentNoNewline {
    <#
    .SYNOPSIS
        Write content to a file without a trailing newline.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string[]]$Content
    )
    if ($PSCmdlet.ShouldProcess($Path, 'Write content')) {
        if ((Get-Command Set-Content).Parameters['NoNewline']) {
            Set-Content -LiteralPath $Path -Value $Content -NoNewline -Force
        }
        else {
            [System.IO.File]::WriteAllText($Path, ($Content -join [char]10))
        }
    }
}

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
            } else {
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

    function Write-ArcSummary {
        [CmdletBinding()]
        param()

        $mb = [math]::Round($script:ARC_TOTAL_SIZE / 1MB, 2)
        Write-Host ""
        Write-Host "══════════════════════════════════════"
        Write-Host " Cleaned: $($script:ARC_TOTAL_COUNT) item(s), ${mb} MB freed."
        Write-Host "══════════════════════════════════════"
    }
