---
name: validation
description: |
  Per-change-type validation matrix for PowerShell, dotbot, autounattend.xml, and guidance files.
  Use proactively after any change to run the narrowest applicable checks.
compatibility: opencode
---

# Validation Skill for Win Dotfiles

Use this skill when you need to validate changes in the Ven0m0/Win repository. Run only the checks that match the files you changed.

## Identify Changed Area

- `Scripts/**/*.ps1`, `*.psm1`, `*.psd1` or standalone `setup.ps1`
- `user/.dotfiles/config/**` — tracked configuration
- `install.conf.yaml`, `Scripts/Setup-Dotfiles.ps1`, `README.md`
- `.github/` — workflows, instructions, skills
- `Scripts/auto/autounattend.xml`

## Relevant Checks Per Change Type

### PowerShell Changes

For every changed PowerShell file:

```bash
cd /path/to/repo
pwsh -NoLogo -NoProfile -Command "Invoke-ScriptAnalyzer -Path '<changed-script>' -Settings './PSScriptAnalyzerSettings.psd1'"
```

CI enforces `PSAvoidGlobalAliases` and `PSAvoidUsingConvertToSecureStringWithPlainText`.

### Bootstrap or Tracked Config Changes

When `install.conf.yaml` or `Scripts/Setup-Dotfiles.ps1` changes:
- Verify referenced source and destination paths exist in the repo
- Check that hash-based deployment logic still correctly computes SHA256
- Review `README.md` and `AGENTS.md` for consistency (setup instructions should match)
- If deployment PowerShell logic changed, run ScriptAnalyzer on those scripts

When a file under `user/.dotfiles/config/` changes:
- Confirm native application file format preserved (no cosmetic re-serialization)
- If a deployment script references it, verify the manifest entry still points at the correct source path

### autounattend.xml Changes

After any edit to `Scripts/auto/autounattend.xml`:

```powershell
$xml = [xml]::new(); $xml.Load('Scripts/auto/autounattend.xml')
```

Also verify:
- All embedded `<File path="...">` scripts inside `<Extensions>` use XML entity encoding (`&amp;`, `&gt;`, etc.)
- `ExtractScript` paths resolve to `C:\Windows\Setup\Scripts\` at runtime
- Execution order: specialize → FirstLogon → install.ps1 → stage2.ps1 → WinUtil RunOnce matches expectations

### Guidance or Workflow Changes Under `.github/`

After editing any file in `.github/`:
- Verify every referenced path and command exists in the repo
- Run repository context lint:

```bash
npx -y @yawlabs/ctxlint --depth 3 --mcp --strict --yes
```

Use `--fix` only if the task explicitly asks for autofix. Keep `.github/copilot-instructions.md` short; broad rules belong in `AGENTS.md`.

### Pester Tests

Run `Invoke-Pester -Path Scripts/ -Output Minimal` **only** when:
- Tests already exist for the affected area, OR
- You are adding new testable PowerShell logic

Do not invent or widen test scope solely to satisfy validation.

## Invariants

- Never skip a relevant check to make a change look green
- Fix issues only in the files you changed
- Re-run the affected check before reporting success
- Call out pre-existing failures unrelated to your changes

## Quick Reference Matrix

| Area Changed | Primary Check | Secondary Checks |
|---|---|---|
| Any `.ps1` | `Invoke-ScriptAnalyzer` | — |
| `install.conf.yaml` | Path resolution, hash logic | `README.md` consistency |
| `Setup-Dotfiles.ps1` | ScriptAnalyzer, hash deployment | Config paths review |
| `user/.dotfiles/config/*` | Format preservation | Deployment manifest |
| `Scripts/auto/autounattend.xml` | XML validate, entity encoding | Script embed review |
| `.github/instructions/*` | Path/command verification | `ctxlint` |
| `.github/skills/*` | Skill references valid? | — |
| `.github/workflows/*` | YAML syntax, tool availability | — |
