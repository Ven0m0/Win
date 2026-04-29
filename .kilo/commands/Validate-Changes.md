# Validate-Changes

**Category:** Validation / CI
**Scope:** Run repository validation checks pre-commit

## Synopsis

Comprehensive validation command that runs CI-like checks on local changes: PSScriptAnalyzer on PowerShell files, autounattend.xml XML validation, and `ctxlint` on `.github/` guidance files.

## Description

This workflow command aggregates all repository validation steps:

1. **PowerShell linting** — `Invoke-ScriptAnalyzer` on changed `.ps1`/`.psm1`/`.psd1` files using `PSScriptAnalyzerSettings.psd1`
2. **autounattend.xml** — validates XML syntax and checks for `ExtractScript` blocks
3. **Guidance linting** — runs `@yawlabs/ctxlint` on `.github/instructions/`, `.github/skills/`, `.github/workflows/`

Use before committing to catch issues early.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-All` | Switch | False | Run all validation checks (default behavior) |
| `-PowerShellOnly` | Switch | False | Only validate PowerShell scripts |
| `-GuidanceOnly` | Switch | False | Only validate `.github/` guidance files |
| `-AutounattendOnly` | Switch | False | Only validate `Scripts/auto/autounattend.xml` |
| `-SkipAnalyzer` | Switch | False | Skip PSScriptAnalyzer checks |

## Usage

```powershell
# Run all checks
.\Validate-Changes.ps1

# Only check PowerShell files
.\Validate-Changes.ps1 -PowerShellOnly

# Only lint guidance files
.\Validate-Changes.ps1 -GuidanceOnly

# Validate autounattend.xml
.\Validate-Changes.ps1 -AutounattendOnly

# Skip analyzer (guidance-only review)
.\Validate-Changes.ps1 -GuidanceOnly -SkipAnalyzer
```

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | All checks passed |
| `1` | One or more validation failures |

## Notes

- The real script is `Scripts/Validate-Changes.ps1`; this `.md` is Kilo command documentation.
- CI enforces `PSAvoidGlobalAliases` and `PSAvoidUsingConvertToSecureStringWithPlainText`.
- Install `ctxlint` globally for guidance checks: `npm i -g @yawlabs/ctxlint`

## Related

- `Invoke-ScriptAnalyzer.ps1` — focused PowerShell linting
- `PSScriptAnalyzerSettings.psd1` — analyzer rules configuration
- `.github/workflows/powershell.yml` — CI workflow
