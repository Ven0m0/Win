# CLAUDE.md - AI Assistant Guide

## Repository Overview

This is a **Windows dotfiles repository** managed with [yadm](https://yadm.io/), containing PowerShell configurations, optimization scripts, and Windows system tweaks. The repository is designed for managing Windows development environments and gaming optimizations across multiple machines.

**Key Technologies:**

- **yadm**: Dotfile management (git-based)
- **PowerShell**: Scripting and automation
- **Git**: Version control
- **Windows Terminal**: Terminal emulator
- **Registry Tweaks**: System optimizations

**Primary Use Cases:**

1. Windows system optimization and gaming performance
2. Dotfile synchronization across Windows machines
3. Automated Windows environment setup
4. NVIDIA GPU configuration and tweaks

---

## Repository Structure

### Root Directory Layout

```
Win/
├── .config/                    # DEPRECATED: Old config location
├── .github/                    # GitHub workflows and templates
├── .vscode/                    # VS Code workspace settings
│   ├── settings.json          # Editor config (PowerShell formatting, etc.)
│   └── extensions.json        # Recommended extensions
├── .yadm/                      # yadm configuration
│   └── bootstrap              # Post-clone setup script (PowerShell)
├── Scripts/                    # Main PowerShell scripts directory
│   ├── Common.ps1             # Shared utility functions module
│   ├── Hostbuilder/           # Hosts file management
│   └── reg/                   # Registry files
├── user/                       # User-specific configurations
│   └── .dotfiles/             # Active dotfiles location
│       └── config/            # Application configurations
├── .editorconfig              # Editor formatting rules
├── .gitattributes             # Git attribute rules
├── .gitconfig                 # Git configuration (user-specific)
├── .gitignore                 # Git ignore patterns
├── README.md                  # User documentation
├── TODO.MD                    # Project tasks/roadmap
├── setup.ps1                  # Main system setup script
└── submodules.md              # External script references
```

### Critical Directories

#### `/Scripts` - Main Scripts Directory

Contains PowerShell optimization and utility scripts. **All scripts require:**

- PowerShell 5.1+ (PowerShell 7+ recommended)
- Administrator privileges
- `Common.ps1` module in the same directory

**Script Categories:**

1. **GPU/Display** - `nvidia-settings.ps1`, `edid-manager.ps1`, `gaming-display.ps1`, `msi-mode.ps1`
2. **Gaming** - `steam.ps1`, `shader-cache.ps1`, `DLSS-force-latest.ps1`
3. **System** - `settings.ps1`, `keyboard-shortcuts.ps1`, `UltimateDiskCleanup.ps1`
4. **Network** - `Network-Tweaker.ps1`, `Hostbuilder/BuildHosts.ps1`
5. **Utilities** - `allow-scripts.cmd`, `setup.ps1`

#### `/user/.dotfiles/config` - Active Configuration Files

The **current location** for all configuration files (replaces deprecated `.config/`):

```
user/.dotfiles/config/
├── powershell/
│   ├── profile.ps1           # Main PowerShell profile
│   └── local.ps1             # Machine-specific (not tracked)
├── windows-terminal/
│   └── settings.json         # Terminal configuration
├── winget-configs/
│   └── settings.json         # Winget settings
├── nvidia/                    # NVIDIA settings and profiles
├── nvidia-inspector/          # NVIDIA Profile Inspector configs
├── DDU/                       # Display Driver Uninstaller settings
├── games/                     # Game-specific configurations
│   ├── bf2/                  # Battlefield 2
│   ├── bo6/                  # Black Ops 6
│   └── bo7/                  # Black Ops 7
├── msi-afterburner/          # MSI Afterburner profiles
├── bleachbit/                # BleachBit cleaners
├── brave/                    # Brave browser configs
├── firefox/                  # Firefox configs
├── cmd/                      # CMD configurations
└── cursors/                  # Custom cursor themes
```

---

## File Conventions

### PowerShell Scripts

#### Style Guidelines (enforced by `.vscode/settings.json`)

```powershell
# OTBS (One True Brace Style) - opening brace on same line
function My-Function {
  param(
    [Parameter(Mandatory)]
    [string]$Name
  )

  # 2 spaces for indentation (not tabs)
  if ($condition) {
    # Whitespace around operators
    $result = $value1 + $value2

    # Pipe operators have whitespace
    Get-Process | Where-Object { $_.Name -eq 'powershell' }
  }
}

# Comment-based help for all functions
<#
.SYNOPSIS
    Brief description
.DESCRIPTION
    Detailed description
.PARAMETER Name
    Parameter description
.EXAMPLE
    My-Function -Name "test"
#>
```

#### Common.ps1 Module Functions

**Always use these instead of duplicating code:**

```powershell
# Admin elevation
Request-AdminElevation

# UI
Initialize-ConsoleUI -Title "Script Name"
Show-Menu -Title "Menu Title" -Options @("Option 1", "Option 2")
$choice = Get-MenuChoice -Min 1 -Max 2

# Registry
Set-RegistryValue -Path "HKLM\..." -Name "Value" -Type "REG_DWORD" -Data "1"
Remove-RegistryValue -Path "HKLM\..." -Name "Value"
$gpuPaths = Get-NvidiaGpuRegistryPaths

# File operations
Get-FileFromWeb -URL "https://..." -File "C:\path\to\file"
Clear-DirectorySafe -Path "C:\path\to\clear"

# VDF parsing (Steam)
$data = ConvertFrom-VDF -Content (Get-Content "file.vdf")
ConvertTo-VDF -Data $hashtable | Out-File "file.vdf"
```

### File Naming Conventions

- **PowerShell scripts**: `lowercase-with-dashes.ps1`
- **Batch files**: `lowercase-with-dashes.cmd`
- **Config files**: Follow application conventions
- **Documentation**: `UPPERCASE.md` for important docs, `lowercase.md` for others

### Line Endings and Encoding

From `.editorconfig`:

- **Default**: `CRLF` (Windows-style)
- **Charset**: `UTF-8`
- **PowerShell**: `UTF-8 with BOM` (`.vscode/settings.json`)
- **Trailing whitespace**: Trimmed (except Markdown)
- **Final newline**: Always inserted

---

## Git and yadm Workflows

### Understanding yadm

yadm is a **git wrapper** for dotfiles. It works identically to git but operates on `$HOME` as the working directory.

**Key Differences:**

- `git status` → `yadm status`
- `git add` → `yadm add`
- `git commit` → `yadm commit`
- Files are tracked from `$HOME` directory, not a separate repo folder

### Common yadm Operations

```powershell
# Check status of tracked dotfiles
yadm status

# Add a new dotfile to track
yadm add $HOME\.config\newfile.json

# Commit changes
yadm commit -m "Update configuration"

# Push to remote
yadm push

# Pull from remote
yadm pull

# Show differences
yadm diff

# List tracked files
yadm ls-files
```

### Git Configuration

From `.gitconfig`:

**Important Settings:**

- **Default branch**: `main`
- **Pull strategy**: `rebase = true` (always rebase on pull)
- **Push**: `autoSetupRemote = true` (auto-track remote branches)
- **Fetch**: `prune = true` (remove deleted remote branches)
- **Editor**: VS Code (`code --wait`)
- **CRLF**: `autocrlf = true` (Windows line endings)
- **Maintenance**: Incremental strategy enabled

**Useful Aliases:**

```bash
git st      # status
git lg      # pretty log graph
git amend   # amend without editing message
git undo    # soft reset HEAD~1
git cleanup # delete merged branches
```

### Git Workflow for AI Assistants

When modifying this repository:

1. **Check current state:**

   ```powershell
   yadm status
   yadm diff
   ```

2. **Make changes** to files

3. **Review changes:**

   ```powershell
   yadm diff
   yadm status
   ```

4. **Stage files:**

   ```powershell
   yadm add path/to/file
   # or stage all changes
   yadm add -A
   ```

5. **Commit with descriptive message:**

   ```powershell
   yadm commit -m "Brief description of changes"
   ```

6. **Push to remote:**
   ```powershell
   yadm push
   ```

---

## Common Tasks for AI Assistants

### 1. Adding a New PowerShell Script

```powershell
# 1. Create script in Scripts/ directory
New-Item -Path "Scripts/new-script.ps1" -ItemType File

# 2. Add required header
# #Requires -RunAsAdministrator
# . "$PSScriptRoot\Common.ps1"
# Request-AdminElevation
# Initialize-ConsoleUI -Title "Script Name"

# 3. Implement functionality using Common.ps1 functions

# 4. Track with yadm
yadm add Scripts/new-script.ps1

# 5. Commit
yadm commit -m "Add new-script.ps1 for [purpose]"
```

### 2. Modifying PowerShell Profile

**IMPORTANT:** The active profile is at `user/.dotfiles/config/powershell/profile.ps1`

```powershell
# Edit the profile
code user/.dotfiles/config/powershell/profile.ps1

# Test changes
. $PROFILE

# Stage and commit
yadm add user/.dotfiles/config/powershell/profile.ps1
yadm commit -m "Update PowerShell profile: [description]"
```

### 3. Adding Configuration Files

```powershell
# Add new config to appropriate directory
# Example: VS Code settings
yadm add user/.dotfiles/config/vscode/settings.json

# Commit
yadm commit -m "Add VS Code configuration"
```

### 4. Creating Registry Tweaks

Use `Common.ps1` functions:

```powershell
# Enable a feature
Set-RegistryValue -Path "HKLM\SOFTWARE\..." -Name "Feature" -Type "REG_DWORD" -Data "1"

# Disable a feature
Set-RegistryValue -Path "HKLM\SOFTWARE\..." -Name "Feature" -Type "REG_DWORD" -Data "0"

# Remove registry value
Remove-RegistryValue -Path "HKLM\SOFTWARE\..." -Name "Feature"
```

### 5. Updating Documentation

When modifying scripts or structure:

1. Update `README.md` for user-facing changes
2. Update `CLAUDE.md` (this file) for structural changes
3. Update `Scripts/OPTIMIZATION_NOTES.md` for script optimizations
4. Keep `TODO.MD` current with pending tasks

---

## Script Dependencies and Architecture

### Common.ps1 Module Architecture

All optimized scripts follow this pattern:

```powershell
#Requires -RunAsAdministrator

# Import shared utilities
. "$PSScriptRoot\Common.ps1"

# Request elevation if not admin
Request-AdminElevation

# Initialize UI
Initialize-ConsoleUI -Title "Script Title (Administrator)"

# Define functions
function Enable-Feature {
    # Implementation using Common.ps1 helpers
}

function Disable-Feature {
    # Implementation
}

function Show-Status {
    # Implementation
}

# Main menu loop
while ($true) {
    Show-Menu -Title "Script Menu" -Options @(
        "Option 1",
        "Option 2",
        "View Status",
        "Exit"
    )

    $choice = Get-MenuChoice -Min 1 -Max 4

    switch ($choice) {
        1 { Enable-Feature }
        2 { Disable-Feature }
        3 { Show-Status }
        4 { exit }
    }

    Read-Host "`nPress Enter to continue"
}
```

### Script Merging History

See `Scripts/OPTIMIZATION_NOTES.md` for details. Key mergers:

- `P0-State-nvidia.ps1` + `Hdcp.ps1` → `nvidia-settings.ps1`
- `OverrideEDID.ps1` + `RemoveEDIDOverride.ps1` → `edid-manager.ps1`
- `fso.ps1` + `mpo.ps1` → `gaming-display.ps1`

---

## Important Conventions

### DO's ✅

1. **Always use `Common.ps1` functions** - Never duplicate code
2. **Test scripts before committing** - Ensure they work on fresh Windows
3. **Follow PowerShell style guide** - OTBS, 2-space indent, proper spacing
4. **Document all functions** - Use comment-based help
5. **Check admin privileges** - Use `Request-AdminElevation`
6. **Provide user feedback** - Use colored output, progress indicators
7. **Handle errors gracefully** - Suppress expected errors, report unexpected ones
8. **Update documentation** - Keep README.md and this file current
9. **Use meaningful commit messages** - Describe what and why
10. **Track configs in `user/.dotfiles/config/`** - New standard location

### DON'Ts ❌

1. **Don't use `.config/` directory** - Deprecated, use `user/.dotfiles/config/`
2. **Don't commit sensitive data** - Check `.gitignore` patterns
3. **Don't use tabs for PowerShell** - Use 2 spaces
4. **Don't skip error handling** - Always consider failure cases
5. **Don't hardcode paths** - Use `$PSScriptRoot`, `$HOME`, etc.
6. **Don't duplicate code** - Extract to `Common.ps1` if used multiple times
7. **Don't modify without testing** - Test all registry changes
8. **Don't ignore `.editorconfig`** - Respect formatting rules
9. **Don't commit without reviewing** - Always check `yadm diff`
10. **Don't push untested changes** - Verify functionality first

### File Location Standards

```powershell
# ✅ CORRECT - Use these locations
user/.dotfiles/config/powershell/profile.ps1
user/.dotfiles/config/windows-terminal/settings.json
user/.dotfiles/config/nvidia/

