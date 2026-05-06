# Implementation Plan: TODO.md Tasks

## Overview

This plan converts TODO.md items into an execution-ready implementation roadmap for the Ven0m0/Win PowerShell dotfiles repository. The work spans parser error fixes, CI workflow improvements, PowerShell module integrations, and code quality enhancements.

## Assumptions

- Repository targets PowerShell 5.1+ and PowerShell 7+
- CI runs on ubuntu-latest with PowerShell/Pester available
- PSScriptAnalyzer settings are defined in `PSScriptAnalyzerSettings.psd1`
- All scripts must pass ScriptAnalyzer with no errors (warnings acceptable per config)
- Existing test structure uses Pester (26 test files in `tests/`)

## Phase 1: Critical Parser Error Fixes (Priority: P0)

**Goal:** Fix syntax errors preventing script execution.

### Task 1.1: Fix SkipVideosMod.ps1 Parser Error
- **File:** `Scripts/arc-raiders/SkipVideosMod.ps1`
- **Issue:** Line 34 - "An empty pipe element is not allowed"
- **Root Cause:** Line continuation with backtick followed by pipe `|` creates empty pipeline element
- **Fix:** Remove backtick continuation or restructure the pipeline
- **Code Reference:**
  ```powershell
  # Current (broken):
  $steamPath = Get-ItemProperty 'HKLM:\Software\Wow6432Node\Valve\Steam' `
      -Name InstallPath -ErrorAction Stop |

  # Fix options:
  # Option A: Remove backtick, keep on one line
  $steamPath = Get-ItemProperty 'HKLM:\Software\Wow6432Node\Valve\Steam' -Name InstallPath -ErrorAction Stop

  # Option B: Use splatting
  $params = @{ Path = 'HKLM:\Software\Wow6432Node\Valve\Steam'; Name = 'InstallPath'; ErrorAction = 'Stop' }
  $steamPath = Get-ItemProperty @params
  ```
- **Validation:** `pwsh -Command "Get-Command Scripts/arc-raiders/SkipVideosMod.ps1"` should succeed

### Task 1.2: Fix Network-Tweaker.ps1 Parser Error
- **File:** `Scripts/Network-Tweaker.ps1`
- **Issue:** Line 2396 - "Unexpected token 'Path' in expression or statement"
- **Root Cause:** Missing closing quote on string at line 2395: `$KeyPath = "HKLM:\SYSTEM\...` is truncated
- **Fix:** Complete the string literal properly
- **Code Reference:** Line 2395 shows `$AdapterDevic` (truncated), needs closing "
- **Validation:** `pwsh -Command "Get-Command Scripts/Network-Tweaker.ps1"` should succeed

### Task 1.3: Verify Parser Fixes
- Run `pwsh -Command "Get-ChildItem Scripts/*.ps1, Scripts/*/*.ps1 | ForEach-Object { Get-Command $_.FullName }"`
- Ensure no parser errors across all scripts

## Phase 2: PSScriptAnalyzer Compliance (Priority: P0)

**Goal:** Ensure all scripts pass PSScriptAnalyzer with no errors.

### Task 2.1: Run Full Analyzer Scan
- **Command:** `Invoke-ScriptAnalyzer -Path Scripts/ -Settings PSScriptAnalyzerSettings.psd1 -Recurse`
- **Output:** Capture all Error-level findings

### Task 2.2: Fix Analyzer Errors
- Address each Error severity finding
- Common expected issues:
  - `PSAvoidGlobalAliases` - Replace aliases with full cmdlet names
  - `PSAvoidUsingInvokeExpression` - Refactor to safer alternatives
  - `PSUseApprovedVerbs` - Rename functions using unapproved verbs
  - `PSReservedCmdletChar` - Fix function names with reserved characters

### Task 2.3: Update powershell.yml Workflow
- **File:** `.github/workflows/powershell.yml`
- **Current State:** Uses both `py-psscriptanalyzer` and legacy `microsoft/psscriptanalyzer-action`
- **Required Changes:**
  1. Ensure both analyzers use `PSScriptAnalyzerSettings.psd1`
  2. Make the workflow fail on errors (remove `continue-on-error: true` or gate it)
  3. Consider adding Pester test execution step
- **Validation:** CI should fail if new analyzer errors are introduced

## Phase 3: PowerShell Module Integration (Priority: P1)

**Goal:** Add and integrate recommended PowerShell modules.

### Task 3.1: Add PSIni Module Support
- **Purpose:** For INI file modifications (game configs, settings)
- **Action:** Add to `Scripts/Install-Packages.ps1` or bootstrap process
- **Usage Pattern:**
  ```powershell
  Install-Module -Name PSIni -Scope CurrentUser -Force
  Import-Module PSIni
  $ini = Get-IniContent -FilePath "config.ini"
  $ini["Section"]["Key"] = "Value"
  $ini | Out-IniFile -FilePath "config.ini" -Force
  ```
- **Files to Update:**
  - `Scripts/Install-Packages.ps1` - Add PSIni to module installation list
  - `Scripts/Common.ps1` - Consider adding helper functions for INI operations

### Task 3.2: Add Pester Module (Explicit)
- **Purpose:** Unit testing framework (already in use, make explicit)
- **Action:** Ensure Pester is in the module installation list
- **Files to Update:** `Scripts/Install-Packages.ps1`

### Task 3.3: Add PowerShell-Beautifier Module
- **Purpose:** Code formatting for PS1 files
- **Action:**
  - Add to `Scripts/Install-Packages.ps1`
  - Create formatting script or integrate into CI
