# Testing Rules

## Primary test tool: PSScriptAnalyzer

There is no automated unit test suite (no Pester tests for most scripts). The primary quality gate is static analysis via PSScriptAnalyzer, which runs in CI on every push and PR.

**Local lint check (run before every commit):**
```powershell
# Single file
Invoke-ScriptAnalyzer -Path Scripts/your-script.ps1

# All scripts
Invoke-ScriptAnalyzer -Path Scripts/ -Recurse

# Specific rules enforced by CI
Invoke-ScriptAnalyzer -Path Scripts/ -Recurse `
  -IncludeRule "PSAvoidGlobalAliases","PSAvoidUsingConvertToSecureStringWithPlainText"
```

## Manual testing protocol

Since scripts interact with live Windows registry and system settings, testing requires:

1. **Syntax check first**: `Invoke-ScriptAnalyzer` must return zero errors
2. **Run as admin**: `PowerShell.exe -ExecutionPolicy Bypass -File Scripts/your-script.ps1`
3. **Registry changes**: capture baseline with `Get-ItemProperty -Path "HKLM\..."` before running, verify the expected key/value after
4. **Restore verification**: always test the "Restore defaults" menu option — confirm it reverts to the baseline captured in step 3

## Existing test file

`Scripts/New-QueryString.Tests.ps1` — Pester test for the `New-QueryString` utility. If adding Pester tests, follow this file's pattern.

## CI gates (must not be broken)

| Workflow | Trigger | What it checks |
|---|---|---|
| `PSScriptAnalyzer` | push/PR to `main` | `PSAvoidGlobalAliases`, `PSAvoidUsingConvertToSecureStringWithPlainText` across entire repo |
| `PSMinifier` | push/PR touching `*.ps1`/`*.psm1` | Minification succeeds; auto-commits minified output on push to `main` |

## No mocking policy

Scripts that modify registry or system settings must be tested against a real Windows system — do not attempt to mock registry calls in Pester. The overhead of mocking `Set-ItemProperty` (via `Common.ps1`) is not worth the false confidence it provides for system-level scripts.

## Test coverage expectation

- All new `Common.ps1` utility functions: add a corresponding Pester test in `Scripts/New-QueryString.Tests.ps1` or a new `*.Tests.ps1` sibling
- Scripts with complex branching logic (Enable/Disable paths): manually test each branch
- Registry scripts: verify both the "apply" and "restore defaults" paths