# ❌ DEPRECATED - Don't use
.config/powershell/         # Old location
.config/windows-terminal/   # Old location
```

---

## Bootstrap Process

When cloning this repository on a new machine:

1. **Install yadm**: `winget install yadm`
2. **Clone repo**: `yadm clone https://github.com/Ven0m0/Win.git`
3. **Run bootstrap**: `pwsh $HOME\.yadm\bootstrap`

The bootstrap script (`.yadm/bootstrap`):

- Checks prerequisites (PowerShell, Git, etc.)
- Sets up PowerShell profile
- Configures Windows Terminal
- Checks Git configuration
- Verifies/installs development tools via winget
- Sets up Scripts directory and execution policy
- Creates common directories (`~\.local\bin`, `~\.cache`, `~\Projects`)
- Optionally adds Scripts to PATH

---

## PowerShell Profile Features

Location: `user/.dotfiles/config/powershell/profile.ps1`

### Key Features

**Environment Setup:**

- Adds `~/Scripts` and `~/.local/bin` to PATH
- Sets `$env:EDITOR` (VS Code → Vim → Notepad)
- Configures Starship prompt (if installed)

**Aliases:**

```powershell
# Navigation
~          # cd $HOME
..         # cd ..
...        # cd ../..

# Git shortcuts
gs, ga, gc, gp, gl, gd

# yadm shortcuts
ys, ya, yc, yp, yl

# Docker (if installed)
d, dc, dps, dimg

# Unix-like
which, grep, df, du
```

