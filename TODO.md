# TODO.md - Ven0m0/Win

## In Progress

### Script Quality
- [ ] Verify `Scripts/Network-Tweaker.ps1` for remaining PSScriptAnalyzer issues (4,233 lines — needs full lint run)
- [ ] Fix `Scripts/enable-timer-res.ps1` hardcoded `C:\SetTimerResolution.exe` path → use `$env:SystemDrive`
- [ ] Fix `Scripts/reg/priority.ps1` line 4 TODO: broken QoS `netsh` commands need replacement

### Test Coverage (no Pester tests exist)
- [ ] `tests/New-SteamShortcut.Tests.ps1`
- [ ] `tests/Optimize-Steam.Tests.ps1`
- [ ] `tests/Steam-Config.Tests.ps1`
- [ ] `tests/enable-timer-res.Tests.ps1`

## Pending

### Package Installation
- [ ] Add [Notepad Replacer](https://www.binaryfortress.com/NotepadReplacer) to `Scripts/Install-Packages.ps1`
  - URL: `https://www.binaryfortress.com/Data/Download/?Package=notepadreplacer&Log=100`
  - Requires Notepad++ installed first; verify silent install flag

### Steam VDF Consolidation
- [ ] Audit `Scripts/steam.ps1` and `Scripts/Steam-Config.ps1` VDF parsing
- [ ] Remove redundant VDF logic; ensure all callers use `Common.ps1` `ConvertFrom-VDF`/`ConvertTo-VDF`

### Dotfiles Patterns (chawyehsu reference)
- [ ] Evaluate [chawyehsu/dotfiles](https://github.com/chawyehsu/dotfiles) patterns:
  - [ ] Bootstrap patterns from [install.ps1](https://github.com/chawyehsu/dotfiles/blob/main/install.ps1)
  - [ ] PowerShell profile features from [profile.ps1](https://github.com/chawyehsu/dotfiles/blob/main/.config/powershell/profile.ps1)
  - [ ] WSL configuration from [.config/wsl](https://github.com/chawyehsu/dotfiles/tree/main/.config/wsl)
  - [ ] Scoop config from [config.json](https://github.com/chawyehsu/dotfiles/blob/main/.config/scoop/config.json)

### Feature Ideas
- [ ] `Watch-GpuMetrics` helper in `Common.ps1` — real-time nvidia-smi/WMI GPU dashboard
- [ ] `Start-OptimizedGame.ps1` — generalize `start-arc-raiders.ps1` launch patterns for any game
- [ ] `Test-SystemHealth` command — proactive health checks (disk, updates, services, temp dirs, startup)

## Completed

- [x] Fix `Scripts/arc-raiders/SkipVideosMod.ps1` line 29 — truncated `| Select-Object -Ex` → `.SteamPath`
- [x] Fix `Scripts/shell-setup.ps1` bare `curl` → `curl.exe` (lines 95-96)
- [x] Add `#Requires -Version 5.1` to `Deploy-Config.ps1`, `Install-Packages.ps1`, `Steam-Config.ps1`, `steam.ps1`, `enable-timer-res.ps1`
- [x] Fix `.kilo/kilo.json` trailing comma in `agent` block (invalid JSON)
- [x] Run `@biomejs/biome format --write` on all tracked JSON files
- [x] Clean Steam redist installers — `Scripts/Optimize-Steam.ps1`
- [x] Download umpdc.dll (NoSteamWebHelper) — `Scripts/Optimize-Steam.ps1`
- [x] Create Steam desktop shortcut with args — `Scripts/New-SteamShortcut.ps1`
