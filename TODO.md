# TODO.md - Ven0m0/Win

## Pending

### Dotfiles Patterns (chawyehsu reference)
Read and analyze [chawyehsu/dotfiles](https://github.com/chawyehsu/dotfiles) as a whole and think/reason about what could be implemented in this repo, and whether the file/folder structure could improve.

- [ ] Bootstrap patterns from [install.ps1](https://github.com/chawyehsu/dotfiles/blob/main/install.ps1)
- [ ] PowerShell profile features from [profile.ps1](https://github.com/chawyehsu/dotfiles/blob/main/.config/powershell/profile.ps1)
- [ ] WSL configuration from [.config/wsl](https://github.com/chawyehsu/dotfiles/tree/main/.config/wsl)
- [ ] Scoop config from [config.json](https://github.com/chawyehsu/dotfiles/blob/main/.config/scoop/config.json)

### Feature Ideas
- [ ] `Watch-GpuMetrics` helper in `Common.ps1` — real-time nvidia-smi/WMI GPU dashboard
- [ ] `Start-OptimizedGame.ps1` — generalize `start-arc-raiders.ps1` launch patterns for any game
- [ ] `Test-SystemHealth` command — proactive health checks (disk, updates, services, temp dirs, startup)
