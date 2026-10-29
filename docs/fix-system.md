# fix-system.ps1

Repair hub selected with `-Action`: system integrity repair (DISM, SFC, CHKDSK, network, WMI),
Windows Update component reset, a read-only health check, and restart helpers. Requires
Administrator (`#Requires -RunAsAdministrator`). Does not create a restore point.

## Usage

Preview the default repair:

```powershell
.\Scripts\fix-system.ps1 -Action System -DryRun
```

Fast repair (DISM + SFC only):

```powershell
.\Scripts\fix-system.ps1 -Action System -QuickScan
```

Reset Windows Update components, previewing first:

```powershell
.\Scripts\fix-system.ps1 -Action WindowsUpdate -WhatIf
.\Scripts\fix-system.ps1 -Action WindowsUpdate
```

Read-only diagnostics:

```powershell
.\Scripts\fix-system.ps1 -Action Health
```

## Parameters

| Parameter | Default | Notes |
| --- | --- | --- |
| `-Action` | `System` | `System`, `WindowsUpdate`, `Health`, `All`, `Restart`, `RestartToBios` |
| `-QuickScan` | off | System: only DISM and the first SFC pass |
| `-SkipDiskCheck` | off | System: skip CHKDSK |
| `-SkipNetworkFix` | off | System: skip winsock/IP reset and DNS flush |
| `-SkipWUReset` | off | System: skip the Windows Update service reset |
| `-ScheduleChkdsk` | off | System: answer Y to schedule `chkdsk /f /r` when CHKDSK reports it is needed |
| `-DryRun` | off | Preview; for System, WindowsUpdate, All it is merged with `-WhatIf` |
| `-NoReboot` | off | System: no reboot recommendation at the end |
| `-NoReport` | off | Skip the report file (System and Health) |

## Actions

| Action | What it does |
| --- | --- |
| `System` | 1 DISM `/RestoreHealth /StartComponentCleanup /ResetBase` (one command), 2 SFC, 3 `chkdsk /scan`, 4 network repairs, 5 WMI verify and salvage, 6 WU service reset, 7 SFC pass 2 |
| `WindowsUpdate` | Stops BITS/wuauserv/CryptSvc and others, clears temp, Prefetch and BITS downloader cache, renames `SoftwareDistribution` and `catroot2`, re-registers 12 DLLs, `bitsadmin /reset /allusers`, `netsh winsock reset`, `gpupdate /force`, restarts services |
| `Health` | Physical disk health, volume free space under 10 percent, pending updates (COM search), Automatic services not running, temp dirs over 5 GB, startup items |
| `All` | `System` with the WU reset skipped, then `WindowsUpdate`. Does not include Health |
| `Restart` | `Restart-Computer -Force` (honors `-WhatIf`/`-Confirm`) |
| `RestartToBios` | `shutdown.exe /r /fw /t 0` (honors `-WhatIf`/`-Confirm`) |

## How it works

- **Preview.** The dispatcher computes `$preview = $DryRun -or $WhatIfPreference` and passes it
  to both the System path (`-DryRun`) and the Windows Update path (`-WhatIf`), so `-Action All
  -DryRun` does not run the WU repair for real. `Health` honors `-DryRun` only.
- **Renames, not deletes.** `SoftwareDistribution` and `catroot2` are renamed with a timestamp
  suffix (`SoftwareDistribution-yyyyMMdd-HHmmss`), so they can be restored by hand.
- **SFC output.** Parsed from text first (UTF-16 NULs stripped), exit code as fallback.
- **Reports.** Written to `$env:TEMP` as `fix-system-report-<timestamp>.txt` and
  `fix-system-health-report-<timestamp>.txt`. The System report is skipped under `-DryRun`.

## Limitations

- DISM and SFC steps can run for tens of minutes. Network and WU resets need a reboot.
- `-NoReboot` only suppresses the reminder text; the script never reboots by itself, except for
  the `Restart` and `RestartToBios` actions.
- `Restart` uses `-Force`, which closes applications without prompting.
- `winsock reset` and `int ip reset` change network configuration and are not undone by the script.
