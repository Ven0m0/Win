# mc-freeze.ps1

Freezes the Minecraft Java client for a fixed time when a global hotkey is pressed, then
resumes it. Requires PowerShell 7+.

On a server, suspending the client also stops network keep-alives. Keep `-Seconds` below the
~15 s keep-alive timeout (the parameter is capped at 14). Anticheat or admins may treat the
stall as a lag switch.

## Usage

```powershell
pwsh -NoProfile -File Scripts\mc-freeze.ps1 -Key R -Seconds 10
```

Press `R` in any window to freeze Minecraft for 10 seconds. Stop the script with Ctrl+C.

While the script runs, the hotkey is consumed system-wide (typing `r` anywhere does nothing).
Pick a function key (`-Key F8`) if that is a problem.

## Parameters

| Parameter | Default | Notes |
| --- | --- | --- |
| `-Seconds` | `10` | Freeze length, 1-14 |
| `-Key` | `R` | `F1`-`F24` or a single letter/digit |
| `-TitlePattern` | `^Minecraft` | Regex matched against the window title of the target |
| `-ProcessName` | `javaw` | Process to look for; override to test against another program |

## How it works

1. **Native calls.** `Add-Type` compiles a small C# class (`McFreeze`) that imports
   `RegisterHotKey`, `UnregisterHotKey` and `PeekMessage` from `user32.dll`, and
   `NtSuspendProcess` / `NtResumeProcess` from `ntdll.dll`.
2. **Hotkey.** `-Key` is mapped to a virtual-key code (`F<n>` is `0x70 + n - 1`; letters and
   digits use their ASCII code). `RegisterHotKey` registers it with no modifiers and
   `MOD_NOREPEAT`, so holding the key fires once. Registration failure throws (the key is
   probably taken by another program).
3. **Message loop.** The script loops, polling `PeekMessage` for `WM_HOTKEY` every 20 ms.
   It polls instead of blocking in `GetMessage` so Ctrl+C is still honoured.
4. **Freeze.** On a hotkey message, `Invoke-Freeze` finds the first `javaw` process whose
   `MainWindowTitle` matches `-TitlePattern` (this skips other Java apps). If none matches
   it warns and returns. Otherwise it calls `NtSuspendProcess` on the process handle, sleeps
   `-Seconds`, and calls `NtResumeProcess`.
5. **Safety.** The resume runs in a `finally` block, so the game is not left suspended if the
   sleep is interrupted. The outer `finally` unregisters the hotkey on exit.

## Limitations

- Hotkey events are only read while the script runs in a console with a message queue on
  its thread (a normal `pwsh` window). Run it in the foreground.
- Java client only. Bedrock (`Minecraft.Windows`) is not targeted.
- The suspend is process-wide, so audio and rendering freeze together.
