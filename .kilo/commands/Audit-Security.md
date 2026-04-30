# Audit-Security

**Category:** Validation / Security
**Scope:** Repository security audit workflow

## Synopsis

Run security checks across the repository to detect credentials, hardcoded paths, unsafe elevation patterns, and improper registry access.

## Description

This workflow command performs a structured security audit of the dotfiles repository:

1. **Credential scan** — Search for potential secrets, API keys, tokens, and passwords in scripts and config files using keyword patterns
2. **Hardcoded path check** — Detect absolute user paths (e.g., `C:\Users\...`) that should use `$HOME` or `$env:USERPROFILE`
3. **Elevation pattern validation** — Verify admin elevation uses `Request-AdminElevation` from `Common.ps1` and avoid unsafe patterns
4. **Registry access review** — Ensure registry modifications use `Set-RegistryValue`/`Remove-RegistryValue` helpers, create restore points, and avoid sensitive keys
5. **Sensitive key audit** — Flag references to `HKLM\SECURITY`, `HKLM\SAM`, `HKLM\SYSTEM\...\Lsa`, and other restricted hives

## Steps

```bash
# 1. Scan for credentials and secrets
grep -riE '(password|api_key|token|secret|credential)\s*=' Scripts/ user/

# 2. Check for hardcoded user paths
grep -riE 'C:\\Users\\[^$]' Scripts/ user/

# 3. Validate elevation patterns
grep -ri 'Request-AdminElevation' Scripts/
grep -ri 'IsInRole.*Administrator' Scripts/

# 4. Review registry access patterns
grep -riE 'Set-ItemProperty|Remove-ItemProperty' Scripts/
grep -ri 'Set-RegistryValue\|Remove-RegistryValue' Scripts/

# 5. Check for sensitive registry keys
grep -riE 'HKLM.\\(SECURITY|SAM)' Scripts/
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Path` | String | `'.'` | Repository root to audit |
| `-OutputFile` | String | `'./security-audit.md'` | Path for the audit report |
| `-Strict` | Switch | False | Fail on warnings as well as errors |

## Usage

```powershell
# Full repository audit
.\Audit-Security.ps1

# Audit specific directory
.\Audit-Security.ps1 -Path Scripts/

# Strict mode (fail on warnings)
.\Audit-Security.ps1 -Strict

# Custom report path
.\Audit-Security.ps1 -OutputFile ./reports/security.md
```

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | No security issues found |
| `1` | Security issues detected |
| `2` | Audit execution error |

## Notes

- This markdown file is Kilo command reference only. Implement as `Scripts/Audit-Security.ps1` if needed.
- Use `grep`, `read`, and LSP tools during interactive Kilo sessions to perform these checks.
- The expected output is a markdown security report with severity classifications.
- Review `AGENTS.md` "Sensitive Content" section for the repository security baseline.

## Related

- `Scripts/Common.ps1` — elevation and registry helpers
- `.kilo/rules/registry-security.md` — registry safety rules
- `.kilo/rules/powershell.md` — PowerShell security patterns
- `Validate-Changes.md` — broader validation workflow
