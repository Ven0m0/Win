# GitHub Copilot Instructions

Ven0m0/Win is a Windows dotfiles repository managed with [dotbot](https://github.com/anishathalye/dotbot).
Start with `AGENTS.md` for repo-wide guidance, then load only the instruction files and skills needed for the current task.

**New in 2025:** One-command fresh Windows 11 setup:
```powershell
iwr https://raw.githubusercontent.com/Ven0m0/Win/main/.github/scripts/bootstrap.ps1 -UseBasicParsing | iex
```

Focus on these areas:

- `Scripts/` for PowerShell automation; reuse `Scripts/Common.ps1`.
- `user/.dotfiles/config/` for tracked configuration files.
- `install.conf.yaml` (dotbot config) and `Scripts/Setup-Dotfiles.ps1` for bootstrap behavior.
- `Scripts/Setup-Win11.ps1` and `.github/scripts/bootstrap.ps1` for fresh-install automation.
- `.github/` files should stay concise and repository-specific.

Guardrails:

- Preserve Windows and PowerShell 5.1+/7+ compatibility.
- Use environment-based paths instead of machine-specific paths.
- Prefer reversible registry or system changes.
- Keep new tracked config under `user/.dotfiles/config/`.
- Validate changed PowerShell files with `Invoke-ScriptAnalyzer -Path <file>`.

Load `.github/skills/win-patterns/SKILL.md` for deeper repo workflow context, and `.kilo/rules/bootstrap-deployment.md` for Windows 11 setup patterns.
