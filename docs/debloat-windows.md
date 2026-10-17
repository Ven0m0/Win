# debloat-windows.ps1

Removes bloatware Appx packages, disables telemetry-related services, optional features and
scheduled tasks, applies privacy registry tweaks, and cleans temp/cache folders. Interactive
menu by default; `-Unattended` runs every phase without prompts. Requires Administrator
(`#Requires -RunAsAdministrator`) and imports `Scripts\Common.ps1`.

## Usage

Interactive menu (run all phases or pick one):

```powershell
.\Scripts\debloat-windows.ps1
```

Unattended, all phases:

```powershell
.\Scripts\debloat-windows.ps1 -Unattended
```

Skip the restore point:

```powershell
.\Scripts\debloat-windows.ps1 -Unattended -NoRestorePoint
```

Restore menu (re-enable services, tasks, registry values):

```powershell
.\Scripts\debloat-windows.ps1 -Restore
```

## Parameters

| Parameter | Default | Notes |
| --- | --- | --- |
| `-Restore` | off | Opens a restore menu instead of the debloat menu |
| `-NoRestorePoint` | off | Skips `New-RestorePoint` ("Before Debloating") |
| `-Unattended` | off | Runs all six phases, no console UI or menu, exits 0 |

The script has no `[CmdletBinding()]` at script level, so `-WhatIf`/`-Confirm` are not accepted.
There is no dry-run mode.

## Phases

| Phase | Action |
| --- | --- |
| 1. Apps | Removes Appx packages (all users, plus provisioned) matching `AppxToRemove` in `Scripts\packages.psd1` |
| 2. Services | Disables 18 services (DiagTrack, Xbox services, MapsBroker, WerSvc, Fax, ...); sets SysMain, WSearch, BITS, wuauserv, TabletInputService, PcaSvc to Manual |
| 3. Features | Disables WorkFolders-Client, WindowsMediaPlayer, Internet Printing Client, Recall (only if currently Enabled; `-NoRestart`) |
| 4. Tasks | Disables a fixed list of scheduled tasks plus every task in the CEIP and `Feedback\Siuf` folders |
| 5. Registry | Applies 20 tweaks via `Set-RegistryValue` (telemetry, Cortana, web search, suggestions, advertising ID, OneDrive sync, SmartScreen, Delivery Optimization, clipboard history, background apps, ...) |
| 6. Cleanup | Clears user/Windows Temp, Prefetch, Windows Update download cache; flushes DNS; empties the Recycle Bin; prints space freed |

## How it works

- **Restore point.** Created once, only by the "Run All Phases" path (menu option 1 or
  `-Unattended`), unless `-NoRestorePoint`. Running a single phase from the menu does not create
  one. Restore mode does not create one either.
- **Phase 6 and Windows Update.** If `wuauserv` was running, it is stopped before clearing the
  update cache and started again afterward.
- **Failures.** Most service, task and Appx calls use `-ErrorAction SilentlyContinue`, so a
  single failure is skipped without aborting.
- **Finish.** Run-all ends with `Show-RestartRequired`.

## Limitations

- Restore is partial. It re-enables the 18 disabled services (startup Automatic, then started)
  and sets the 6 Manual services to Automatic, which may not match their original start type.
  It re-enables only 6 of the disabled tasks, and reverts only a subset of the registry tweaks
  (AllowTelemetry, DoNotShowFeedbackNotifications, AllowCortana set back to absent;
  SystemPaneSuggestionsEnabled and AdvertisingInfo `Enabled` set to 1).
- Not reverted: removed Appx packages, disabled Windows features, SmartScreen, OneDrive,
  Delivery Optimization and the other registry tweaks, and everything deleted in phase 6.
  Use the restore point for those.
- Phase 5 disables SmartScreen and OneDrive file sync via policy keys; review the list in the
  script before running on a machine you rely on for those.
