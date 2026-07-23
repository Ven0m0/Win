# Invoke-ScriptAnalyzer

**Category:** Validation / Linting
**Scope:** PowerShell script analysis

## Synopsis

Run PSScriptAnalyzer on PowerShell scripts with the repository's project-specific settings. Enforces CI rules and can auto-fix certain issues.

## Description

This command wraps `Invoke-ScriptAnalyzer` with the repo's `PSScriptAnalyzerSettings.psd1`. It supports:

- **Full scan** — analyze entire `Scripts/` directory
- **Changed files** — auto-detect modified scripts via `git diff`
- **Staged only** — only analyze staged changes (`git diff --cached`)
- **Single file** — target a specific script
- **Auto-fix** — attempt to fix fixable issues (`-Fix`)
- **Report export** — JSON report of all findings (`-ExportReport`)

Current CI-enforced rules: `PSAvoidGlobalAliases`, `PSAvoidUsingConvertToSecureStringWithPlainText`.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Path` | String | `'Scripts'` | File or directory to analyze |
| `-ChangedOnly` | Switch | False | Only analyze files modified in git working tree |
| `-UncommittedOnly` | Switch | False | Only analyze staged but uncommitted changes |
| `-Fix` | Switch | False | Attempt to auto-fix fixable issues (review before commit) |
| `-ExportReport` | Switch | False | Save detailed findings as JSON |
| `-OutputFile` | String | `./psa-report.json` | Path for exported report |

## Usage

```powershell
# Full scan of Scripts/
.\Invoke-ScriptAnalyzer.ps1

# Only changed files
.\Invoke-ScriptAnalyzer.ps1 -ChangedOnly

# Specific script with auto-fix
.\Invoke-ScriptAnalyzer.ps1 -Path Scripts/Setup-Dotfiles.ps1 -Fix

# Export JSON report
.\Invoke-ScriptAnalyzer.ps1 -ExportReport -OutputFile ./lint-report.json
```

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | All scripts pass |
| `1` | One or more issues found |

## Notes

- The actual script lives in `Scripts/Invoke-ScriptAnalyzer.ps1`.
- This `.md` file is Kilo command reference only.
- Run locally before committing: `Invoke-ScriptAnalyzer -Path <script> -Settings ./PSScriptAnalyzerSettings.psd1`

## Related

- `PSScriptAnalyzerSettings.psd1` — rule configuration
- `Validate-Changes.ps1` — broader validation (includes XML, guidance lint)
- `.github/workflows/powershell.yml` — CI workflow