- **Usage:** `Install-Module -Name PowerShell-Beautifier`
- **CI Integration:** Consider adding format check to `ps-format.yml`

### Task 3.4: Evaluate PSParallel Module
- **Purpose:** Bulk operations parallelization
- **Action:** Evaluate if any scripts would benefit from parallel execution
- **Candidate Scripts:** `Scripts/debloat-windows.ps1`, `Scripts/Fix-WindowsUpdates.ps1`
- **Decision:** Add only if concrete use case identified

### Task 3.5: Evaluate Refactor Module
- **Purpose:** Rename functions/commands across multiple files
- **Action:** Document usage in `AGENTS.md` or dev docs
- **Note:** This is a development tool, not a runtime dependency

## Phase 4: CI Workflow Enhancements (Priority: P1)

**Goal:** Add unit test workflow inspired by winutil.

### Task 4.1: Study winutil Unittests Workflow
- **Reference:** https://github.com/ChrisTitusTech/winutil/blob/main/.github/workflows/unittests.yaml
- **Key Elements to Port:**
  - Pester test discovery and execution
  - Code coverage reporting
  - Test result publishing

### Task 4.2: Create/Update Unit Test Workflow
- **File:** `.github/workflows/lint-format-test.yml` (extend) or new `unittests.yml`
- **Add Steps:**
  1. Install Pester module
  2. Run `Invoke-Pester -Path tests/ -Output Detailed`
  3. Publish test results
  4. (Optional) Generate and publish code coverage
- **Validation:** Tests should run on every PS1 change

### Task 4.3: Ensure Test Coverage for Fixed Scripts
- **Files:** `tests/SkipVideosMod.Tests.ps1`, `tests/Network-Tweaker.Tests.ps1`
- **Action:** Verify tests exist and pass after parser fixes
- **Command:** `Invoke-Pester -Path tests/SkipVideosMod.Tests.ps1, tests/Network-Tweaker.Tests.ps1`

## Phase 5: External Tool Integration (Priority: P2)

**Goal:** Evaluate and integrate external tools.

### Task 5.1: Evaluate Winrift Integration
- **Reference:** https://github.com/emylfy/Winrift
- **Purpose:** Windows optimization/tweaking tool
- **Action:**
  - Review Winrift functionality
  - Determine if features overlap with existing scripts
  - Decide: integrate as dependency, borrow patterns, or skip
- **Documentation:** Add findings to `AGENTS.md` or create `docs/external-tools.md`

### Task 5.2: DISM Command Documentation
- **Command:** `dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase /RestoreHealth`
- **Action:**
  - Add to `Scripts/additional-maintenance.ps1` or create new maintenance script
  - Document when to use (system corruption, update issues)
  - Add warning about execution time and reboot requirements

## Dependencies & Order

```
Phase 1 (Parser Fixes)
    |
    v
Phase 2 (Analyzer Compliance) <- Depends on Phase 1 (scripts must parse to analyze)
    |
    v
Phase 3 (Module Integration) <- Can parallel with Phase 2 after Task 1.x complete
    |
    v
Phase 4 (CI Enhancements) <- Depends on Phase 2 (clean baseline needed)
    |
    v
Phase 5 (External Tools) <- Lowest priority, research-only
```

## Validation Checklist

- [ ] All scripts parse without errors (`Get-Command` test)
- [ ] PSScriptAnalyzer reports zero errors (`Invoke-ScriptAnalyzer`)
- [ ] CI workflow fails on analyzer errors
- [ ] All 26 Pester tests pass (`Invoke-Pester -Path tests/`)
- [ ] PSIni module installs and basic INI operations work
- [ ] PowerShell-Beautifier installs and formats a test file
- [ ] `Scripts/arc-raiders/SkipVideosMod.ps1` executes without parser error
- [ ] `Scripts/Network-Tweaker.ps1` executes without parser error

## Open Questions / Blockers

1. **Network-Tweaker.ps1 Scope:** File is 240KB+ with 4200+ lines. Is this a generated file or manually maintained? Large files may need modularization.

2. **PSScriptAnalyzer Severity:** Current settings use `Severity = 'Warning'`. Should this be tightened to `'Error'` for CI gating?

3. **Winrift Integration Depth:** Is the goal to vendor Winrift, add it as a git submodule, or just document it as a reference?

4. **PowerShell-Beautifier in CI:** Should formatting be enforced (fail CI on unformatted code) or just checked?

5. **Parallel Processing:** Are there specific scripts with performance bottlenecks that justify PSParallel complexity?

## File References

| File | Purpose | Phase |
|------|---------|-------|
| `Scripts/arc-raiders/SkipVideosMod.ps1` | Arc Raiders mod - parser fix needed | 1.1 |
| `Scripts/Network-Tweaker.ps1` | Network tweaking - parser fix needed | 1.2 |
| `PSScriptAnalyzerSettings.psd1` | Analyzer configuration | 2.x |
| `.github/workflows/powershell.yml` | Main analyzer workflow | 2.3 |
| `.github/workflows/lint-format-test.yml` | Lint/format/test workflow | 4.2 |
| `Scripts/Install-Packages.ps1` | Package/module installation | 3.x |
| `Scripts/Common.ps1` | Shared helper functions | 3.1 |
| `tests/*.Tests.ps1` | Pester test files | 4.3 |
| `Scripts/additional-maintenance.ps1` | Maintenance commands | 5.2 |
