# Windows Dotfiles

[![Maintainability](https://qlty.sh/gh/Ven0m0/projects/.github/maintainability.svg)](https://qlty.sh/gh/Ven0m0/projects/.github)

- [Winget](https://winstall.app)
- [Scoop](https://scoop.sh)
```pwsh
iex "& {$(irm get.scoop.sh)} -RunAsAdmin"
```
- [Chocolatey](https://chocolatey.org)
- CCT (Chris Titus Tech): Use the `winutil` function defined in the PowerShell profile
```pwsh
iwr -useb https://christitus.com/win | iex
```

My Windows configuration files and scripts, managed with [yadm](https://yadm.io/).

## Features

- **PowerShell Profile**: Custom aliases, functions, and prompt
- **Windows Terminal Settings**: Modern terminal configuration
- **Optimization Scripts**: Collection of Windows optimization and gaming tweaks
- **Git Configuration**: Sensible git defaults and aliases
- **yadm Bootstrap**: Automated setup on new machines

## Fresh Windows 11 Install (One-Command)

For a clean Windows 11 system, use the complete setup script that installs all prerequisites, clones the repository, and runs bootstrap automatically:

```powershell
# Download and execute the setup script (runs as admin)
iwr https://raw.githubusercontent.com/Ven0m0/Win/main/.github/scripts/bootstrap.ps1 -UseBasicParsing | iex
```

The script will:
1. Install winget (if missing)
2. Install Git, PowerShell 7+, and yadm
3. Clone this repository via yadm
4. Run the full bootstrap to deploy configs
5. Optionally install WSL2 (recommended)

**Unattended mode**: Append `-Unattended` for zero prompts (e.g., for automated deployments):

```powershell
iwr https://raw.githubusercontent.com/Ven0m0/Win/main/.github/scripts/bootstrap.ps1 -UseBasicParsing | iex -Unattended
```

Alternatively, clone the repo manually first and run the local setup script:

```powershell
# Clone using yadm (installed from winget)
yadm clone https://github.com/Ven0m0/Win.git

# One-command local setup
pwsh $HOME\.yadm\bootstrap
```

## Quick Start

### Option 1: One-Command Setup (Fresh Windows 11)

The fastest way to set up on a fresh Windows 11 install:

```powershell
iwr https://raw.githubusercontent.com/Ven0m0/Win/main/.github/scripts/bootstrap.ps1 -UseBasicParsing | iex
```

This single command will automatically:
- Install [winget](https://winstall.app) (Windows Package Manager) if missing
- Install Git, PowerShell 7+, and yadm
- Clone this repository
- Run the full bootstrap
- Optionally set up WSL2

### Option 2: Manual Setup

If you prefer explicit control or the one-command script fails, install prerequisites manually:

1. **Install yadm** (the dotfile manager):

   ```powershell
   winget install yadm
   ```

   Or via Chocolatey:

   ```powershell
   choco install yadm
   ```

2. **Recommended tools** (bootstrap will install these if missing, but you can pre-install):

   ```powershell
   winget install Git.Git
   winget install Microsoft.PowerShell
   winget install Microsoft.WindowsTerminal
   winget install Microsoft.VisualStudioCode
   ```

The bootstrap script will:

- Set up PowerShell profile
- Configure Windows Terminal
- Check for required tools
- Create common directories
- Optionally add Scripts to PATH

### Manual Setup (if bootstrap doesn't run)

1. **PowerShell Profile**:

   ```powershell
   Copy-Item "$HOME\user\.dotfiles\config\powershell\profile.ps1" $PROFILE -Force
   ```

2. **Windows Terminal Settings**:

   ```powershell
   Copy-Item "$HOME\user\.dotfiles\config\windows-terminal\settings.json" "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" -Force
   ```

Bootstrap also attempts to apply Firefox `user.js`, Brave policy registry settings, CMD aliases, and tracked game configs when their destination folders already exist.

### Manual Setup (if bootstrap doesn't run)

If automatic bootstrap fails, configure manually:

1. **Enable script execution**:

   ```cmd
   cd %USERPROFILE%\Scripts
   allow-scripts.ps1
   ```

2. **PowerShell Profile**:

   ```powershell
   Copy-Item "$HOME\user\.dotfiles\config\powershell\profile.ps1" $PROFILE -Force
   ```

3. **Windows Terminal Settings**:

   ```powershell
   Copy-Item "$HOME\user\.dotfiles\config\windows-terminal\settings.json" "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" -Force
   ```

4. **Git Config**:

   ```powershell
   Copy-Item "$HOME\.gitconfig##template" "$HOME\.gitconfig"
   notepad $HOME\.gitconfig
   ```

## Repository Structure

```
.
├── Scripts/
│   ├── Setup-Win11.ps1           # Fresh Windows 11 one-command setup (local)
│   ├── Setup-Dotfiles.ps1        # Core bootstrap logic (called by yadm)
│   ├── Common.ps1                # Shared utility functions
│   ├── shell-setup.ps1           # Full toolchain install (Scoop, Choco, apps)
│   ├── allow-scripts.ps1         # Enable/disable PowerShell script execution
│   ├── debloat-windows.ps1       # System debloating suite
│   ├── system-settings-manager.ps1
│   ├── system-update.ps1
│   ├── system-maintenance.ps1
│   ├── fix-system.ps1
│   ├── additional-maintenance.ps1
│   ├── edid-manager.ps1          # Display EDID management
│   ├── gaming-display.ps1        # Fullscreen/MPO optimization
│   ├── gpu-display-manager.ps1   # GPU/display settings
│   ├── Network-Tweaker.ps1       # Network adapter optimization
│   ├── UltimateDiskCleanup.ps1   # Disk cleanup GUI
│   ├── shader-cache.ps1          # Shader cache cleanup
│   ├── steam.ps1                 # Steam optimization
│   ├── DLSS-force-latest.ps1     # DLSS configuration
│   ├── arc-raiders/              # Arc Raiders utilities
│   ├── Hostbuilder/
│   │   └── BuildHosts.ps1        # Hosts file builder
│   └── Common.Tests.ps1          # Pester tests
├── user/.dotfiles/config/
│   ├── powershell/profile.ps1    # PowerShell profile
│   ├── windows-terminal/settings.json
│   ├── firefox/user.js
│   ├── brave/brave_debloater.reg
│   ├── cmd/alias.cmd
│   ├── bleachbit/cleaners/
│   ├── games/(bf2, bo6, bo7)/   # Game-specific configs
│   ├── nvidia/                   # NVIDIA assets
│   ├── scoop/                    # Scoop bucket configs
│   └── winget-configs/
├── .yadm/
│   └── bootstrap                 # yadm entry point
├── .github/
│   ├── scripts/
│   │   └── bootstrap.ps1         # One-command internet bootstrap
│   ├── instructions/
│   │   ├── windows-11-setup.instructions.md
│   │   ├── powershell.instructions.md
│   │   └── ...
│   ├── skills/
│   │   ├── win-patterns/SKILL.md
│   │   └── ...
│   └── copilot-instructions.md
├── AGENTS.md                     # This file
├── .gitignore
└── README.md
```

## Available Scripts

All scripts are located in `~/Scripts/` and can be run directly:

### Setup & Bootstrap

- **`Setup-Win11.ps1`** — Complete fresh Windows 11 setup (one-command)
- **`Setup-Dotfiles.ps1`** — Core bootstrap (called by `yadm bootstrap`)
- **`shell-setup.ps1`** — Full toolchain install (Scoop, Chocolatey, apps)
- **`allow-scripts.ps1`** — Enable/disable PowerShell script execution policy

### System Optimization

- **`debloat-windows.ps1`** — System debloater (Apps, Services, Tasks, Features)
- **`system-settings-manager.ps1`** — Apply system performance optimizations
- **`system-update.ps1`** — Windows Update handler
- **`system-maintenance.ps1`** — Scheduled maintenance runner
- **`fix-system.ps1`** — System repair and recovery utilities
- **`additional-maintenance.ps1`** — Extra maintenance routines

### Gaming Utilities

- **`steam.ps1`** — Optimize Steam for minimal RAM/CPU usage
- **`shader-cache.ps1`** — Clear Steam/game/GPU shader caches
- **`DLSS-force-latest.ps1`** — Force latest DLSS version
- **`edid-manager.ps1`** — Apply/remove EDID overrides for display issues
- **`gaming-display.ps1`** — Configure fullscreen mode and multiplane overlay
- **`gpu-display-manager.ps1`** — GPU and display settings

### Maintenance & Cleanup

- **`UltimateDiskCleanup.ps1`** — Comprehensive disk cleanup tool (GUI)
- **`Clean-SpotifyCache.ps1`** — Clear Spotify cache

### Networking

- **`Network-Tweaker.ps1`** — Advanced network adapter configuration GUI
- **`Hostbuilder/BuildHosts.ps1`** — Build custom hosts file with ad/malware blocking

### Other

- **`PowerShell-Context-Menus.reg`** — Adds PowerShell to context menus
- **`Common.ps1`** — Shared utility functions (imported by many scripts)

## yadm Usage

### Basic Commands

```powershell
# Check status
yadm status

# Add a new dotfile
yadm add <file>

# Commit changes
yadm commit -m "Update configuration"

# Push to remote
yadm push

# Pull from remote
yadm pull

# Show differences
yadm diff
```

### Adding New Dotfiles

To track a new configuration file:

```powershell
# Add the file to yadm
yadm add $HOME\.my-new-config

# Commit
yadm commit -m "Add my new config"

# Push
yadm push
```

### Updating on Another Machine

```powershell
# Pull latest changes
yadm pull

# Re-run bootstrap if needed
pwsh $HOME\.yadm\bootstrap
```

### Templates

yadm supports templates with the `##template` suffix. These files can contain variables that are replaced based on the system.

Example: `.gitconfig##template` should be copied to `.gitconfig` and customized.

## PowerShell Profile Features

The PowerShell profile (`~/.config/powershell/profile.ps1`) includes:

### Aliases

- **Navigation**: `~` (go home)
- **Git**: `gs`, `ga`, `gc`, `gp`, `gl`, `gd`
- **yadm**: `ys`, `ya`, `yc`, `yp`, `yl`
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
- `Clear-TempFiles` - Clean temporary files

### PSReadLine Configuration

- History search with arrow keys
- Tab completion with menu
- Predictive IntelliSense (PowerShell 7+)
- Syntax highlighting

## Customization

### Local Customizations

Create `~/.config/powershell/local.ps1` for machine-specific configuration that won't be tracked by yadm:

```powershell
# ~/.config/powershell/local.ps1
# This file is ignored by yadm

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

Run `Scripts\allow-scripts.cmd` as administrator to enable script execution.

### Bootstrap Script Doesn't Run

Manually run:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
pwsh $HOME\.yadm\bootstrap
```

### Windows Terminal Settings Not Applied

Manually copy:

```powershell
Copy-Item "$HOME\user\.dotfiles\config\windows-terminal\settings.json" "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" -Force
```

### Automated Windows 11 Installation (autounattend.xml)

The `Scripts/auto/autounattend.xml` file enables fully automated Windows 11 installation.

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

### yadm Commands Not Working

Make sure yadm is in your PATH:

```powershell
where.exe yadm
```

If not found, reinstall yadm or add it to PATH manually.

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
