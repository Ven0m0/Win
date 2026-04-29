# Debloat-Windows

**Category:** System Debloat
**Scope:** Remove bloatware, disable services/tasks/features

## Synopsis

Safe Windows debloat wrapper with presets and selective modes. Calls `Scripts/debloat-windows.ps1` with undo support, reporting, and restore point protection.

## Description

Deblocks Windows by removing built-in Appx packages, disabling unnecessary services, turning off scheduled tasks, and removing optional Windows features. Supports:

- **Presets** — `Minimal` (keep essentials), `Moderate` (remove most bloat), `Aggressive` (also disable optional services)
- **Selective modes** — `-AppsOnly`, `-ServicesOnly`, `-TasksOnly`, `-FeaturesOnly`
- **Undo** — attempt to reverse debloat operations (best-effort; not always perfect)
- **Reporting** — JSON report of all changes (`-GenerateReport`)
- **Restore point** — auto-created before changes (unless `-NoRestorePoint`)

Requires administrator privileges.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Preset` | String | `'Moderate'` | Debloat intensity: Minimal, Moderate, Aggressive |
| `-AppsOnly` | Switch | False | Remove only Appx packages |
| `-ServicesOnly` | Switch | False | Disable only services |
| `-TasksOnly` | Switch | False | Disable only scheduled tasks |
| `-FeaturesOnly` | Switch | False | Remove only Windows features |
| `-NoRestorePoint` | Switch | False | Skip restore point creation |
| `-Undo` | Switch | False | Reverse debloat operations |
| `-GenerateReport` | Switch | False | Export JSON change report |
| `-ReportPath` | String | `./debloat-report.json` | Report output path |

## Usage

```powershell
# Moderate debloat (default)
.\Debloat-Windows.ps1

# Minimal bloat removal
.\Debloat-Windows.ps1 -Preset Minimal

# Aggressive debloat
.\Debloat-Windows.ps1 -Preset Aggressive

# Only remove apps, dry-run preview
.\Debloat-Windows.ps1 -AppsOnly -WhatIf

# Only disable services
.\Debloat-Windows.ps1 -ServicesOnly

# Undo previous debloat
.\Debloat-Windows.ps1 -Undo

# Generate detailed report
.\Debloat-Windows.ps1 -GenerateReport -ReportPath C:\Reports\debloat.json
```

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Failure (check error output) |

## Notes

- Real script: `Scripts/Debloat-Windows.ps1`
- This `.md` is Kilo command documentation only.
- Undo mode is best-effort; some changes may require manual reinstall of apps/features.
- Restoration of services/tasks uses original states recorded in the report (if generated).

## Related

- `Scripts/debloat-windows.ps1` — implementation
- `New-RestorePointSafe.ps1` — restore point management
- `Backup-CurrentConfigs.ps1` — pre-change backup
- `AGENTS.md` — repository-wide debloat guidance
