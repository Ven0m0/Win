# 1. OBJECTIVE

Add comprehensive PowerShell linting and formatting as pre-commit hooks (pre-commit/prek compatible) and GitHub Actions workflows to ensure consistent code quality across all PowerShell scripts in the repository.

# 2. CONTEXT SUMMARY

**Repository:** Ven0m0/Win - Windows dotfiles and optimization suite
- 40+ PowerShell scripts (`.ps1`, `.psm1`, `.psd1`)
- Existing tools: PSScriptAnalyzer, PSScriptAnalyzerSettings.psd1, .editorconfig
- Existing CI: `powershell.yml` (PSScriptAnalyzer), `ps-format.yml` (format checks), `lint.yml` (needs updates)
- Current pre-commit config with Python/JS tooling, no PowerShell hooks yet

**Key constraints:**
- Windows and PowerShell 5.1+/7+ compatibility must be preserved
- Repo uses 2-space indentation, CRLF line endings, UTF-8 BOM, max 120 chars line length
- Existing PSScriptAnalyzer rules configured in `PSScriptAnalyzerSettings.psd1`

# 3. APPROACH OVERVIEW

1. **Pre-commit hooks:** Add local hooks for PSScriptAnalyzer (linting) and a formatter hook. Use PowerShell scripts invoked via local hooks since no native pre-commit PowerShell tool exists.

2. **GitHub Actions:** Consolidate and enhance existing workflows:
   - Update `powershell.yml` - ensure proper linting with SARIF
   - Create a unified `lint-format-test.yml` workflow combining lint, format, and tests
   - Maintain compatibility with Windows runners for full PowerShell functionality

3. **Formatting strategy:** Since no widely-adopted PowerShell formatter exists in pre-commit ecosystem, use PSScriptAnalyzer for linting + a simple formatting validation script that enforces repo standards (indent, whitespace, BOM).

# 4. IMPLEMENTATION STEPS

### Step 1: Create PowerShell formatting script for pre-commit
- **Goal:** Create a script that can format-check and auto-fix PowerShell files
- **Method:** Create `.github/scripts/Format-PowerShell.ps1` with:
  - Checks: 2-space indentation, no tabs, trailing whitespace, UTF-8 BOM, max line length
  - Output format compatible with pre-commit hook expectations
- **Reference:** `.editorconfig`, existing `ps-format.yml` workflow

### Step 2: Create PowerShell linting script for pre-commit
- **Goal:** Create a script that runs PSScriptAnalyzer as a pre-commit hook
- **Method:** Create `.github/scripts/Lint-PowerShell.ps1` that:
  - Runs PSScriptAnalyzer with repo settings
  - Outputs violations in a format pre-commit can understand
  - Returns non-zero exit code on violations
- **Reference:** `PSScriptAnalyzerSettings.psd1`, existing `powershell.yml`

### Step 3: Update pre-commit configuration
- **Goal:** Add PowerShell hooks to `.pre-commit-config.yaml`
- **Method:** Add local hooks for:
  - `psscriptanalyzer-lint` - runs Lint-PowerShell.ps1
  - `psscriptanalyzer-format` - runs Format-PowerShell.ps1 (check mode)
  - Files pattern: `**.ps1`, `**.psm1`, `**.psd1`
- **Reference:** Existing pre-commit hooks in config

### Step 4: Consolidate GitHub Actions workflows
- **Goal:** Create a unified, comprehensive CI workflow for PowerShell
- **Method:** 
  - Update `powershell.yml` to be more robust
  - Create `lint-format-test.yml` combining all checks (lint, format, tests)
  - Keep `powershell.yml` for SARIF security scanning
  - Remove/update `lint.yml` (references outdated `src` folder)
- **Reference:** Existing workflows, PSScriptAnalyzerAction

### Step 5: Create Pester test runner script
- **Goal:** Enable running Pester tests from pre-commit and CI
- **Method:** Create `.github/scripts/Test-PowerShell.ps1` that:
  - Finds and runs `*.Tests.ps1` files
  - Returns proper exit codes for CI integration
- **Reference:** Existing test files in `Scripts/*.Tests.ps1`

### Step 6: Add prek configuration (pre-commit compatible)
- **Goal:** Ensure hooks work with prek framework if needed
- **Method:** Verify local hooks use standard pre-commit interface (exit codes, stdout)
- **Reference:** pre-commit local hooks documentation

# 5. TESTING AND VALIDATION

### Pre-commit Hooks
- Run `pre-commit run --all-files psscriptanalyzer-lint` to verify linting
- Run `pre-commit run --all-files psscriptanalyzer-format` to verify formatting check
- Verify hooks exit with code 1 when violations exist
- Test with `pre-commit try-repo . --all-files` for local hooks

### GitHub Actions
- Trigger workflows on PR and push to main
- Verify SARIF upload in Security tab for `powershell.yml`
- Check workflow runs show:
  - Lint passing/failing correctly
  - Format violations detected
  - Tests running and passing
- Verify "Files changed" tab shows relevant status checks

### Code Quality
- Run `Invoke-ScriptAnalyzer` on modified scripts
- Verify no false positives for existing code patterns
- Ensure workflow concurrency settings prevent duplicate runs
