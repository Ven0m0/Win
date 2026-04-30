# Migrate-Config

**Category:** Maintenance / Migration
**Scope:** Configuration migration from old formats or tools

## Synopsis

Migrate tracked dotfile settings from legacy formats, tools, or directory structures into the current repository layout under `user/.dotfiles/config/`.

## Description

This workflow command guides safe migration of configuration files:

1. **Identify old config** — Locate legacy config files, registry exports, or settings from previous tools (e.g., old dotbot layouts, manual `.reg` files, app-specific backups)
2. **Map to new structure** — Match each old file to the target path under `user/.dotfiles/config/` following the current directory conventions
3. **Validate paths** — Ensure deployment targets (e.g., `$PROFILE`, Windows Terminal settings path, Firefox profile) exist and are writable
4. **Test deployment** — Run `dotbot -c install.conf.yaml` or `Scripts/Setup-Dotfiles.ps1` with `-WhatIf` to preview changes before applying
5. **Update manifest** — If `Scripts/Setup-Dotfiles.ps1` maintains a deployment manifest, add the new config entries and hash-check logic

## Steps

```powershell
# 1. Identify old config files
Get-ChildItem -Path $HOME\.old-dotfiles -Recurse -File

# 2. Read current deployment manifest
read Scripts/Setup-Dotfiles.ps1

# 3. Map and edit config entries
# edit <manifest> to add new config mapping

# 4. Validate target paths
Test-Path $PROFILE
Test-Path "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

# 5. Preview deployment
dotbot -c install.conf.yaml --only link -n
# or
pwsh -File Scripts/Setup-Dotfiles.ps1 -WhatIf
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Source` | String | — | Path to old config directory or file |
| `-Target` | String | — | Destination under `user/.dotfiles/config/` |
| `-WhatIf` | Switch | False | Preview changes without applying |
| `-SkipWingetTools` | Switch | False | Skip tool installation during test deployment |

## Usage

```powershell
# Migrate an old PowerShell profile
.\Migrate-Config.ps1 -Source $HOME\.old-dotfiles\profile.ps1 -Target user/.dotfiles/config/powershell/profile.ps1

# Migrate a directory of registry files
.\Migrate-Config.ps1 -Source $HOME\.old-dotfiles\registry\ -Target user/.dotfiles/config/registry/

# Preview only
.\Migrate-Config.ps1 -Source ./legacy/ -Target user/.dotfiles/config/ -WhatIf
```

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Migration completed successfully |
| `1` | Mapping or validation failure |
| `2` | Deployment test failed |

## Notes

- This markdown file is Kilo command reference only. Implement as `Scripts/Migrate-Config.ps1` if needed.
- Always preserve native file formats; do not re-serialize JSON, YAML, or REG files during migration.
- Use SHA256 hash-based deployment logic from `Scripts/Setup-Dotfiles.ps1`.
- Expected output is a migration summary listing source files, target paths, and deployment status.

## Related

- `Scripts/Setup-Dotfiles.ps1` — deployment logic and manifest
- `install.conf.yaml` — dotbot configuration
- `Deploy-Configs.md` — config deployment workflow
- `Sync-Configs.md` — bidirectional sync workflow
