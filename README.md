# Windows Dotfiles

[![Maintainability](https://qlty.sh/gh/Ven0m0/projects/.github/maintainability.svg)](https://qlty.sh/gh/Ven0m0/projects/.github)

> My Windows configuration files and scripts, managed with [dotbot](https://github.com/anishathalye/dotbot) and git.

## Package Managers

The following package managers are recommended for Windows:

- [Winget](https://winstall.app) — Windows Package Manager (built-in)
- [Scoop](https://scoop.sh) — Command-line installer
  ```pwsh
  iex "& {$(irm get.scoop.sh)} -RunAsAdmin"
  ```
- [Chocolatey](https://chocolatey.org) — Package manager for Windows
- **CCT (Chris Titus Tech)**: Use the `winutil` function defined in the PowerShell profile
  ```pwsh
  irm -useb "https://christitus.com/windev" | iex
  ```
  or in powershell 7:
  ```pwsh
  & ([scriptblock]::Create((irm https://christitus.com/windev)))
  ```

## Features

- **PowerShell Profile**: Custom aliases, functions, and prompt
- **Windows Terminal Settings**: Modern terminal configuration
- **Optimization Scripts**: Collection of Windows optimization and gaming tweaks
- **Git Configuration**: Sensible git defaults and aliases
- **Dotbot Bootstrap**: Automated setup on new machines

## Fresh Windows 11 Install (One-Command)

On a completely clean Windows 11 machine with nothing installed, run:

```pwsh
iwr -useb "https://raw.githubusercontent.com/Ven0m0/Win/main/bootstrap.ps1" | iex
```

This single command chains the whole setup:
1. Install winget, Git, Python, [mise](https://mise.jdx.dev), and [uv](https://docs.astral.sh/uv) (if missing)
2. Shallow-clone this repository into `$env:USERPROFILE\project\Win`
3. Invoke `Scripts/Setup-Win11.ps1`, which runs:
   - **Debloat Windows** — removes ~40 bloat appx packages via `packages.psd1`
   - **Install all software** — winget (core, runtimes, toolchains, dev tools, CLI tools, apps), Scoop, Bun/npm globals, Cargo, PowerShell modules — see `packages.psd1`
   - **Deploy all configs** — every tracked config to its correct path via mise-managed dotbot (`mise install` + `mise run bootstrap`)
   - Optionally install WSL2

`Setup-Win11.ps1` no longer clones the repository itself — it operates on wherever it's located (`bootstrap.ps1`'s clone, or a manual checkout) and assumes prerequisites are already installed.

**Unattended mode** (zero prompts) — piping into `iex` can't forward parameters, so use `ScriptBlock.Create` instead:

```pwsh
&([ScriptBlock]::Create((irm "https://raw.githubusercontent.com/Ven0m0/Win/main/bootstrap.ps1"))) -Unattended
```

**Skip phases** as needed — these flags are exposed on both `bootstrap.ps1` and `Setup-Win11.ps1` and forward through the chain:

| Flag | Effect |
|---|---|
| `-SkipDebloat` | Don't remove bloatware |
| `-SkipPackages` | Don't run the full software install |
| `-SkipWingetTools` | Skip installing tools via winget (use existing installations) |
| `-SkipWSL` | Don't install WSL2 |
| `-Force` | Re-run setup even if already configured |

If you already have the repo cloned and just want the full local setup without re-cloning:

```pwsh
pwsh -File "$env:USERPROFILE\project\Win\Scripts\Setup-Win11.ps1"
```

Alternatively, deploy configs only (no software install, no debloat):

```pwsh
# Clone using git
git clone --depth 1 https://github.com/Ven0m0/Win.git
# Deploy configs only
mise run deploy
```

## Quick Start

### Option 1: One-Command Setup (Fresh Windows 11)

The fastest way to set up on a fresh Windows 11 install:

```pwsh
iwr https://raw.githubusercontent.com/Ven0m0/Win/main/bootstrap.ps1 -UseBasicParsing | iex
```
This single command will automatically:
- Install [winget](https://winstall.app) (Windows Package Manager) if missing
- Install Git, Python, [mise](https://mise.jdx.dev), and [uv](https://docs.astral.sh/uv)
- Shallow-clone this repository into `$env:USERPROFILE\project\Win`
- Chain into `Scripts/Setup-Win11.ps1` for the full setup (debloat, software catalog, mise-managed dotbot config deploy)
- Optionally set up WSL2

### Option 2: Manual Setup
If you prefer explicit control or the one-command script fails, install prerequisites manually:

1. **Install mise** (manages dotbot, Python, and other tools declared in `mise.toml`):
   ```pwsh
   winget install jdx.mise
   ```
   Then from the repo root, install everything `mise.toml` declares (including dotbot via pipx):
   ```pwsh
   mise install
   ```
   Or install dotbot directly, without mise:
   ```pwsh
   pip install dotbot
   ```

2. **Recommended tools** (bootstrap will install these if missing, but you can pre-install):
   ```pwsh
   winget install -h Git.Git Microsoft.PowerShell Microsoft.WindowsTerminal astral-sh.uv
   ```

The bootstrap script will:

- Set up PowerShell profile
- Configure Windows Terminal
- Check for required tools
- Create common directories
- Optionally add Scripts to PATH

### Manual Setup (if bootstrap doesn't run)

1. **PowerShell Profile**:
   ```pwsh
   Copy-Item "$HOME\user\.dotfiles\config\powershell\Microsoft.PowerShell_profile.ps1" $PROFILE -Force
   ```

2. **Windows Terminal Settings**:
   ```pwsh
   Copy-Item "$HOME\user\.dotfiles\config\windows-terminal\settings.json" "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" -Force
   ```

Bootstrap also attempts to apply Firefox `user.js`, Brave policy registry settings, CMD aliases, and tracked game configs when their destination folders already exist.

If automatic bootstrap fails, configure manually:

1. **Enable script execution**:
   ```pwsh
   pwsh -nop -nol "$HOME\Scripts\allow-scripts.ps1"
   ```

2. **PowerShell Profile**:
   ```pwsh
   Copy-Item "$HOME\user\.dotfiles\config\powershell\Microsoft.PowerShell_profile.ps1" $PROFILE -Force
   ```

3. **Windows Terminal Settings**:
   ```pwsh
   Copy-Item "$HOME\user\.dotfiles\config\windows-terminal\settings.json" "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" -Force
   ```

4. **Git Config**:
   ```pwsh
   Copy-Item "$HOME\.gitconfig##template" "$HOME\.gitconfig"
   notepad $HOME\.gitconfig
   ```

## Power Setup Workflow

Apply the gaming-oriented power/performance profile after the base setup is deployed:

```pwsh
# Launch the settings manager (self-elevates)
pwsh -File "$env:USERPROFILE\project\Win\Scripts\system-settings-manager.ps1"
```

Select **Performance Optimizations** from the main menu, then **Apply**. This:

- Disables hibernate, fast boot, and the sleep/lock Start-menu options
- Disables power throttling (`PowerThrottlingOff`)
- Enables USB overclock compatibility (`WHQLSettings`)
- Disables raw mouse input throttling
- Unbinds the `ms_server` component from network adapters

Run **Restore Defaults** from the same menu to revert every value the apply step touched.

To also stop USB peripherals from suspending mid-session:

```pwsh
pwsh -File "$env:USERPROFILE\project\Win\Scripts\DisableUSBPowerManagement.ps1"
```

Both scripts require administrator elevation and only touch `HKLM` power-related keys — see [`.claude/rules/registry-security.md`](.claude/rules/registry-security.md) for the restore-point and rollback conventions they follow.

## Repository Structure

```text
.
├── Scripts/
│   ├── Setup-Win11.ps1           # Fresh Windows 11 one-command setup (local)
│   ├── Setup-Dotfiles.ps1        # Core bootstrap logic (called by dotbot)
│   ├── Common.ps1                # Shared utility functions
│   ├── shell-setup.ps1           # Full toolchain install (Scoop, Choco, apps)
│   ├── allow-scripts.ps1         # Enable/disable PowerShell script execution
│   ├── debloat-windows.ps1       # System debloating suite
│   ├── system-settings-manager.ps1
│   ├── system-update.ps1
│   ├── system-maintenance.ps1    # Maintenance hub (-Action Defrag|Disk|Shader|Extra|All)
│   ├── fix-system.ps1            # Repair hub (-Action System|WindowsUpdate|All)
│   ├── Network-Tweaker.ps1       # Network adapter optimization
│   ├── Optimize-Steam.ps1        # Steam optimization
│   ├── DLSS-force-latest.ps1     # DLSS configuration
│   ├── arc-raiders/              # Arc Raiders utilities
│   ├── Hostbuilder/
│   │   └── BuildHosts.ps1        # Hosts file builder
│   └── Common.Tests.ps1          # Pester tests
├── user/.dotfiles/config/
│   ├── powershell/Microsoft.PowerShell_profile.ps1    # PowerShell profile
│   ├── windows-terminal/settings.json
│   ├── browser/firefox/user.js
│   ├── cmd/alias.cmd
│   ├── bleachbit/cleaners/
│   ├── games/(arc-raiders, bf2, bo6, fortnite, minecraft)/
│   ├── nvidia/                   # NVIDIA assets
│   ├── obs/                      # OBS Studio profiles, scenes, plugin_config
│   ├── scoop/                    # Scoop bucket configs
│   └── winget-configs/
├── install.conf.yaml             # dotbot configuration entry point
├── bootstrap.ps1                 # One-command internet bootstrap
├── .github/
│   ├── instructions/
│   │   ├── windows-11-setup.instructions.md
│   │   ├── powershell.instructions.md
│   │   └── ...
│   ├── skills/
│   │   ├── win-patterns/SKILL.md
│   │   └── ...
│   └── copilot-instructions.md
├── AGENTS.md                     # AI assistant guide
├── CLAUDE.md                     # Symlink to AGENTS.md
├── .gitignore
└── README.md                    # This file
```

## Available Scripts

All scripts are located in `~/Scripts/` and can be run directly:

### Setup & Bootstrap

- **`Setup-Win11.ps1`** — Full fresh Windows 11 setup: debloat → install all software → deploy all configs. Chained from `bootstrap.ps1`; does not clone the repo itself, operates on wherever it's located
- **`Install-Packages.ps1`** — Install the full software catalog from `packages.psd1` (can run standalone)
- **`packages.psd1`** — Canonical package catalog (winget/scoop/choco/modules/features/appx-remove lists)
- **`Setup-Dotfiles.ps1`** — Deploy tracked configs (called by dotbot / `mise run deploy`)
- **`debloat-windows.ps1`** — Remove bloatware using `packages.psd1` `AppxToRemove` list
- **`shell-setup.ps1`** — Legacy full toolchain install (superseded by `Install-Packages.ps1` + `packages.psd1`)
- **`allow-scripts.ps1`** — Enable/disable PowerShell script execution policy

### System Optimization

- **`debloat-windows.ps1`** — System debloater (Apps, Services, Tasks, Features)
- **`system-settings-manager.ps1`** — Apply system performance optimizations
- **`system-update.ps1`** — Windows Update handler
- **`system-maintenance.ps1`** — Maintenance hub: `-Action Defrag|Disk|Shader|Extra|All` (defrag/MSI, disk cleanup GUI, shader cache, DISM/cache rebuilds)
- **`fix-system.ps1`** — Repair hub: `-Action System|WindowsUpdate|All` (DISM/SFC/CHKDSK/network/WMI + Windows Update reset)

### Gaming Utilities

- **`Optimize-Steam.ps1`** — Optimize Steam for minimal RAM/CPU usage
- **`system-maintenance.ps1 -Action Shader`** — Clear Steam/game/GPU shader caches
- **`DLSS-force-latest.ps1`** — Force latest DLSS version

### Power & Performance

- **`system-settings-manager.ps1`** → *Performance Optimizations* menu — applies the gaming power/performance profile (disables hibernate, fast boot, power throttling, sleep/lock options; enables USB overclock compatibility and raw mouse input); same menu offers a *Restore Defaults* option that reverts every value it touched
- **`DisableUSBPowerManagement.ps1`** — Disables USB selective suspend across all USB hubs/controllers/HID devices so peripherals don't power down mid-session

### Maintenance & Cleanup

- **`system-maintenance.ps1 -Action Disk`** — Comprehensive disk cleanup tool (GUI)

### Networking

- **`Network-Tweaker.ps1`** — Advanced network adapter configuration GUI
- **`Hostbuilder/BuildHosts.ps1`** — Build custom hosts file with ad/malware blocking

### Other

- **`PowerShell-Context-Menus.reg`** — Adds PowerShell to context menus
- **`Common.ps1`** — Shared utility functions (imported by many scripts)

## Dotbot Usage

### Basic Commands

```pwsh
# Deploy dotfiles
mise run deploy
# or
dotbot -c install.conf.yaml

# Full bootstrap (install dotbot + deploy)
mise run bootstrap

# Check git status
git status --long

# Commit changes
git commit -m "Update configuration"

# Push to remote
git push
```

### Adding New Dotfiles

To track a new configuration file:

```pwsh
# Add the file to git
git add $HOME\.my-new-config

# Commit
git commit -m "Add my new config"

# Push
git push
```

### Updating on Another Machine

```pwsh
# Pull latest changes
git pull

# Re-run bootstrap if needed
mise run deploy
# or
dotbot -c install.conf.yaml
```

### Templates

Dotbot configuration supports templates in [`install.conf.yaml`](install.conf.yaml). Configuration files can specify conditions and variable substitution.

Example: `.gitconfig##template` should be copied to `.gitconfig` and customized.

## PowerShell Profile Features

The PowerShell profile (`~/.config/powershell/Microsoft.PowerShell_profile.ps1`) includes:

### Aliases

- **Navigation**: `~` (go home)
- **Git**: `gs`, `ga`, `gc`, `gp`, `gl`, `gd`
- **Docker**: `d`, `dc`, `dps`, `dimg` (if docker installed)
- **Unix-like**: `which`, `grep`, `df`, `du`, `touch`, `myip`

### Functions

- `Get-DiskUsage` / `df` - Show disk usage
- `Get-FileSize` / `du` - Calculate directory size
- `Update-Profile` - Reload profile
- `Edit-Profile` - Edit profile in default editor
- `Get-PublicIP` / `myip` - Get public IP address
- `touch <file>` - Create/update file
- `mkcd <dir>` - Create directory and cd into it
- `Clear-TempFile` - Clean temporary files

### PSReadLine Configuration

- History search with arrow keys
- Tab completion with menu
- Predictive IntelliSense (PowerShell 7+)
- Syntax highlighting

## Customization

### Local Customizations

Create `~/.config/powershell/local.ps1` for machine-specific configuration that won't be tracked by git:

```pwsh
# ~/.config/powershell/local.ps1
# This file is ignored by git

# Machine-specific aliases
Set-Alias -Name myapp -Value "C:\path\to\app.exe"

# Machine-specific environment variables
$env:MY_VAR = "value"
```

Similarly, for git: `~/.gitconfig.local` (already included in `.gitconfig##template`).

## Useful Resources

### Windows Customization

- [ExplorerPatcher](https://github.com/valinet/ExplorerPatcher) - Enhance Windows 11 taskbar and explorer

### ISO Building

- [Unattend Generator](https://schneegans.de/windows/unattend-generator) - Create unattended Windows installation configs
- [UUP dump](https://uupdump.net) - Download Windows updates and builds
- [Tiny11 Builder](https://github.com/ntdevlabs/tiny11builder) - Create lightweight Windows 11 images

### NVIDIA Tools

- [NVIDIA Profile Inspector (Unlocked)](https://github.com/Ixeoz/nvidiaProfileInspector-UNLOCKED) - Advanced NVIDIA settings
- [NVIDIA Profile Inspector](https://github.com/Orbmu2k/nvidiaProfileInspector) - Original version

## Troubleshooting

### PowerShell Scripts Won't Run

Run `Scripts\allow-scripts.ps1` as administrator to enable script execution.

### Bootstrap Script Doesn't Run

Manually run:

```pwsh
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
mise run bootstrap
# or
dotbot -c install.conf.yaml
```

### Windows Terminal Settings Not Applied

Manually copy:

```pwsh
Copy-Item "$HOME\user\.dotfiles\config\windows-terminal\settings.json" "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" -Force
```

### Automated Windows 11 Installation (autounattend.xml)

The [`Scripts/auto/autounattend.xml`](Scripts/auto/autounattend.xml) file enables fully automated Windows 11 installation.

#### Prerequisites

- **Windows 11 ISO** - Download from [UUP dump](https://uupdump.net) or Microsoft
- **8GB+ USB drive** - For installation media
- **Internet connection** - Required for winget app installations
- **Disable BitLocker** - Before installation, disable BitLocker in Windows or BIOS
- **Disable Secure Boot** - Some systems require disabling in BIOS/UEFI
- **Backup data** - Installation will format the target disk

#### Usage

1. Copy `Scripts/auto/autounattend.xml` to the root of your Windows 11 installation USB
2. Boot from the USB and follow the prompts
3. Installation proceeds automatically (~45-60 minutes)
4. System will restart and install apps automatically

#### Installation Flow

1. Windows PE loads → bypasses TPM/SecureBoot/RAM checks
2. Disk is partitioned (GPT: EFI 550MB, Windows, Recovery 1000MB)
3. Windows image is applied
4. System specialized with bloatware removal and registry tweaks
5. User "Ven0m0" created with auto-logon
6. First login → runs install.ps1 (100+ apps via winget)
7. Final reboot → stage2.ps1 installs WSL2

#### Troubleshooting

- **Installation hangs at disk partitioning**: Ensure disk 0 is available and not in use
- **winget packages fail to install**: Check internet connectivity, packages may be retried automatically
- **No internet after install**: Run `C:\Windows\Setup\Scripts\install.ps1` manually
- **WSL2 install fails**: Run `wsl --install -d Ubuntu --web-download` manually

#### Log Files

Check these locations for debugging:

- `C:\Windows\Setup\Scripts\install.log` - App installation logs
- `C:\Windows\Setup\Scripts\stage2.log` - WSL installation logs
- `C:\Windows\Setup\Scripts\Specialize.log` - System customization logs

### Dotbot Commands Not Working

Make sure dotbot is installed:

```pwsh
where.exe dotbot
```

If not found, run `mise install` from the repo root (installs dotbot via pipx per `mise.toml`), or fall back to `pip install dotbot`.

## Contributing

Feel free to fork and customize for your own use!

## Credits

This repository builds upon work from:

- [zScripts](https://github.com/zoicware/zScripts) - Windows optimization scripts
- [AveYo](https://github.com/AveYo) - Various Windows tools and scripts
- [FR33THYFR33THY](https://github.com/FR33THYFR33THY) - Gaming optimizations

## License

This repository is provided as-is for personal use.

---

**Note**: Always review scripts before running them, especially those that modify system settings or registry values.
