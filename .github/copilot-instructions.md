# GitHub Copilot Instructions

Ven0m0/Win is a Windows dotfiles repository managed with [dotbot](https://github.com/anishathalye/dotbot).
Start with `AGENTS.md` for repo-wide guidance, then load only the instruction files and skills needed for the current task.

Load these only when relevant:

- `.kilo/skills/win-patterns/SKILL.md` for cross-cutting repo workflow context
- `.kilo/skills/bootstrap-deployment/SKILL.md` for bootstrap entry points and deployment changes

Keep these guardrails in mind:

- Reuse `Scripts/Common.ps1` before adding new helpers.
- Keep tracked config under `user/.dotfiles/config/`.
- Review `install.conf.yaml` and `Scripts/Setup-Dotfiles.ps1` together for bootstrap changes.
- Preserve Windows and PowerShell 5.1+/7+ compatibility and environment-based paths.
- Prefer reversible registry or system changes.

Fresh Windows 11 bootstrap entry point:

```powershell
iwr https://raw.githubusercontent.com/Ven0m0/Win/main/bootstrap.ps1 -UseBasicParsing | iex
```
