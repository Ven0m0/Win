#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Arc Raiders + system cleanup: caches, logs, temp files, shader caches,
    DNS flush, memory trim, disk optimization.
#>

$totalSize  = 0
$totalCount = 0

function Remove-Glob {
    param([string]$Pattern)
    $items = Get-Item -Path $Pattern -Force -ErrorAction SilentlyContinue
    foreach ($item in $items) {
        $sz = if ($item.PSIsContainer) {
            (Get-ChildItem $item -Recurse -File -Force -ErrorAction SilentlyContinue |
                Measure-Object Length -Sum).Sum
        } else { $item.Length }
        $script:totalSize  += [long]$sz
        $script:totalCount++
        Remove-Item $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  DEL  $($item.FullName)"
    }
}

# ── Arc Raiders ───────────────────────────────────────────────────────────────
Write-Host "`n[Arc Raiders]"
Remove-Glob "$env:LOCALAPPDATA\PioneerGame\Saved\*.upipelinecache"
Remove-Glob "$env:LOCALAPPDATA\PioneerGame\Saved\CollectedShaderCode\*"
Remove-Glob "$env:LOCALAPPDATA\PioneerGame\Saved\Crashes\*"
Remove-Glob "$env:LOCALAPPDATA\PioneerGame\Saved\Logs\*"
Remove-Glob "$env:LOCALAPPDATA\PioneerGame\Saved\Config\CrashReportClient\*"

# ── Windows Logs / Temp / Prefetch ────────────────────────────────────────────
Write-Host "`n[Windows]"
Remove-Glob "$env:windir\*.log"
Remove-Glob "$env:windir\*.tmp"
Remove-Glob "$env:windir\Temp\*"
Remove-Glob "$env:windir\Logs\*"
Remove-Glob "$env:windir\Prefetch\*"
Remove-Glob "$env:TEMP\*"
Remove-Glob "$env:LOCALAPPDATA\cache\*"

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
    } catch {}
}

if ($steamPath) {
    Remove-Glob "$steamPath\appcache\httpcache\*"
    Remove-Glob "$steamPath\appcache\stats\*"
    Remove-Glob "$steamPath\logs\*"
    Remove-Glob "$steamPath\steamapps\shadercache\*"
    Remove-Glob "$env:LOCALAPPDATA\Steam\htmlcache\*"
    Write-Host "  Steam path: $steamPath"
} else {
    Write-Host "  Steam path not found — skipped."
}

# ── NVIDIA Shader / Compute Caches ────────────────────────────────────────────
Write-Host "`n[NVIDIA caches]"
Remove-Glob "$env:APPDATA\NVIDIA\ComputeCache\*"
Remove-Glob "$env:LOCALAPPDATA\NVIDIA\DXCache\*"
Remove-Glob "$env:LOCALAPPDATA\NVIDIA\GLCache\*"
Remove-Glob "$env:LOCALAPPDATA\D3DSCache\*"
Remove-Glob "$env:LOCALAPPDATA\NVIDIA Corporation\NV_Cache\*"

$nvidiaLocalLow = [System.IO.Path]::Combine(
    [Environment]::GetFolderPath('UserProfile'),
    'AppData', 'LocalLow', 'NVIDIA'
)
Remove-Glob "$nvidiaLocalLow\PerDriverVersion\DXCache\*"
Remove-Glob "$nvidiaLocalLow\PerDriverVersion\VkCache\*"
Remove-Glob "$nvidiaLocalLow\*"

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
    'C:\Windows\System32\directxdatabaseupdater.exe',
    'C:\Windows\System32\dxgiadaptercache.exe'
)) {
    if (Test-Path $exe) {
        Start-Process $exe -WindowStyle Hidden
        Write-Host "  Started: $(Split-Path $exe -Leaf)"
    }
}

# ── Second-pass temp (post-DX rebuild) ────────────────────────────────────────
Write-Host "`n[Temp 2nd pass]"
Remove-Glob "$env:windir\Temp\*"
Remove-Glob "$env:TEMP\*"

# ── Memory: trim working sets + standby list ──────────────────────────────────
Write-Host "`n[Memory] Trimming..."

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class MemUtil {
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
            } catch {}
        }
    }
    // SystemMemoryListInformation=80, command 4=purge standby list
    public static void PurgeStandby() {
        IntPtr buf = Marshal.AllocHGlobal(4);
        Marshal.WriteInt32(buf, 4);
        NtSetSystemInformation(80, buf, 4);
        Marshal.FreeHGlobal(buf);
    }
}
"@ -ErrorAction SilentlyContinue

try { [MemUtil]::TrimAll();      Write-Host "  Working sets trimmed."  } catch { Write-Host "  WS trim skipped: $_" }
try { [MemUtil]::PurgeStandby(); Write-Host "  Standby list purged."  } catch { Write-Host "  Standby purge skipped: $_" }

rundll32.exe advapi32.dll,ProcessIdleTasks
Write-Host "  Idle tasks queued."

