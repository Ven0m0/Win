# Sync-Configs

**Category:** Git / Deployment
**Scope:** Pull and deploy dotfile updates

## Synopsis

Pull latest changes from the dotfiles repository and optionally re-deploy configuration updates.

## Description

Workflow:

1. **Git pull** — fetches and pulls from remote (`origin` by default)
2. **Change detection** — checks if `user/.dotfiles/config/` has modifications
3. **Deploy** — runs dotbot full deployment or targeted groups

Useful for keeping dotfiles synchronized across machines or after pulling updates from another computer.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-PullOnly` | Switch | False | Only git pull, skip deployment |
| `-DeployAfterPull` | Switch | False | Pull then run full deployment (default if `-Target` not used) |
| `-Target` | String[] | Empty | Deploy only specific config groups after pull |
| `-Force` | Switch | False | Force redeploy even if no config changes detected |
| `-Branch` | String | Current branch | Specify branch to pull |
| `-Repository` | String | `'origin'` | Remote repository name/URL |
| `-DryRun` | Switch | False | Show actions without executing |

## Usage

```powershell
# Pull latest and redeploy all
.\Sync-Configs.ps1

# Only pull, do not redeploy
.\Sync-Configs.ps1 -PullOnly

# Pull then deploy only PowerShell profile
.\Sync-Configs.ps1 -Target 'PowerShell profile'

# Force redeploy even if no changes detected
.\Sync-Configs.ps1 -Force

# Pull from specific branch
.\Sync-Configs.ps1 -Branch feature/new-configs

# Dry-run (no actual changes)
.\Sync-Configs.ps1 -DryRun
```

## Behavior Notes

- If `-Target` is provided, deployment uses `Scripts/Setup-Dotfiles.ps1 -Target <...>`
- Without `-Target`, full dotbot runs: `dotbot -c install.conf.yaml`
- When neither `-PullOnly` nor `-DeployAfterPull` nor `-Target` is set, defaults to `-DeployAfterPull`
- `-Force` overrides change detection, forcing deployment

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Git operation failed |

## Notes

- Real script: `Scripts/Sync-Configs.ps1`
- This `.md` is Kilo command reference.
- Repository root is auto-detected from script location or current directory.

## Related

- `Deploy-Configs.ps1` — deploy without pulling
- `Scripts/Setup-Dotfiles.ps1` — deployment engine
- `install.conf.yaml` — dotbot manifest
