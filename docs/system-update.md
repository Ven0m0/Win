# system-update.ps1

Updates Windows, package managers (Scoop, Winget, Chocolatey), WSL, Microsoft Store apps,
Defender signatures and a long list of developer tools in one run, then cleans temp files and
prints a summary of what changed. Version 2.0.0. Declares `#Requires -RunAsAdministrator`.

## Usage

```powershell
.\Scripts\system-update.ps1
.\Scripts\system-update.ps1 -DryRun
.\Scripts\system-update.ps1 -SkipCleanup -SkipWindowsUpdate
.\Scripts\system-update.ps1 -SkipNode -SkipRust -SkipGo
.\Scripts\system-update.ps1 -DeepClean -WhatChanged
.\Scripts\system-update.ps1 -Schedule -ScheduleTime "03:00"
```

## Parameters

| Parameter | Default | Notes |
| --- | --- | --- |
| `-DryRun` | off | Prints "Would run" per step; also implied by `-WhatIf`. Nothing runs, state is not saved |
| `-SkipWindowsUpdate`, `-SkipReboot` | off | `-SkipReboot` only suppresses the pending-reboot warning after Windows Update |
| `-SkipWSL`, `-SkipWSLDistros`, `-SkipDefender`, `-SkipStoreApps` | off | Skip that step |
| `-SkipNode` | off | npm, pnpm, Bun, Deno, Volta, fnm |
| `-SkipRust`, `-SkipGo`, `-SkipFlutter`, `-SkipGitLFS`, `-SkipPoetry`, `-SkipComposer`, `-SkipRuby` | off | Skip that toolchain |
| `-SkipUVTools`, `-SkipVSCodeExtensions`, `-SkipPowerShellModules` | off | Skip that step |
| `-SkipCleanup` | off | Skip the temp/DNS/Recycle Bin section |
| `-DeepClean` | off | Adds DISM StartComponentCleanup, Delivery Optimization cache, Prefetch `*.pf` |
| `-SkipDestructive` | off | With `-DeepClean`, keeps Prefetch files |
| `-UpdateOllamaModels` | off | Opt-in: `ollama pull` for each installed model |
| `-WhatChanged` | off | Diffs Winget/Scoop/Chocolatey package versions against the previous run |
| `-WingetTimeoutSec` | `300` | Per-call winget timeout; values below 30 are raised to 30 |
| `-LogPath` | `%LOCALAPPDATA%\Update-Everything\system-update.log` | Log file |
| `-Schedule` | off | Registers a daily task and exits (see below) |
| `-ScheduleTime` | `03:00` | `HH:mm`, validated by regex; used with `-Schedule` |
| `-AutoElevate`, `-NoElevate` | off | See Limitations |
| `-NoPause` | off | Skips the "Press Enter to close" prompt (only shown after `-AutoElevate`) |
| `-FastMode`, `-ParallelThrottle` | off, `4` | See Limitations |

## How it works

- **Step wrapper.** Every step runs through `Invoke-Update`, which skips it for a flag, a
  missing command ("not installed"), a missing admin right, or `-FastMode`, then records it as
  Updated, Checked, Failed or Skipped. The summary lists all four groups and section timings.
- **Topgrade first.** If `topgrade` is on PATH, one `topgrade --yes --no-retry` call replaces the
  Scoop/Winget/Chocolatey/WSL steps and all dev-tool steps. Windows Update, Store apps and
  Defender signatures still run separately.
- **Winget.** Scans with `winget upgrade --include-unknown --source winget`, then upgrades each
  id one at a time with up to 3 attempts (10 s wait on exit 1632, Windows Installer busy). As
  admin it sets `TEMP`/`TMP` to `%SystemRoot%\Temp` for the winget child process only.
  Packages whose installed version is `Unknown` are auto-pinned with a blocking pin and skipped.
- **Upgrade hooks.** Spotify, Chrome, VS Code, Foxit Reader and Adobe Acrobat Reader are closed
  before their upgrade and relaunched afterward if they were running.
- **Windows Update.** Uses the `PSWindowsUpdate` module (installs it to the CurrentUser scope if
  missing), excludes the Drivers category, and falls back to `usoclient.exe StartScan` on failure.
- **Config and state.** Optional `update-config.json` next to the script overrides keys in the
  built-in config (`StateDir`, `WingetTimeoutSec`, `TempCleanupDays`, `SkipManagers`, ...).
  State is saved to `%LOCALAPPDATA%\Update-Everything\state.json`.
- **Cleanup.** Removes items older than `TempCleanupDays` (default 7) from `%TEMP%` and, as
  admin, `%SystemRoot%\Temp`; flushes DNS; empties the Recycle Bin.
- **Schedule.** Registers task `DailySystemUpdate` (highest run level, network required) running
  the script with `-SkipReboot -NoPause`. No other parameters are forwarded to the task.
- **Notification.** Shows a BurntToast notification if that module is installed.

## Limitations

- `#Requires -RunAsAdministrator` stops the script before it starts in a non-elevated shell, so
  the `-AutoElevate` relaunch and the "running without elevation" branches are not reachable
  as written. Start it from an elevated shell.
- `-FastMode` only skips steps flagged `SlowOperation`; none of the current steps set it, so the
  switch has no effect. `-ParallelThrottle` and the `FastModeSkip`/`ManagersParallel` config
  lists are not used by the code.
- No restore point. The script modifies installed software; use `-DryRun` first.
- `-DeepClean` Prefetch deletion is permanent. `pip` upgrades skip `tesserocr`.
- Volta and fnm steps only print a message; they do not update anything.