[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
[System.GC]::Collect()

# ── Disk Optimization ─────────────────────────────────────────────────────────
Write-Host "`n[Disk] Optimizing fixed volumes..."
Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter } | ForEach-Object {
    $dl = $_.DriveLetter
    $med = try {
        (Get-PhysicalDisk | Where-Object {
            (Get-Partition -DriveLetter $dl -ErrorAction SilentlyContinue |
                Get-Disk -ErrorAction SilentlyContinue).UniqueId -eq $_.UniqueId
        } | Select-Object -First 1).MediaType
    } catch { 'Unspecified' }

    Write-Host "  ${dl}: ($($_.FileSystem), $med)"
    if ($med -ne 'HDD') {
        Optimize-Volume -DriveLetter $dl -ReTrim -Verbose:$false
        Write-Host "    ReTrim issued."
    } else {
        Optimize-Volume -DriveLetter $dl -Defrag -Verbose:$false
        Write-Host "    Defrag issued."
    }
}

# ── Large Page Support (SeLockMemoryPrivilege) ───────────────────────────────
Write-Host "`n[LargePages] Granting SeLockMemoryPrivilege to current user..."

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class LsaUtil {
    [StructLayout(LayoutKind.Sequential)] struct LSA_UNICODE_STRING {
        public ushort Length, MaximumLength;
        public IntPtr Buffer;
    }
    [StructLayout(LayoutKind.Sequential)] struct LSA_OBJECT_ATTRIBUTES {
        public int Length, pad1; public IntPtr pad2, pad3, pad4, pad5;
    }
    [DllImport("advapi32.dll")] static extern uint LsaOpenPolicy(IntPtr sys, ref LSA_OBJECT_ATTRIBUTES attr, uint access, out IntPtr handle);
    [DllImport("advapi32.dll")] static extern uint LsaAddAccountRights(IntPtr pol, IntPtr sid, LSA_UNICODE_STRING[] rights, int count);
    [DllImport("advapi32.dll")] static extern uint LsaClose(IntPtr h);
    [DllImport("advapi32.dll")] static extern bool LookupAccountName(string sys, string name, IntPtr sid, ref int sidLen, StringBuilder dom, ref int domLen, out int use);
    [DllImport("kernel32.dll")] static extern IntPtr LocalAlloc(uint flags, int size);

    public static string Grant(string account) {
        int sidLen=0, domLen=256, use=0;
        LookupAccountName(null, account, IntPtr.Zero, ref sidLen, null, ref domLen, out use);
        IntPtr sid = LocalAlloc(0x40, sidLen);
        var dom = new StringBuilder(domLen);
        if (!LookupAccountName(null, account, sid, ref sidLen, dom, ref domLen, out use))
            return "LookupAccountName failed: " + Marshal.GetLastWin32Error();

        var attr = new LSA_OBJECT_ATTRIBUTES { Length = Marshal.SizeOf(typeof(LSA_OBJECT_ATTRIBUTES)) };
        IntPtr pol;
        uint r = LsaOpenPolicy(IntPtr.Zero, ref attr, 0x00000801, out pol);
        if (r != 0) return "LsaOpenPolicy failed: " + r;

        var priv = new LSA_UNICODE_STRING[1];
        var s = "SeLockMemoryPrivilege";
        priv[0].Buffer = Marshal.StringToHGlobalUni(s);
        priv[0].Length = (ushort)(s.Length * 2);
        priv[0].MaximumLength = (ushort)(priv[0].Length + 2);

        r = LsaAddAccountRights(pol, sid, priv, 1);
        LsaClose(pol);
        Marshal.FreeHGlobal(priv[0].Buffer);
        return r == 0 ? "OK" : "LsaAddAccountRights failed: " + r;
    }
}
"@ -ErrorAction SilentlyContinue

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$result = [LsaUtil]::Grant($currentUser)
Write-Host "  $currentUser -> SeLockMemoryPrivilege: $result"
if ($result -eq 'OK') {
    Write-Host "  NOTE: Log off and back on (or reboot) for the privilege to take effect."
}

# ── PioneerGame IFEO / Priority Registry ─────────────────────────────────────
Write-Host "`n[Registry] Applying PioneerGame IFEO settings..."
$ifeo = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\PioneerGame.exe'
$perf = "$ifeo\PerfOptions"
 
New-Item -Path $perf -Force | Out-Null
Set-ItemProperty -Path $perf -Name 'CpuPriorityClass' -Value 6   -Type DWord
Set-ItemProperty -Path $perf -Name 'IoPriority'       -Value 3   -Type DWord
Set-ItemProperty -Path $ifeo -Name 'UseLargePages'    -Value 1   -Type DWord
Write-Host "  CpuPriorityClass=6 (High), IoPriority=3 (Normal), UseLargePages=1"

# ── Summary ───────────────────────────────────────────────────────────────────
$mb = [math]::Round($totalSize / 1MB, 2)
Write-Host "`n══════════════════════════════════════"
Write-Host " Done. $totalCount item(s) deleted, ${mb} MB freed."
Write-Host "══════════════════════════════════════"
