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
- **Claude Code Setup**: Global settings, hooks, plugins and MCP servers via `Scripts/Setup-ClaudeCode.ps1`
- **Game Configs**: Arc Raiders, BF2, BO6, Fortnite, Minecraft, plus emulator (Dolphin, AzaharPlus, Eden) seeds
- **Media Tools**: Dedupe and optimize image/video libraries

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

### Order of Execution

The full chain, in the order each layer actually runs:

1. **`bootstrap.ps1`** (internet entry point) — self-elevates, installs winget/Git/Python/mise/uv if missing, shallow-clones the repo, then invokes `Setup-Win11.ps1`.
2. **`Scripts/Setup-Win11.ps1`** (`#Requires -RunAsAdministrator`) — orchestrates the local machine setup in 6 phases:
   1. **Prerequisites** — verifies winget, Git, PowerShell 7+, and mise are available (registers winget via App Installer if absent, configures OpenSSH/git credential helper/TERM, installs Git/pwsh via winget if missing, fails if mise is absent)
   2. **Debloat** — runs `Scripts/debloat-windows.ps1 -NoRestorePoint -Unattended` (skip with `-SkipDebloat`)
   3. **Install software catalog** — runs `Scripts/Install-Packages.ps1`, which reads `Scripts/packages.psd1` (skip with `-SkipPackages`)
   4. **Deploy configs** — `mise install` then `mise run bootstrap`, which invokes `Scripts/Setup-Dotfiles.ps1`
   5. **Optional WSL2** — `wsl.exe --install --no-distribution` if not already installed (skip with `-SkipWSL`)
   6. **Summary** — prints a color-coded OK/FAIL/SKIP table and total duration
3. **`Scripts/Setup-Dotfiles.ps1`** (invoked by `mise run bootstrap` / dotbot, or standalone) — deploys tracked configs in 5 phases:
   1. Set `CurrentUser` execution policy to `RemoteSigned`
   2. Install core tools via winget (Git, PowerShell 7+, Windows Terminal, VS Code) — skip with `-SkipWingetTools`
   3. Deploy every entry in the config manifest (PowerShell profile, Windows Terminal settings, Firefox `user.js`, game configs, editor settings, etc.) with SHA256 hash-based change detection
   4. Configure `PATH` (add `~/Scripts`, ensure `~/.local/bin` precedes WinGet Links) and create common directories
   5. Print a verification summary and list any failed deployments

