# New-RestorePointSafe

**Category:** System Safety
**Scope:** System Restore Point management

## Synopsis

Create, list, restore, and cleanup System Restore Points with repository-aware naming and safety checks.

## Description

Safe wrapper around Windows System Restore functionality:

- **Create** — creates a restore point with optional custom description
- **List** — displays recent restore points (sequence, date, description)
- **Restore** — interactive restore to a selected point (initiates System Restore)
- **DeleteOld** — identifies restore points older than N days (manual cleanup recommended)

Always requires administrator privileges for create/restore operations.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Description` | String | Timestamped | Custom description for new restore point |
| `-NoRollback` | Switch | False | Skip printing rollback instructions after creation |
| `-Restore` | Switch | False | Initiate restore to most recent point (interactive) |
| `-List` | Switch | False | List recent restore points |
| `-DeleteOld` | Switch | False | Identify old restore points for manual cleanup |
| `-OlderThanDays` | Int | `30` | Age threshold for `-DeleteOld` |

## Usage

```powershell
# Create restore point with default description
.\New-RestorePointSafe.ps1

# Create with custom description
.\New-RestorePointSafe.ps1 -Description "Before GPU optimizations"

# List recent restore points
.\New-RestorePointSafe.ps1 -List

# Initiate restore (interactive selection)
.\New-RestorePointSafe.ps1 -Restore

# Cleanup old points (identifies; manual delete from System Properties)
.\New-RestorePointSafe.ps1 -DeleteOld -OlderThanDays 60
```

## Notes

- Execute from elevated PowerShell (Administrator).
- Actual script: `Scripts/New-RestorePointSafe.ps1`
- This `.md` is Kilo command reference.
- Restore points are system-wide; this complements (not replaces) git-based config rollback.

## Related

- `Scripts/Common.ps1` — `New-RestorePoint` helper
- `Debloat-Windows.ps1` — auto-creates restore point before debloating
- `Optimize-Gaming.ps1` — auto-creates restore point before tweaks
- `Backup-CurrentConfigs.ps1` — filesystem/registry snapshot (complementary)
