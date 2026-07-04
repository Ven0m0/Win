# Implementation Plan: Ven0m0/Win Repository

## Current Status: Updated 2026-07-04

## Completed Items

### Script Quality
- `Scripts/Network-Tweaker.ps1` — PSScriptAnalyzer clean
- `Scripts/enable-timer-res.ps1` — hardcoded path fixed, `Get-FileFromWeb` reuse, `#Requires -Version 5.1`
- Steam scripts (`Steam-Config.ps1`, `steam.ps1`, `New-SteamShortcut.ps1`) merged into `Scripts/Optimize-Steam.ps1`
- `Scripts/reg/priority.ps1` — QoS TODO resolved

### Test Coverage
- `tests/New-SteamShortcut.Tests.ps1`, `tests/Optimize-Steam.Tests.ps1`, `tests/Steam-Config.Tests.ps1`, `tests/enable-timer-res.Tests.ps1` — all present, dot-source the merged `Optimize-Steam.ps1`

### Package Installation
- Notepad Replacer added to `Scripts/Install-Packages.ps1` (Phase 7.5, gated on Notepad++ presence, `-SkipNotepadReplacer` switch)

### Steam VDF
- Resolved by consolidation — `Optimize-Steam.ps1` is now the single VDF-handling script; no separate parser to merge

---

## Remaining Tasks

### Evaluate chawyehsu Dotfiles Patterns

- Bootstrap patterns: [install.ps1](https://github.com/chawyehsu/dotfiles/blob/main/install.ps1) vs `Scripts/Setup-Dotfiles.ps1`
- PS profile features: [profile.ps1](https://github.com/chawyehsu/dotfiles/blob/main/.config/powershell/profile.ps1)
- WSL config: [.config/wsl](https://github.com/chawyehsu/dotfiles/tree/main/.config/wsl) → consider `user/.dotfiles/config/wsl/`
- Scoop config: [config.json](https://github.com/chawyehsu/dotfiles/blob/main/.config/scoop/config.json)

### Feature Improvements

- **`Watch-GpuMetrics`** — add to `Common.ps1`; real-time nvidia-smi/WMI GPU dashboard (temp, clock, VRAM, power)
- **`Start-OptimizedGame.ps1`** — generalize `start-arc-raiders.ps1` launch patterns; accept game name + preset; reuse `game-boost.ps1`
- **`Test-SystemHealth`** — proactive checks: disk health, pending updates, service anomalies, large temp dirs, startup items

---

## Validation Checklist

- [x] All `Scripts/*.ps1` pass PSScriptAnalyzer
- [x] All root scripts have `#Requires -Version 5.1`
- [x] Pester tests for New-SteamShortcut, Optimize-Steam, Steam-Config, enable-timer-res
- [x] Notepad Replacer added to package installation
- [x] Steam VDF consolidation complete (via script merge)
- [ ] chawyehsu patterns evaluated
- [ ] Watch-GpuMetrics, Start-OptimizedGame.ps1, Test-SystemHealth implemented