Standalone package installs (no debloat, no config deploy) — see [Package Installation](#package-installation) below.

## Quick Start

### Option 1: One-Command Setup (Fresh Windows 11)

See [Fresh Windows 11 Install (One-Command)](#fresh-windows-11-install-one-command) above — same `bootstrap.ps1` command, which self-elevates, installs prerequisites, clones the repo, and chains into the full setup.

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

3. **Enable script execution** (if bootstrap doesn't run automatically):
   ```pwsh
   pwsh -nop -nol "$HOME\Scripts\allow-scripts.ps1"
   ```

4. **PowerShell Profile**:
   ```pwsh
   Copy-Item "$HOME\user\.dotfiles\config\powershell\Microsoft.PowerShell_profile.ps1" $PROFILE -Force
   ```

5. **Windows Terminal Settings**:
   ```pwsh
   Copy-Item "$HOME\user\.dotfiles\config\windows-terminal\settings.json" "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" -Force
   ```

6. **Git Config**:
   ```pwsh
   Copy-Item "$HOME\user\.dotfiles\config\git\.gitconfig" "$HOME\.gitconfig"
   notepad $HOME\.gitconfig
   ```

The bootstrap script also sets up the PowerShell profile, configures Windows Terminal, checks for required tools, creates common directories, and optionally adds Scripts to PATH — and attempts to apply Firefox `user.js`, Brave policy registry settings, CMD aliases, and tracked game configs when their destination folders already exist.

## Package Installation

`Scripts/Install-Packages.ps1` installs the full software catalog defined in `Scripts/packages.psd1` (winget, Scoop, Chocolatey, Bun/npm globals, Cargo, PowerShell modules, Windows optional features) and can run standalone, without debloat or config deployment:

```pwsh
# Install everything in the catalog
pwsh -File "$env:USERPROFILE\project\Win\Scripts\Install-Packages.ps1"

# Skip specific package sources
pwsh -File "$env:USERPROFILE\project\Win\Scripts\Install-Packages.ps1" -SkipScoop -SkipChoco

# Also apply post-install Windows configuration (timezone, input locale, geo ID)
pwsh -File "$env:USERPROFILE\project\Win\Scripts\Install-Packages.ps1" -ApplyPostInstall
```

| Flag | Effect |
|---|---|
| `-SkipWinget` | Skip winget package installations |
| `-SkipScoop` | Skip Scoop package installations |
| `-SkipChoco` | Skip Chocolatey package installations |
| `-SkipSystemFeatures` | Skip Windows optional features (DISM) |
| `-SkipPowerShellModules` | Skip PowerShell module installations |
| `-SkipNotepadReplacer` | Skip Notepad Replacer setup |
| `-SkipPeripherals` | Skip peripheral driver/tool installs |
| `-SkipManualInstalls` | Skip manual (no winget package) app installs |
| `-SkipLanguagePackages` | Skip Bun/npm/Cargo global package installs |
| `-ApplyPostInstall` | Apply post-install Windows configuration (timezone, input locale, geo ID) |

`packages.psd1` is the single source of truth for every package list — edit it directly to add or remove software; no script changes needed.

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

Both scripts require administrator elevation and only touch `HKLM` power-related keys and follow the repo's restore-point and rollback conventions (`New-RestorePoint`, `-Restore`).

## Repository Structure

```text
.
├── Scripts/
│   ├── Setup-Win11.ps1           # Fresh Windows 11 one-command setup (local)
│   ├── Setup-Dotfiles.ps1        # Config deployment (called by dotbot / mise)
│   ├── Setup-Dotfiles.Apps.ps1   # Per-app/game resolvers and deploys (dot-sourced)
│   ├── Setup-ClaudeCode.ps1      # Claude Code marketplaces, plugins, MCP servers
│   ├── Install-Packages.ps1      # Software install driven by packages.psd1
│   ├── packages.psd1             # Canonical package catalog
│   ├── Common.ps1                # Shared utility functions
│   ├── allow-scripts.ps1         # Enable/disable PowerShell script execution
│   ├── debloat-windows.ps1       # System debloating suite
│   ├── system-settings-manager.ps1
│   ├── system-update.ps1
│   ├── system-maintenance.ps1    # Maintenance hub (-Action Defrag|Disk|Shader|Extra|All)
│   ├── fix-system.ps1            # Repair hub (-Action System|WindowsUpdate|All)
│   ├── Network-Tweaker.ps1       # Network adapter optimization
│   ├── optimize-steam.ps1        # Steam optimization
│   ├── dedupe-media.ps1, optimize-media.ps1, sanitize-filenames.ps1
│   ├── Get-BedrockPackUpdate.ps1, mc-freeze.ps1   # Minecraft Bedrock helpers
│   ├── arc-raiders/              # Arc Raiders utilities
│   ├── reg/                      # Registry tweaks and context-menu .reg files
│   ├── snapmem/                  # Memory snapshot tool (Python)
│   └── third-party/              # Vendored third-party tools
├── docs/                         # Per-script documentation
├── tests/                        # Pester tests (*.Tests.ps1)
├── user/.dotfiles/config/        # Tracked configs (deploy targets)
│   ├── powershell/               # PowerShell profile
│   ├── windows-terminal/, cmd/, git/, ssh/, psmux/, ohmyposh/, vscode/
│   ├── browser/                  # Firefox user.js, Brave policies
│   ├── games/                    # arc-raiders, bf2, bo6, fortnite
│   ├── emulators/                # dolphin, azaharplus, eden (seed-only)
│   ├── nvidia/, obs/, bleachbit/, DDU/, cursors/, handbrake/, legcord/
│   ├── claude/, kilo/, opencode/ # AI tool configs
│   └── mise/, scoop/, winget-configs/, cargo/, bat/, rtk/, topgrade/, wsl/
├── install.conf.yaml             # dotbot configuration entry point
├── mise.toml                     # Tool manifest and the deploy task
├── bootstrap.ps1                 # One-command internet bootstrap
├── .github/workflows/            # CI (ci, lint-format-test, ps-format, reg-validate)
├── .claude/                      # Claude Code agents, rules, skills
├── AGENTS.md                     # AI assistant guide
├── CLAUDE.md                     # Symlink to AGENTS.md
└── README.md                     # This file
```

## Available Scripts

Scripts live in `Scripts/` (added to `PATH` by `Setup-Dotfiles.ps1`) and can be run directly. Per-script details are in [`docs/`](docs/):

### Setup & Bootstrap

- **`Setup-Win11.ps1`** — Full fresh Windows 11 setup: debloat → install all software → deploy all configs. Chained from `bootstrap.ps1`; does not clone the repo itself, operates on wherever it's located
- **`Install-Packages.ps1`** — Install the full software catalog from `packages.psd1` (can run standalone)
- **`packages.psd1`** — Canonical package catalog (winget/scoop/choco/modules/features/appx-remove lists)
- **`Setup-Dotfiles.ps1`** — Deploy tracked configs (called by dotbot / `mise run deploy`)
- **`debloat-windows.ps1`** — Remove bloatware using `packages.psd1` `AppxToRemove` list
- **`Setup-ClaudeCode.ps1`** — Install Claude Code marketplaces, plugins and MCP servers from `user/.dotfiles/config/claude/`
- **`allow-scripts.ps1`** — Enable/disable PowerShell script execution policy

### System Optimization

- **`system-settings-manager.ps1`** — Apply system performance optimizations
- **`system-update.ps1`** — Windows Update handler
- **`system-maintenance.ps1`** — Maintenance hub: `-Action Defrag|Disk|Shader|Extra|All` (defrag/MSI, disk cleanup GUI, shader cache, DISM/cache rebuilds)
- **`fix-system.ps1`** — Repair hub: `-Action System|WindowsUpdate|All` (DISM/SFC/CHKDSK/network/WMI + Windows Update reset)

### Gaming Utilities

- **`optimize-steam.ps1`** — Optimize Steam for minimal RAM/CPU usage
- **`system-maintenance.ps1 -Action Shader`** — Clear Steam/game/GPU shader caches
- **`Get-BedrockPackUpdate.ps1`** — Report (and with `-Update`, apply) outdated Minecraft Bedrock packs/mods in LeviLauncher
- **`mc-freeze.ps1`** — Minecraft helper; see [`docs/mc-freeze.md`](docs/mc-freeze.md)
- **`arc-raiders/`** — Arc Raiders cleanup and intro-video skip mod

### Power & Performance

- **`system-settings-manager.ps1`** → *Performance Optimizations* menu — applies the gaming power/performance profile (disables hibernate, fast boot, power throttling, sleep/lock options; enables USB overclock compatibility and raw mouse input); same menu offers a *Restore Defaults* option that reverts every value it touched
- **`DisableUSBPowerManagement.ps1`** — Disables USB selective suspend across all USB hubs/controllers/HID devices so peripherals don't power down mid-session

### Maintenance & Cleanup

- **`system-maintenance.ps1 -Action Disk`** — Comprehensive disk cleanup tool (GUI)

### Media

- **`dedupe-media.ps1`** — Remove duplicate media (fclones exact, czkawka fuzzy); preview by default, `-Apply` to act. Run before `optimize-media.ps1`
- **`optimize-media.ps1`** — Compress images and re-encode video to H.265/Opus, backing up originals
- **`sanitize-filenames.ps1`** — Normalize problematic filenames

### Networking

- **`Network-Tweaker.ps1`** — Advanced network adapter configuration GUI

### Other

- **`reg/`** — Registry tweaks and context-menu `.reg` files
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

# Commit and push changes
git commit -m "chore: update configuration"
git push
```

### Adding New Dotfiles

To track a new configuration file:

```pwsh
# Add the file to git
git add $HOME\.my-new-config

# Commit
git commit -m "feat: add my new config"

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

Files with a `##template` suffix are substituted by dotbot at deploy time.

### Validating Scripts

Before committing changes to any `Scripts/*.ps1` file:

```pwsh
Invoke-ScriptAnalyzer -Path Scripts -Recurse -Severity Error -Settings PSScriptAnalyzerSettings.psd1
Invoke-Pester tests/*.Tests.ps1 -Output Detailed
```

## PowerShell Profile Features

The PowerShell profile (`user/.dotfiles/config/powershell/Microsoft.PowerShell_profile.ps1`, deployed to `~/Documents/PowerShell/`) includes:

### Aliases

- **Navigation**: `~`, `..` through `.....`
- **Git**: `gs`, `ga`, `gc`, `gpush`, `gpull`, `gl`, `gd`, `gcl`, `gcom`, `lazyg`
- **Unix-like**: `which`, `grep`, `sed`, `head`, `tail`, `unzip`, `pkill`, `pgrep`, `export`, `df`, `du`, `touch`, `ln`, `sudo`/`su` (elevate)
- **Misc**: `ll`, `la`, `uptime`, `sysinfo`, `flushdns`, `cpy`, `pst`, `myip`

### Functions

- `Get-DiskUsage` / `df` - Show disk usage
- `Get-FileSize` / `du` - Calculate directory size
- `winutil` / `winutildev` - Run Chris Titus Tech's WinUtil
- `Show-Help` - List profile commands
- `Get-PublicIP` / `myip` - Get public IP address
- `touch <file>` - Create/update file
- `mkcd <dir>` - Create directory and cd into it

### PSReadLine Configuration

- History search with arrow keys
- Tab completion with menu
- Predictive IntelliSense (PowerShell 7+)
- Syntax highlighting

## Customization

### Local Customizations

Create `$HOME\.dotfiles\config\powershell\local.ps1` for machine-specific configuration that won't be tracked by git:

```pwsh
# $HOME\.dotfiles\config\powershell\local.ps1
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

Manually copy the settings file — see step 5 under [Option 2: Manual Setup](#option-2-manual-setup).

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