**Functions:**

```powershell
Get-DiskUsage / df          # Show disk usage
Get-FileSize / du           # Calculate directory size
Update-Profile / sreload    # Reload profile
Edit-Profile                # Edit profile in $EDITOR
Get-PublicIP / myip         # Get public IP
touch <file>                # Create/update file
mkcd <dir>                  # Create dir and cd into it
Clear-TempFiles             # Clean temp directories
supdate                     # Update PowerShell/Starship
pupdate                     # Update all winget packages
```

**PSReadLine Config:**

- Arrow keys for history search
- Tab for menu completion
- Predictive IntelliSense (PS7+)
- Syntax highlighting
- Custom color scheme

### Local Customizations

Create `user/.dotfiles/config/powershell/local.ps1` for machine-specific settings (ignored by yadm):

```powershell
# Machine-specific aliases
Set-Alias myapp "C:\path\to\app.exe"

# Environment variables
$env:MY_CUSTOM_VAR = "value"
```

---

## Testing Guidelines

Before committing scripts:

### 1. Syntax Check

```powershell
# Run PSScriptAnalyzer if available
Invoke-ScriptAnalyzer -Path Scripts/your-script.ps1
```

### 2. Execution Test

```powershell
# Test as admin
PowerShell.exe -ExecutionPolicy Bypass -File Scripts/your-script.ps1
```

