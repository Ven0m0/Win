# GitHub Copilot Instructions

Ven0m0/Win is a Windows dotfiles repository managed with [yadm](https://yadm.io/).
Start with `AGENTS.md` for repo-wide guidance, then load only the instruction files and skills needed for the current task.

Focus on these areas:

- `Scripts/` for PowerShell automation; reuse `Scripts/Common.ps1`.
- `user/.dotfiles/config/` for tracked configuration files.
- `.yadm/bootstrap` and `Scripts/Setup-Dotfiles.ps1` for bootstrap behavior.
- `.github/` files should stay concise and repository-specific.

Guardrails:

- Preserve Windows and PowerShell 5.1+/7+ compatibility.
- Use environment-based paths instead of machine-specific paths.
- Prefer reversible registry or system changes.
- Keep new tracked config under `user/.dotfiles/config/`.
- Validate changed PowerShell files with `Invoke-ScriptAnalyzer -Path <file>`.

Load `.github/skills/win-patterns/SKILL.md` when you need deeper repo workflow context.
