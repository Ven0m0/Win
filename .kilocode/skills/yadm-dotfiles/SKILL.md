---
name: yadm-dotfiles
description: yadm dotfile management workflow for this repo — tracking files under $HOME, bootstrap process, config file locations, and the distinction between yadm (dotfiles) and git (this Scripts repo)
---

# yadm Dotfiles Workflow

## What yadm is

yadm is a git wrapper that treats `$HOME` as the working tree. It tracks dotfiles (PowerShell profile, terminal config, etc.) without symlinks.

## Key distinction

| yadm | git |
|---|---|
| Manages dotfiles at `$HOME` | Manages this Scripts/config repo at `~/Win` |
| `yadm add ~/.config/...` | `git add Scripts/new-script.ps1` |
| `yadm push` to sync dotfiles | `git push` for this repo |

## Dotfile locations

All active configs live in `user/.dotfiles/config/` — NOT `.config/` (deprecated):

| Config | Path |
|---|---|
| PowerShell profile | `user/.dotfiles/config/powershell/profile.ps1` |
| Machine-local overrides | `user/.dotfiles/config/powershell/local.ps1` (gitignored) |
| Windows Terminal | `user/.dotfiles/config/windows-terminal/settings.json` |
| Game configs | `user/.dotfiles/config/games/<game>/` |
| BleachBit cleaners | `user/.dotfiles/config/bleachbit/cleaners/` |

## Bootstrap (new machine)

```powershell
winget install yadm
yadm clone https://github.com/Ven0m0/Win.git
pwsh $HOME\.yadm\bootstrap
```

Bootstrap sets up: PowerShell profile symlinks, Windows Terminal config, git defaults, dev tools via winget, Scripts dir added to PATH.

## Common yadm commands

```powershell
yadm status           # what's changed in tracked dotfiles
yadm diff             # see changes
yadm add <file>       # track a new dotfile
yadm commit -m "..."
yadm push             # sync to remote
yadm ls-files         # list all tracked dotfiles
```

## Never track

- `user/.dotfiles/config/powershell/local.ps1` — machine-specific, gitignored
- `.gitconfig` / `.gitconfig.local` — contain personal email
- `.ssh/` directory (`.ssh/config` is OK)
- Any `.env` file or token file
