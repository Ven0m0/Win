# TODO.md - Ven0m0/Win

## Pending

### Feature Ideas — completed 2026-07-10

All three shipped per `PLAN.md`. Notable deviations from the plan:
- `Start-OptimizedGame.ps1` generalizes `game-boost.ps1` (not `start-arc-raiders.ps1`, which stays
  Arc-Raiders/Steam-specific as scoped). `game-boost.ps1` is now a thin wrapper calling it with
  `Scripts/games/arc-raiders.psd1`. Dropped two unconditional `DISM /CleanUp-Wim` /
  `Get-MountedWimInfo` calls that ran on every boost (including `-DryRun`) in the original — looked
  like a leftover debug artifact, not intentional behavior, and a 15-30 minute component cleanup on
  every game launch would be a regression if carried into the generalized engine.
- `Test-SystemHealth` shipped as `fix-system.ps1 -Action Health` per plan; `-Action All` does not
  include it (read-only diagnostics, not a repair).
- Pester tests were updated/added but not executed locally — only PowerShell 3.4.0 (no Pester 5) is
  installed on this machine. Verified via parser + `PSScriptAnalyzer` (clean) instead; run
  `Invoke-Pester -Path tests/ -Output Minimal` in CI or with Pester 5 installed to confirm.
