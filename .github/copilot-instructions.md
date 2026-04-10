# GitHub Copilot Instructions

Ven0m0/Win is a **Windows dotfiles and optimization repository** managed with [yadm](https://yadm.io/). It contains PowerShell automation, Windows configuration, registry tweaks, and gaming/performance tuning assets for Windows machines.

Use these repository-wide rules for every task:

- Reuse `Scripts/Common.ps1` for shared PowerShell behavior; do not duplicate helpers.
- Keep tracked configuration in `user/.dotfiles/config/`; do not introduce new content under deprecated `.config/` paths.
- Preserve Windows and PowerShell 5.1+/7+ compatibility.
- Use `$PSScriptRoot`, `$HOME`, `$env:*`, and other environment-based paths instead of hardcoded machine-specific paths.
- Prefer reversible registry and system changes when modifying user-visible behavior.
- Follow the file-type guidance in `.github/instructions/` for PowerShell, CMD/Batch, AutoHotkey, and general context rules.
- For setup/bootstrap changes, review `.yadm/bootstrap`, `Scripts/Setup-Dotfiles.ps1`, and related docs together.

When editing common areas:

- `Scripts/*.ps1`: keep the existing admin/elevation pattern, use `Scripts/Common.ps1`, and match the established PowerShell style.
- `user/.dotfiles/config/**`: preserve the target application's native format and existing directory layout.
- `.github/**`: keep instructions concise, repository-specific, and complementary rather than duplicating path-specific guidance.

Validation:

- Run `Invoke-ScriptAnalyzer -Path <changed-script>` for changed PowerShell files.
- Use existing Pester tests when the affected area already has tests or when adding new testable PowerShell logic.
- Documentation-only changes usually only need a careful diff review.

See `AGENTS.md` at the repository root for the full AI workflow and repository guide.
