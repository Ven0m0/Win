# Backup-CurrentConfigs

**Category:** Safety / Snapshot
**Scope:** Pre-change system backup

## Synopsis

Create snapshots of current system state: registry exports, installed package lists, service states, and PowerShell profile. Compressible into ZIP archive.

## Description

Use before making significant changes (debloat, registry tweaks, etc.) to capture a rollback baseline. Captures:

- **Registry** — exports key areas (HKCU\Software, HKLM policies, GameConfig, ContentDeliveryManager, etc.) to `.reg` files
- **Packages** — winget list, Appx packages (all users), provisioned Appx to JSON
- **Services** — service name, display name, status, start type, service type to CSV
- **PowerShell profile** — copies current `$PROFILE` for snapshot

Output organized into timestamped directory (`./backups/YYYY-MM-DD_HHmm`) and optionally compressed to ZIP.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-ExportRegistry` | Switch | False | Export registry keys only |
| `-ListPackages` | Switch | False | Save package lists only |
| `-ListServices` | Switch | False | Capture service states only |
| `-All` | Switch | False | Perform all backup operations (default if no switches) |
| `-OutputDir` | String | Timestamped `./backups/` | Custom output directory |
| `-Compress` | Switch | False | Bundle all backups into ZIP archive |
| `-KeepLocal` | Switch | False | Keep uncompressed files alongside ZIP |

## Usage

```powershell
# Full backup (all categories) to timestamped directory
.\Backup-CurrentConfigs.ps1 -All

# Registry export only
.\Backup-CurrentConfigs.ps1 -ExportRegistry

# Packages and services only
.\Backup-CurrentConfigs.ps1 -ListPackages -ListServices

# Custom output location + compression
.\Backup-CurrentConfigs.ps1 -All -OutputDir C:\Backups\PreChange -Compress

# Create ZIP and delete temporary files
.\Backup-CurrentConfigs.ps1 -Compress
```

## Output Structure

```
backups/
└── 2024-01-15_1430/
    ├── registry/
    │   ├── HKCU_Software.reg
    │   ├── HKLM_SOFTWARE_Microsoft_Windows_CurrentVersion_Policies.reg
    │   ├── HKCU_System_GameConfig.reg
    │   └── ...
    ├── packages/
    │   ├── winget-list.json
    │   ├── appx-packages.json
    │   └── appx-provisioned.json
    ├── services/
    │   └── services.csv
    └── profile.ps1
```

## Notes

- Real script: `Scripts/Backup-CurrentConfigs.ps1`
- This `.md` is Kilo command reference.
- Does NOT create System Restore Point — use `New-RestorePointSafe.ps1` separately.
- Compressed backups: `.zip` with all files, temporary dir optionally removed.

## Related

- `New-RestorePointSafe.ps1` — System Restore Point (complementary)
- `Debloat-Windows.ps1` — generates rollback report internally
- `Validate-Changes.ps1` — verify after changes
