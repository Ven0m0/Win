# system-maintenance.ps1

Maintenance hub selected with `-Action`: volume optimization plus MSI Afterburner cleanup,
a disk cleanup GUI, shader/log cache purge, deeper component maintenance, and driver store
cleanup. Requires elevation except under `-DryRun`.

## Usage

Default action (optimize and retrim `C:`, then trim MSI Afterburner files):

```powershell
.\Scripts\system-maintenance.ps1
```

Defrag every volume:

```powershell
.\Scripts\system-maintenance.ps1 -Action Defrag -AllVolumes
```

Preview the Extra action without a restore point:

```powershell
.\Scripts\system-maintenance.ps1 -Action Extra -NoRestorePoint -DryRun
```

Clear shader caches, or open the cleanup GUI:

```powershell
.\Scripts\system-maintenance.ps1 -Action Shader -Verbose
.\Scripts\system-maintenance.ps1 -Action Disk
```

## Parameters

| Parameter | Default | Notes |
| --- | --- | --- |
| `-Action` | `Defrag` | `Defrag`, `Disk`, `Shader`, `Extra`, `DriverCleanup`, `All` |
| `-Volume` | `C:` | Defrag target; ignored with `-AllVolumes` |
| `-AllVolumes` | off | Defrag all volumes |
| `-NoDefrag` | off | Skip the defrag step (Defrag and All) |
| `-NoMsi` | off | Skip MSI Afterburner cleanup (Defrag and All) |
| `-MsiDir` | `${env:ProgramFiles(x86)}\MSI Afterburner` | Afterburner install folder |
| `-NoRestorePoint` | off | Extra only: skip the restore point |
| `-DryRun` | off | Preview; skips elevation |

`-WhatIf`/`-Confirm` are declared (`SupportsShouldProcess`) but only honored by MSI cleanup,
driver cleanup and the WaasMedic ownership step. Use `-DryRun` for previews.

## Actions

| Action | What it does |
| --- | --- |
| `Defrag` | `defrag.exe /O` then `/L` (retrim) on the volume; with `-AllVolumes` runs `/C /O` then `/C /L`. Then MSI cleanup if `-MsiDir` exists |
| `Disk` | WinForms checklist of `cleanmgr` categories plus Event Viewer logs, Windows logs, TEMP |
| `Shader` | Stops Steam, clears Steam/Epic caches and NVIDIA/AMD/Intel/D3D shader caches |
| `Extra` | Restore point, DISM RestoreHealth, `sfc /scannow`, DISM StartComponentCleanup, then cache and log cleanup |
| `DriverCleanup` | `rundll32 pnpclean.dll,RunDLL_PnpClean /DRIVERS /MAXCLEAN` |
| `All` | Defrag, MSI cleanup, Shader, Extra. Does not include Disk or DriverCleanup |

## How it works

- **MSI cleanup.** Copies `MSIMystic.usf`, `MSIWin11Dark.usf` and `defaultX.uxf` out of
  `Skins`, deletes `Skins`, `Localization`, `Doc` and `SDK\Doc`, recreates `Skins`, moves the
  three skins back, and removes the SDK and ReadMe Start Menu shortcuts.
- **Extra order.** DISM RestoreHealth runs before SFC because SFC repairs from the component
  store. Each DISM/SFC step has a 1800 s timeout and can take 30+ minutes.
- **Extra cleanup list.** Windows Update download cache (with `wuauserv` stopped), Store cache
  (`wsreset -i`), BITS queue, font cache, icon and thumbnail cache (restarts `explorer`), DNS
  cache, temp folders, Recycle Bin, `energy-report.html`, Application and System event logs.
- **Log.** Extra writes `maintenance-log-<timestamp>.txt` to `$env:TEMP` (not under `-DryRun`).
- **Shader.** Reads the Steam path from `HKCU:\SOFTWARE\Valve\Steam`, parses
  `libraryfolders.vdf`, and stops Steam gracefully. The only app targeted is Counter-Strike 2
  (app id 730).
- **Disk GUI.** Always clears Prefetch, Windows Temp, user Temp and INetCache after OK. Ticked
  categories are set as `StateFlags0069` under `VolumeCaches`, then `cleanmgr /sagerun:69`.

## Limitations

- `-DryRun` does nothing for `Shader`, `DriverCleanup` and `Disk` (each prints a notice and
  returns).
- Clearing event logs and deleting caches cannot be undone. Only Extra makes a restore point.
- MSI cleanup removes MSI Afterburner skins other than the three kept and its docs.
- On error the script writes the message and exits with code 1.
