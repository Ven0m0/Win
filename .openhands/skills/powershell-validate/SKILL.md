# PowerShell Script Validation Skill

Validates PowerShell scripts using PSScriptAnalyzer with repository-specific settings.

## Purpose

This skill provides a standardized way to validate PowerShell scripts in the Ven0m0/Win repository, ensuring they meet the coding standards defined in `PSScriptAnalyzerSettings.psd1`.

## Usage

```bash
# Validate specific files
pwsh -NoProfile -File .github/scripts/Lint-PowerShell.ps1 -Files @("Scripts/test.ps1")

# Validate from git diff (pre-commit style)
git diff --name-only | pwsh -NoProfile -File .github/scripts/Lint-PowerShell.ps1 -CheckMode

# Check mode for CI
pwsh -NoProfile -File .github/scripts/Lint-PowerShell.ps1 -CheckMode -Severity Error
```

## Validation Rules

The repository enforces these PSScriptAnalyzer rules:

| Rule | Severity | Description |
|------|----------|-------------|
| PSAvoidGlobalAliases | Error | Avoid using global aliases like `cd`, `sl`, etc. |
| PSAvoidUsingConvertToSecureStringWithPlainText | Error | SecureString conversion without plain text |
| PSAvoidUsingCmdletAliases | Warning | Prefer full cmdlet names over aliases |
| PSAvoidUsingEmptyCatchBlock | Error | Empty catch blocks mask errors |
| PSAvoidUsingPositionalParameters | Warning | Use named parameters for clarity |

## Workflow

### 1. Get Changed Files

```bash
git diff --name-only HEAD~1 -- '*.ps1'
```

### 2. Validate Each Script

```bash
Invoke-ScriptAnalyzer -Path "<script-path>" -Settings PSScriptAnalyzerSettings.psd1
```

### 3. Categorize Issues

**Auto-fixable:**
- Aliases (`%`→`ForEach-Object`, `?`→`Where-Object`)
- Trailing whitespace
- Inconsistent line endings

**Manual review required:**
- `Invoke-Expression` usage
- Global error suppression
- Complex logic issues

### 4. Apply Fixes (with care)

When auto-fixing:
1. Read file content
2. Replace only the specific issue line
3. Never modify content inside strings or script blocks
4. Preserve script behavior

## Related Files

- `PSScriptAnalyzerSettings.psd1` - Repository-specific PSScriptAnalyzer settings
- `.github/scripts/Lint-PowerShell.ps1` - Linting script
- `.github/scripts/Test-PowerShell.ps1` - Pester test runner
