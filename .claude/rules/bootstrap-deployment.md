# Bootstrap Deployment Rules

Applies to bootstrap and deployment scripts: `**/Setup-Win11.ps1`, `**/bootstrap.ps1`, `**/Setup-Dotfiles.ps1`.

## Bootstrap Layers

1. **Internet bootstrap** (`bootstrap.ps1`) — one-command entry; self-elevates, installs prereqs (winget, Git, pwsh, Python, dotbot), clones repo
2. **Repo bootstrap** (`install.conf.yaml` + `Scripts/Setup-Dotfiles.ps1`) — installs winget packages, deploys configs via SHA256 hash, configures PATH, creates directories
3. **Unattended USB** (`Scripts/auto/autounattend.xml`) — fully self-contained; no companion flat files

## Unattended USB Install

`Scripts/auto/autounattend.xml` provides a fully unattended Windows 11 install from USB:

1. Copy `autounattend.xml` to the **root of the USB drive** — that is the only file required
2. Boot from the USB; Windows Setup detects the file and runs fully unattended
3. All setup scripts are **embedded inside the XML** via the `ExtractScript` mechanism

**Do not** add flat `.ps1` or `.cmd` files alongside the XML in `Scripts/auto/`; they become stale duplicates.

**Validate the XML** after any edit:
```powershell
$xml = [xml]::new(); $xml.Load('Scripts/auto/autounattend.xml')
```

## Repository Conventions

- **Bootstrap entry points**: `install.conf.yaml` and `bootstrap.ps1`
- **Main setup logic**: `Scripts/Setup-Dotfiles.ps1`
- **Shared utilities**: `Scripts/Common.ps1`
- **Config deployment**: Manifest-driven with SHA256 hash-based change detection
- **Tool installation**: Uses `winget` with `--silent --accept-*` flags
- **Tracked config root**: `user/.dotfiles/config/`

