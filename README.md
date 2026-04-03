# Windows Dotfiles

[![Maintainability](https://qlty.sh/gh/Ven0m0/projects/.github/maintainability.svg)](https://qlty.sh/gh/Ven0m0/projects/.github)

- [Winget](https://winstall.app)
- [Scoop](https://scoop.sh) `iex "& {$(irm get.scoop.sh)} -RunAsAdmin"`
- [Chocolatey](https://chocolatey.org)
- CCT: `iwr -useb https://christitus.com/win | iex`

My Windows configuration files and scripts, managed with [yadm](https://yadm.io/).

## Features

- **PowerShell Profile**: Custom aliases, functions, and prompt
- **Windows Terminal Settings**: Terminal configuration
- **Optimization Scripts**: Windows optimization and gaming tweaks
- **Git Configuration**: Git defaults and aliases
- **yadm Bootstrap**: Automated setup on new machines

## Quick Start

### Prerequisites

1. Install [yadm](https://yadm.io/):

   ```powershell
   winget install yadm
   ```

   Or via Chocolatey:

   ```powershell
   choco install yadm
   ```

2. Optional but recommended:
   ```powershell
   winget install Git.Git
   winget install Microsoft.PowerShell
   winget install Microsoft.WindowsTerminal
   winget install Microsoft.VisualStudioCode
   ```

### Installation

Clone this repository using yadm:

```powershell
# Clone the dotfiles
yadm clone https://github.com/Ven0m0/Win.git

# Run the bootstrap script (optional but recommended)
pwsh $HOME\.yadm\bootstrap
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

3. **Enable Script Execution**:
   ```cmd
   cd %USERPROFILE%\Scripts
   allow-scripts.cmd
   ```

## Repository Structure

```
.
├── .yadm/
│   └── bootstrap                      # Post-clone setup script
├── Scripts/
│   ├── Common.ps1                     # Shared utility functions
│   ├── gpu-display-manager.ps1        # GPU/display settings (P-State, HDCP, MSI Mode, EDID)
│   ├── gaming-display.ps1             # FSO/MPO display tweaks
│   ├── edid-manager.ps1               # EDID override management
│   ├── debloat-windows.ps1            # System debloater
│   ├── steam.ps1                      # Steam optimization
│   ├── shader-cache.ps1               # Shader cache cleanup
│   ├── DLSS-force-latest.ps1          # DLSS configuration
│   ├── Network-Tweaker.ps1            # Network adapter optimization
│   ├── UltimateDiskCleanup.ps1        # Disk cleanup GUI
│   ├── system-maintenance.ps1         # System maintenance tasks
│   ├── allow-scripts.cmd              # PowerShell execution policy
│   └── Hostbuilder/
│       └── BuildHosts.ps1             # Hosts file builder
├── user/.dotfiles/config/
│   ├── powershell/profile.ps1         # PowerShell profile
│   ├── windows-terminal/              # Windows Terminal config
│   └── nvidia/                        # NVIDIA registry tweaks and profiles
├── setup.ps1                          # Main system setup script
├── .gitignore
└── README.md
```

## Available Scripts

All scripts are located in `~/Scripts/` and can be run directly:

### System Optimization

- **`gpu-display-manager.ps1`** - Manage NVIDIA GPU settings (P-State, HDCP, MSI Mode, EDID)
- **`edid-manager.ps1`** - Apply/remove EDID overrides to fix display issues
- **`gaming-display.ps1`** - Configure fullscreen mode and multiplane overlay
- **`debloat-windows.ps1`** - System debloater (Apps, Services, Tasks, Features)

### Gaming Utilities

- **`steam.ps1`** - Optimize Steam for minimal RAM/CPU usage
- **`shader-cache.ps1`** - Clear Steam/game/GPU shader caches
- **`DLSS-force-latest.ps1`** - Force latest DLSS version

### Maintenance

- **`UltimateDiskCleanup.ps1`** - Disk cleanup tool (GUI)
- **`debloat-windows.ps1`** - Debloating and optimization suite
- **`setup.ps1`** - Install common software and perform system maintenance

### Networking

- **`Network-Tweaker.ps1`** - Advanced network adapter configuration GUI
- **`Hostbuilder/BuildHosts.ps1`** - Build custom hosts file with ad/malware blocking

### Configuration

- **`allow-scripts.cmd`** - Enable/disable PowerShell script execution

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

The PowerShell profile (`user/.dotfiles/config/powershell/profile.ps1`) includes:

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

Create `user/.dotfiles/config/powershell/local.ps1` for machine-specific configuration that won't be tracked by yadm:

```powershell
# user/.dotfiles/config/powershell/local.ps1
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

### yadm Commands Not Working

Make sure yadm is in your PATH:

```powershell
where.exe yadm
```

If not found, reinstall yadm or add it to PATH manually.

## Credits

This repository builds upon work from:

- [zScripts](https://github.com/zoicware/zScripts) - Windows optimization scripts
- [AveYo](https://github.com/AveYo) - Various Windows tools and scripts
- [FR33THYFR33THY](https://github.com/FR33THYFR33THY) - Gaming optimizations

## License

This repository is provided as-is for personal use.

---

**Note**: Always review scripts before running them, especially those that modify system settings or registry values.