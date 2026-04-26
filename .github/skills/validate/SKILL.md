---
name: validate
description: Run the narrowest checks for Win repository changes across PowerShell, tracked config, bootstrap files, and Copilot guidance.
allowed-tools: 'Read, Bash, Grep, Glob'
---

# Validate

Run only the checks that match the files you changed.

## Identify the changed area

- `Scripts/**/*.ps1`, `*.psm1`, `*.psd1`, or `setup.ps1`
- `user/.dotfiles/config/**`
- `install.conf.yaml`, `Scripts/Setup-Dotfiles.ps1`, or `README.md`
- `.github/` workflows, instructions, or skills

## Relevant checks

### PowerShell changes

Run ScriptAnalyzer on each changed PowerShell file:

```bash
cd /path/to/repo
pwsh -NoLogo -NoProfile -Command "Invoke-ScriptAnalyzer -Path '<changed-script>' -Settings './PSScriptAnalyzerSettings.psd1'"
```

### Bootstrap or tracked config changes

- Verify the referenced source and destination paths exist.
- If the change also touches PowerShell deployment logic, run ScriptAnalyzer on the changed script files.
- Review `install.conf.yaml`, `Scripts/Setup-Dotfiles.ps1`, and the affected docs together.

### Guidance or workflow changes under `.github/`

- Verify every referenced path and command exists.
- Run:

```bash
npx -y @yawlabs/ctxlint --depth 3 --mcp --strict --yes
```

- Use `--fix` only when the task explicitly asks for autofix.

### Pester

- Run `Invoke-Pester -Path Scripts/ -Output Minimal` only when tests exist for the changed area or when you add new tests.
- Do not invent or widen test scope just to satisfy the skill.

## Invariants

- Never skip a relevant check to make a change look green.
- Fix issues in the changed files only.
- Re-run the affected check before reporting success.
- Call out pre-existing failures that are unrelated to your changes.
