#Requires -Version 5.1
<#
.SYNOPSIS
  Freezes the Minecraft client for a fixed time when a global hotkey is pressed.
.DESCRIPTION
  Registers a global hotkey, then suspends the Minecraft javaw process with
  NtSuspendProcess for -Seconds and resumes it with NtResumeProcess. The resume
  runs in a finally block so the game is never left suspended. Stop with Ctrl+C.

  On a server, suspending also stops network keep-alives. Keep -Seconds below the
  ~15 s keep-alive timeout. Anticheat or admins may treat the stall as a lag switch.

  On resume Minecraft runs up to 10 catch-up ticks before drawing a frame, so a player in mid-air drops
  ~0.5 s worth of gravity at once. The script cannot prevent this; only a client mod can.
.EXAMPLE
  pwsh -NoProfile -File mc-freeze.ps1 -Key R -Seconds 10
  Press R in any window to freeze Minecraft for 10 seconds. While the script runs,
  R is consumed system-wide (typing "r" anywhere does nothing); stop the script to get it back.
#>
[CmdletBinding()]
param (
  # Freeze length; capped below the server keep-alive timeout
  [ValidateRange(1, 14)][int]$Seconds = 10,
  # Function key or single letter/digit that triggers the freeze
  [ValidatePattern('^(F([1-9]|1[0-9]|2[0-4])|[A-Za-z0-9])$')][string]$Key = 'R',
  # Window title regex of the target; overridable for testing against another process
  [string]$TitlePattern = '^Minecraft',
  [string]$ProcessName = 'javaw'
)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class McFreeze {
  [StructLayout(LayoutKind.Sequential)]
  public struct MSG { public IntPtr hwnd; public uint message; public UIntPtr wParam; public IntPtr lParam; public uint time; public int x; public int y; }

  [DllImport("user32.dll", SetLastError = true)] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint mods, uint vk);
  [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
  [DllImport("user32.dll")] public static extern int PeekMessage(out MSG msg, IntPtr hWnd, uint min, uint max, uint remove);
  [DllImport("ntdll.dll")] public static extern int NtSuspendProcess(IntPtr handle);
  [DllImport("ntdll.dll")] public static extern int NtResumeProcess(IntPtr handle);
}
'@

$WM_HOTKEY = 0x0312
$MOD_NOREPEAT = 0x4000
$PM_REMOVE = 1
$hotkeyId = 1
$vk = if ($Key.Length -gt 1) {
  0x70 + ([int]$Key.Substring(1) - 1)   # VK_F1 = 0x70
} else {
  [int][char]$Key.ToUpperInvariant()    # letters and digits: VK equals the ASCII code
}

if (-not [McFreeze]::RegisterHotKey([IntPtr]::Zero, $hotkeyId, $MOD_NOREPEAT, $vk)) {
  throw "Could not register $Key (already taken by another program?)."
}

function Invoke-Freeze {
  $target = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -match $TitlePattern } |
    Select-Object -First 1
  if (-not $target) {
    Write-Warning "No $ProcessName window matching '$TitlePattern'."
    return
  }

  # Process.Handle throws and NtSuspendProcess returns an NTSTATUS (non-zero = failure) when access is denied
  $handle = $null
  $suspendStatus = -1
  try {
    $handle = $target.Handle
    $suspendStatus = [McFreeze]::NtSuspendProcess($handle)
  } catch {
    $err = $_
    Write-Warning "Cannot open PID $($target.Id): $($err.Exception.Message)"
  }
  if ($suspendStatus -ne 0) {
    Write-Warning ('Could not suspend PID {0} (NTSTATUS 0x{1:X8}); try an elevated shell.' -f $target.Id, $suspendStatus)
    exit 1
  }

  Write-Host "Freezing PID $($target.Id) for $Seconds s"
  try {
    Start-Sleep -Seconds $Seconds
  } finally {
    $resumeStatus = [McFreeze]::NtResumeProcess($handle)
    if ($resumeStatus -ne 0) {
      Write-Warning ('NtResumeProcess failed for PID {0} (NTSTATUS 0x{1:X8}); resume it manually.' -f $target.Id, $resumeStatus)
    } else {
      Write-Host 'Resumed'
    }
  }
}

Write-Host "Press $Key to freeze '$ProcessName' for $Seconds s. Ctrl+C to quit."
try {
  $msg = New-Object -TypeName McFreeze+MSG
  while ($true) {
    # Poll instead of blocking in GetMessage so Ctrl+C is still honoured
    if ([McFreeze]::PeekMessage([ref]$msg, [IntPtr]::Zero, $WM_HOTKEY, $WM_HOTKEY, $PM_REMOVE) -ne 0) {
      Invoke-Freeze
    }
    Start-Sleep -Milliseconds 20
  }
} finally {
  $null = [McFreeze]::UnregisterHotKey([IntPtr]::Zero, $hotkeyId)
}
