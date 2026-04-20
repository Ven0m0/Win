---
name: win-patterns
description: Repo-specific workflow guide for Win. Use when editing PowerShell scripts, tracked config, bootstrap logic, or Copilot guidance.
allowed-tools: 'Read, Glob, Grep, Bash'
---

# Win repository patterns

Load this skill when the task touches repository conventions or spans multiple repo areas.

## Hotspots

- `Scripts/` for PowerShell automation
- `Scripts/Common.ps1` for shared helpers
- `user/.dotfiles/config/` for tracked config and game assets
- `.yadm/bootstrap` and `Scripts/Setup-Dotfiles.ps1` for bootstrap behavior
- `.github/` for Copilot guidance and workflow metadata

## Common workflows

### PowerShell script changes

- Open the target script and `Scripts/Common.ps1` together.
- Preserve the existing admin elevation, strict mode, and environment-based path patterns.
- Prefer shared helpers over new one-off functions.
- Run `Invoke-ScriptAnalyzer -Path <changed-script>` after edits.

### Bootstrap changes

Review these files together:

- `.yadm/bootstrap`
- `Scripts/Setup-Dotfiles.ps1`
- `README.md`
- `AGENTS.md`

### Tracked config changes

- Keep new tracked config in `user/.dotfiles/config/`.
- Preserve the target application's native file format.
- If a script deploys the config, verify the deployment logic still points at the right source file.

### Guidance changes

- Keep `.github/copilot-instructions.md` short.
- Put broad repo rules in `AGENTS.md`.
- Put narrow rules in `.github/instructions/`.
- Put recurring workflows in `.github/skills/`.
- Run `npx -y @yawlabs/ctxlint --depth 3 --mcp --strict --yes` after guidance edits.

## Validation reminders

- Current CI runs PSScriptAnalyzer from `.github/workflows/powershell.yml`.
- CI currently enforces `PSAvoidGlobalAliases` and `PSAvoidUsingConvertToSecureStringWithPlainText`.
- The repo does not currently ship a committed Pester suite, so add tests only when the change justifies them.
