# TODO.md - Ven0m0/Win

## In Progress

### Fix Parser Errors
- [ ] Fix `Scripts/arc-raiders/SkipVideosMod.ps1` line 29 - incomplete pipe element `| Select-Object -Ex`
- [ ] Verify `Scripts/Network-Tweaker.ps1` for parser errors

## Pending

### Package Installation
- [ ] Add [Notepad Replacer](https://www.binaryfortress.com/NotepadReplacer) to package install:
  - URL: `https://www.binaryfortress.com/Data/Download/?Package=notepadreplacer&Log=100`
  - Requires Notepad++ installed first

### Dotfiles Patterns
- [ ] Evaluate [chawyehsu/dotfiles](https://github.com/chawyehsu/dotfiles) patterns:
  - [ ] Install bootstrap patterns from [install.ps1](https://github.com/chawyehsu/dotfiles/blob/main/install.ps1)
  - [ ] PowerShell profile features from [profile.ps1](https://github.com/chawyehsu/dotfiles/blob/main/.config/powershell/profile.ps1)
  - [ ] WSL configuration from [.config/wsl](https://github.com/chawyehsu/dotfiles/tree/main/.config/wsl)
  - [ ] Scoop config from [config.json](https://github.com/chawyehsu/dotfiles/blob/main/.config/scoop/config.json)

## Completed 

- [x] Clean Steam redist installers - `Scripts/Optimize-Steam.ps1`
- [x] Download umpdc.dll (NoSteamWebHelper) - `Scripts/Optimize-Steam.ps1` handles this
- [x] Create Steam desktop shortcut with args - `Scripts/New-SteamShortcut.ps1`