### 3. Registry Change Verification

```powershell
# Before running script
Get-ItemProperty -Path "HKLM\..."

# After running script
Get-ItemProperty -Path "HKLM\..."

# Compare values
```

### 4. Menu Navigation Test

- Test all menu options
- Verify exit functionality
- Check invalid input handling

### 5. Error Handling Test

- Test without admin privileges (should elevate)
- Test with missing dependencies
- Test with invalid input

---

## External Resources

### Referenced in submodules.md

- [zScripts](https://github.com/zoicware/zScripts) - Windows optimization base
- [OverrideEDID](https://github.com/zoicware/OverrideEDID) - Display fixes
- [RemoveWindowsAI](https://github.com/zoicware/RemoveWindowsAI) - AI removal

### Package Managers

- [Winget](https://winstall.app) - Primary package manager
- [Scoop](https://scoop.sh) - Alternative package manager
- [Chocolatey](https://chocolatey.org) - Legacy package manager
- [CCT](https://christitus.com/win) - ChrisTitus Tech utility

### Tools Referenced

- [NVIDIA Profile Inspector](https://github.com/Orbmu2k/nvidiaProfileInspector)
- [NVIDIA Profile Inspector Unlocked](https://github.com/Ixeoz/nvidiaProfileInspector-UNLOCKED)
- [ExplorerPatcher](https://github.com/valinet/ExplorerPatcher)
- [Tiny11 Builder](https://github.com/ntdevlabs/tiny11builder)
- [UUP Dump](https://uupdump.net)
- [Unattend Generator](https://schneegans.de/windows/unattend-generator)

---

## Troubleshooting Common Issues

### Scripts Won't Execute

**Problem**: "Running scripts is disabled on this system"

**Solution**:

```cmd
cd %USERPROFILE%\Scripts
allow-scripts.cmd
```

Or manually:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### Bootstrap Won't Run

**Problem**: Bootstrap script doesn't execute after clone

**Solution**:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
pwsh $HOME\.yadm\bootstrap
```

### yadm Not Found

**Problem**: `yadm` command not recognized

**Solution**:

```powershell
winget install yadm
# Restart terminal
```

### Common.ps1 Not Found

**Problem**: Scripts fail with "Common.ps1 not found"

**Solution**: Ensure `Common.ps1` is in the Scripts directory:

```powershell
yadm status  # Check if Common.ps1 is present
```

### Registry Changes Not Applying

**Problem**: Script runs but settings don't change

**Checklist**:

1. Running as Administrator?
2. Correct registry path? (HKLM vs HKCU)
3. Restart required?
4. Windows version compatible?

---

## Security Considerations

### What Gets Committed

**✅ Safe to commit:**

- Configuration files (without secrets)
- PowerShell scripts
- Documentation
- VS Code settings

**❌ Never commit:**

- `.gitconfig` (has user email - use template)
- `.gitconfig.local` (local overrides)
- `.ssh/` directory (except `config`)
- `powershell/local.ps1` (machine-specific)
- Any files matching `.gitignore` patterns

### Script Safety

All scripts in this repository:

- Are open source and reviewable
- Primarily modify registry settings
- Require explicit user confirmation
- Can be undone (most have "restore defaults" options)

**Always review scripts before running**, especially:

- Registry modifications
- System file changes
- Network configurations

---

## Version Control Best Practices

### Commit Message Format

```
<type>: <subject>

<body (optional)>
```

**Types:**

- `feat`: New feature or script
- `fix`: Bug fix
- `docs`: Documentation update
- `refactor`: Code refactoring
- `style`: Formatting changes
- `chore`: Maintenance tasks

**Examples:**

```
feat: Add GPU power state optimization script

Add nvidia-settings.ps1 to manage P0 state and HDCP settings
Merged P0-State-nvidia.ps1 and Hdcp.ps1 for unified interface

fix: Correct registry path in msi-mode.ps1

Updated device registry enumeration to handle edge cases

docs: Update README with new script organization
```

### Branch Strategy

**Main branch**: `main` (stable, tested changes)

For experimental changes:

```powershell
# Create feature branch
git checkout -b feature/my-feature

# Make changes, commit
git add .
git commit -m "feat: Add my feature"

# Merge back when tested
git checkout main
git merge feature/my-feature
```

---

## Performance Optimization

### Script Performance Tips

From `Common.ps1` design:

1. **Use robocopy for bulk operations**:

   ```powershell
   Clear-DirectorySafe -Path "C:\temp"  # Uses robocopy
   ```

2. **Suppress unnecessary output**:

   ```powershell
   $null = reg add ... 2>&1
   ```

3. **Minimize WMI calls**:

   ```powershell
   # Cache results
   $gpuPaths = Get-NvidiaGpuRegistryPaths
   ```

4. **Use built-in cmdlets over external tools** when possible

5. **Batch registry operations** instead of individual calls

---

## Maintenance Schedule

### Regular Tasks

**Weekly:**

- Review `TODO.MD` for pending items
- Test critical scripts after Windows updates
- Check for yadm updates: `winget upgrade yadm`

**Monthly:**

- Update PowerShell: `supdate`
- Review and clean old configurations
- Check for broken symlinks/references

**After Windows Update:**

- Test NVIDIA scripts (drivers may reset settings)
- Verify PowerShell execution policy
- Check Windows Terminal configuration

**Before Major Changes:**

- Backup registry: `regedit → Export`
- Create system restore point
- Document current state

---

## Quick Reference

### Most Used Commands

```powershell
# Check dotfile status
yadm status

# View changes
yadm diff

# Add and commit
yadm add <file>
yadm commit -m "message"
yadm push

# Reload PowerShell profile
sreload

# Edit PowerShell profile
Edit-Profile

# Run script as admin
PowerShell -ExecutionPolicy Bypass -File Scripts/script.ps1

# Get public IP
myip

# Clean temp files
Clear-TempFiles
```

### Important Paths

```powershell
$PROFILE                    # PowerShell profile location
$HOME                       # User home directory
$HOME\Scripts               # Scripts directory
$HOME\.dotfiles\config      # Configuration files
$PSScriptRoot               # Current script directory
```

### Registry Shortcuts

```powershell
# NVIDIA GPU settings
HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\

# Windows performance
HKLM\SYSTEM\CurrentControlSet\Control\

# User preferences
HKCU\Software\
```

---

## Contributing Guidelines for AI

When modifying this repository:

1. **Understand before changing** - Read existing code and documentation
2. **Follow established patterns** - Use `Common.ps1`, match existing style
3. **Test thoroughly** - All changes must be tested
4. **Document changes** - Update all relevant documentation
5. **Commit logically** - Group related changes, write clear messages
6. **Preserve functionality** - Don't break existing features
7. **Respect user preferences** - Don't override local customizations
8. **Be conservative with automation** - Prefer explicit over implicit
9. **Maintain backwards compatibility** - Don't break existing scripts
10. **Ask when uncertain** - Better to clarify than assume

---

## Additional Notes

### Windows Terminal Configuration

Located at: `user/.dotfiles/config/windows-terminal/settings.json`

Bootstrap copies to: `$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`

### VS Code Integration

- EditorConfig support required for `.editorconfig`
- PowerShell extension recommended for script development
- Configured in `.vscode/settings.json` and `.vscode/extensions.json`

### Starship Prompt

If Starship is installed:

- Automatically initialized in PowerShell profile
- Provides git-aware, customizable prompt
- Install: `winget install Starship.Starship`

---

## Summary

This repository is a **comprehensive Windows dotfiles and optimization suite** designed for:

- Gaming performance optimization
- Developer environment setup
- NVIDIA GPU configuration
- Windows system tweaks
- Consistent cross-machine configurations

**Core Principles:**

- DRY (Don't Repeat Yourself) - Use `Common.ps1`
- User Safety - Always allow reverting changes
- Documentation - Keep docs current
- Testing - Verify before committing
- Modularity - One concern per script

**For AI Assistants:**

- Always check `yadm status` before and after changes
- Use `Common.ps1` functions exclusively
- Follow PowerShell style guide strictly
- Test in admin PowerShell before committing
- Update documentation for structural changes
- Commit with descriptive messages
- Never commit sensitive data

---

**Last Updated**: 2025-12-04
**Repository**: https://github.com/Ven0m0/Win
**Maintainer**: Ven0m0
**License**: Personal use (see README.md)
