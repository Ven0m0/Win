# Review-Code

**Category:** Validation / Review
**Scope:** Structured code review for PowerShell changes

## Synopsis

Perform a structured code review on PowerShell script changes, checking analyzer results, Common.ps1 helper usage, ShouldProcess support, and error handling patterns.

## Description

This workflow command runs a comprehensive code review focused on the repository's PowerShell scripts:

1. **PSScriptAnalyzer** — Run `Invoke-ScriptAnalyzer` with `PSScriptAnalyzerSettings.psd1` to catch CI violations
2. **Common.ps1 usage** — Verify that scripts reuse existing helpers (`Set-RegistryValue`, `New-RestorePoint`, etc.) instead of duplicating logic
3. **ShouldProcess verification** — Confirm system-modifying functions use `[CmdletBinding(SupportsShouldProcess)]` and wrap changes in `$PSCmdlet.ShouldProcess`
4. **Error handling review** — Check for `Set-StrictMode`, `$ErrorActionPreference = 'Stop'`, and absence of global `SilentlyContinue`
5. **Style compliance** — Validate full cmdlet names (no aliases), comment-based help, and approved verb-noun function names

## Steps

```powershell
# 1. Run PSScriptAnalyzer
Invoke-ScriptAnalyzer -Path Scripts/<changed>.ps1 -Settings PSScriptAnalyzerSettings.psd1

# 2. Check Common.ps1 helper usage
grep -ri 'Set-RegistryValue\|Remove-RegistryValue\|New-RestorePoint\|Get-NvidiaGpuRegistryPaths' Scripts/<changed>.ps1

# 3. Verify ShouldProcess support
grep -ri 'SupportsShouldProcess' Scripts/<changed>.ps1
grep -ri 'ShouldProcess' Scripts/<changed>.ps1

# 4. Review error handling
grep -ri 'Set-StrictMode' Scripts/<changed>.ps1
grep -ri 'ErrorActionPreference' Scripts/<changed>.ps1

# 5. Check for prohibited patterns
grep -riE 'Invoke-Expression|SilentlyContinue.*global|ConvertTo-SecureString.*PlainText' Scripts/<changed>.ps1
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Path` | String | `'Scripts/'` | File or directory to review |
| `-ChangedOnly` | Switch | False | Review only git-modified files |
| `-Severity` | String | `'Warning'` | Minimum severity to report: `'Information'`, `'Warning'`, `'Error'` |
| `-ExportReport` | Switch | False | Save review comments as markdown |

## Usage

```powershell
# Review a specific script
.\Review-Code.ps1 -Path Scripts/Setup-Dotfiles.ps1

# Review all changed files
.\Review-Code.ps1 -ChangedOnly

# Error-only review with report export
.\Review-Code.ps1 -Severity Error -ExportReport

# Full directory review
.\Review-Code.ps1 -Path Scripts/
```

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Review passed with no issues |
| `1` | Issues found at or above the specified severity |

## Notes

- This markdown file is Kilo command reference only. Implement as `Scripts/Review-Code.ps1` if needed.
- Expected output is a set of review comments with severity levels (`Critical`, `Warning`, `Suggestion`).
- Always review against the rules in `.kilo/rules/powershell.md`.

## Related

- `Invoke-ScriptAnalyzer.md` — focused analyzer workflow
- `Scripts/Common.ps1` — shared helper library
- `.kilo/rules/powershell.md` — PowerShell coding rules
- `Validate-Changes.md` — pre-commit validation
