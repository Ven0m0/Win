# PLAN.md — Ven0m0/Win Repository Audit

Audit date: 2026-05-03
Scope: Full repository audit for code quality, architecture, production readiness, and maintainability.

---

## Summary

This repository (Ven0m0/Win) provides PowerShell-based Windows customization and optimization automation, primarily via free-standing `.ps1` scripts, tracked config files (dotfiles), and `dotbot` orchestration. Key scripts include the bootstrap pipeline, arc-raiders game utilities, and numerous optimization scripts (debloat, settings, network, storage, system updates). The repo has thoughtful guardrails (`Common.ps1`, CI, and AGENTS.md-level rules), but the current state has notable concerns around unwieldy script sizes, scattered error handling, test coverage gaps, security-level registry tweaks, and inconsistent PS practices (e.g., `-WhatIf` support, `Write-Host`).

**Existing TODOs/FIXMEs**: None found in code comments. No prior `PLAN.md` existed. The audit below is entirely newly identified.

---

## Newly Identified Tasks

---

### Critical

#### C1. `RegistryTweaks10.reg` unconditionally disables UAC (`EnableLUA=0`)
- **Rationale**: Disabling UAC (`HKLM\...\Policies\System\EnableLUA = 0`) is a high-risk security change delivered as a silent `.reg` import with no warning or opt-out. This can break elevation expectations across the system and reduce the security posture significantly.
- **Scope**: `Scripts/reg/RegistryTweaks10.reg` (and any callers such as dotbot manifests or `Setup-Dotfiles.ps1` references).
- **Priority**: Critical
- **Effort**: Small

#### C2. Global `$ErrorActionPreference = 'SilentlyContinue'` in 3 scripts
- **Rationale**: Three scripts set the global error preference to `SilentlyContinue`, which masks all failures and makes debugging extremely difficult. This is a prohibited pattern per repo rules (`registry-security.md` / `powershell.md`).
  - `Scripts/arc-raiders/ARCRaidersUtility.ps1` (line ~26)
  - `Scripts/Network-Tweaker.ps1` (lines ~2255, ~2383)
  - `Scripts/UltimateDiskCleanup.ps1` (line ~18)
- **Scope**: Replace with `-ErrorAction SilentlyContinue` on specific cmdlets only, or wrap risky sections in `try/catch` that log instead of silently discarding.
- **Priority**: Critical
- **Effort**: Small

#### C3. 19 empty `catch {}` blocks across 6 files
- **Rationale**: Empty catch blocks swallow exceptions without logging. The analyzer currently excludes `PSAvoidUsingEmptyCatchBlock`, which masks real maintainability issues. Key files:
  - `Scripts/arc-raiders/cleanup-arc-raiders.ps1` (2)
  - `Scripts/arc-raiders/game-boost.ps1` (2)
  - `Scripts/arc-raiders/SkipVideosMod.ps1` (3)
  - `Scripts/arc-raiders/start-arc-raiders.ps1` (1)
  - `Scripts/Install-Packages.ps1` (2)
  - `Scripts/system-update.ps1` (9)
- **Scope**: Add minimal logging (`Write-Verbose`, `Write-Warning`, or `Add-Log` from `Common.ps1`) inside every catch block. Remove the analyzer exclusion once cleaned.
- **Priority**: Critical
- **Effort**: Medium

---

### High

#### H1. `Network-Tweaker.ps1` (240 KB, ~4,224 lines) is unmanageable monolith
- **Rationale**: This file is larger than the rest of `Scripts/` combined. It is largely WinForms designer output and networking tweaks mixed together. It is difficult to review, test, and maintain. The existing test file is only 1.3 KB (likely a stub).
- **Scope**: Split UI generation, adapter enumeration, registry logic, and button handlers into separate files (or at minimum into regions/functions in separate modules). Remove dead WinForms boilerplate if possible.
- **Priority**: High
- **Effort**: Large

#### H2. `system-update.ps1` (~1,576 lines) is overly complex and under-tested
- **Rationale**: Contains scheduled task logic, winget timeout handling, streaming capture, upgrade hooks, WSL updates, and cleanup—all in one file. It has 743 bytes of test coverage (effectively a stub) and 9 empty catch blocks.
- **Scope**: Decompose into smaller parameterized functions/modules (e.g., `Update-WingetPackages`, `Update-Windows`, `Update-WSLDistros`). Add Pester coverage for at least the happy path and timeout behavior.
- **Priority**: High
- **Effort**: Large

#### H3. Arc Raiders scripts duplicate process-control and error-handling logic
- **Rationale**: `game-boost.ps1`, `cleanup-arc-raiders.ps1`, `SkipVideosMod.ps1`, and `start-arc-raiders.ps1` share patterns for game process discovery, priority adjustment, and empty catch blocks. The AGENTS.md already notes that all five arc-raiders scripts change together—this is a sign of tight coupling through duplication.
- **Scope**: Centralize game-launch and process-boost helpers in `Common.ps1` or a new `Scripts/arc-raiders/ArcRaidersCommon.ps1`. Parameterize mode differences (boost, cleanup, skip videos).
- **Priority**: High
- **Effort**: Medium

#### H4. Missing tests for 6 scripts
- **Rationale**: The `tests/` directory has 19 test files but these scripts lack any coverage:
  - `Scripts/Fix-WindowsUpdates.ps1`
  - `Scripts/arc-raiders/ARCRaidersUtility.ps1`
  - `Scripts/arc-raiders/cleanup-arc-raiders.ps1`
  - `Scripts/arc-raiders/game-boost.ps1`
  - `Scripts/arc-raiders/SkipVideosMod.ps1`
  - `Scripts/arc-raiders/start-arc-raiders.ps1`
- **Scope**: Add at least smoke tests (parameter validation, `ShouldProcess` forwarding, no-throw on dry-run) for each. Heavily UI-dependent scripts may need mocked form objects or be verified via integration tests.
- **Priority**: High
- **Effort**: Medium

#### H5. `PSScriptAnalyzerSettings.psd1` excludes `PSAvoidUsingEmptyCatchBlock` globally
- **Rationale**: Excluding this rule hides the systemic empty-catch problem. It should be re-enabled once the codebase is cleaned. The `PSReviewUnusedParameter` exclusion is more defensible for CLI scripts, but should still be reviewed.
- **Scope**: Re-enable `PSAvoidUsingEmptyCatchBlock`; fix all violations (see C3). Evaluate whether `PSReviewUnusedParameter` exclusion is still necessary.
- **Priority**: High
- **Effort**: Small

#### H6. Elevation relaunch does not consistently propagate `-WhatIf` / `-Confirm`
- **Rationale**: Multiple scripts relaunch elevated via `Start-Process ... -Verb RunAs`, but several do not forward `$WhatIfPreference` or `-WhatIf` in the argument list (e.g., `Scripts/arc-raiders/game-boost.ps1`, `Scripts/gpu-display-manager.ps1`). This breaks `SupportsShouldProcess` contracts.
- **Scope**: Audit all `Start-Process -Verb RunAs` call sites. Ensure `if ($WhatIfPreference) { $argList += ' -WhatIf' }` logic is present.
- **Priority**: High
- **Effort**: Small

#### H7. `Invoke-Expression` (`iex`) used in `autounattend.xml` for WinUtil
- **Rationale**: The unattended installer XML uses `iex` to launch the WinUtil tool. While this is an embedded final-stage convenience, it is a prohibited pattern per repo rules and should be avoided when a simple script path call would suffice.
- **Scope**: Replace `iex ((New-Object ... ).Content)` with a downloaded `.ps1` execution path or embedded script block executed via `powershell.exe -File`.
- **Priority**: High
- **Effort**: Small

---

### Medium

#### M1. `Deploy-Config.ps1` may duplicate `Setup-Dotfiles.ps1` logic
- **Rationale**: Both scripts handle tracked config deployment. `Setup-Dotfiles.ps1` is the canonical, hash-aware implementation. `Deploy-Config.ps1` appears to overlap and could be redundant or divergent.
- **Scope**: Compare the two files. Consolidate into `Setup-Dotfiles.ps1` if `Deploy-Config.ps1` is a subset; otherwise clearly document when each should be used.
- **Priority**: Medium
- **Effort**: Small

#### M2. `Common.ps1` functions lacking `[CmdletBinding()]`
- **Rationale**: At least `vdf_mkdir` (and possibly others) lack `[CmdletBinding()]`, which means they do not support `-Verbose`, `-WhatIf`, or pipeline binding. Several `Network-Tweaker.ps1` functions also lack it.
- **Scope**: Add `[CmdletBinding()]` to all functions in `Common.ps1`. Review `Network-Tweaker.ps1` helper functions for the same gap.
- **Priority**: Medium
- **Effort**: Small

#### M3. `Write-Host` used outside of UI helpers in many scripts
- **Rationale**: `Write-Host` is acceptable in menu/UI functions (already suppressed in `Common.ps1`), but 25 files use it, including scripts that are intended to run in CI or unattended modes. This produces non-capturable output.
- **Scope**: Replace non-UI `Write-Host` with `Write-Verbose`, `Write-Information`, or the logging helpers from `Common.ps1` (`Add-Log`).
- **Priority**: Medium
- **Effort**: Medium

#### M4. No integration tests for `install.conf.yaml` / dotbot deployment
- **Rationale**: The deployment pipeline is the primary value of the repo, yet only unit tests exist. There is no validation that `install.conf.yaml` targets map to real source files or that `Setup-Dotfiles.ps1` can run in dry-run mode for every target.
- **Scope**: Add a CI job that runs `pwsh -File Scripts/Setup-Dotfiles.ps1 -WhatIf` for a representative subset of targets (or all) on every PR.
- **Priority**: Medium
- **Effort**: Medium

#### M5. `autounattend.xml` hardcodes Appx removal list inline
- **Rationale**: The Appx list inside the XML is not shared with `debloat-windows.ps1`, which maintains its own list. Updates to one will not propagate to the other. The XML is also 70+ KB, making review difficult.
- **Scope**: Extract the Appx list into a shared data file (JSON/CSV) and reference it from both `debloat-windows.ps1` and the XML generation/template step. Alternatively, generate the XML from a manifest.
- **Priority**: Medium
- **Effort**: Medium

#### M6. No centralized rollback / `-Restore` on most optimization scripts
- **Rationale**: The repo rules recommend `-Restore` / `-Undo` for registry changes, but most scripts (debloat, system-update, Install-Packages, network, settings) only apply changes with no reversal path.
- **Scope**: For each system-modifying script, add a `-Restore` switch that reverses the primary registry/service changes. Start with the highest-risk scripts (debloat, system-settings-manager).
- **Priority**: Medium
- **Effort**: Large

#### M7. No CHANGELOG or version tracking
- **Rationale**: Individual scripts have version strings in comments, but there is no repo-level changelog or release notes, making it hard for users to know what changed between commits.
- **Scope**: Add `CHANGELOG.md` following Keep a Changelog format. Update CI to reject PRs that modify user-facing scripts without a changelog entry.
- **Priority**: Medium
- **Effort**: Small

#### M8. `Network-Tweaker.ps1` uses global / script-scoped variables for UI state
- **Rationale**: WinForms controls and state are stored in script-scoped variables with minimal encapsulation. This makes testing and reasoning about side effects extremely difficult.
- **Scope**: Encapsulate UI creation and event binding into a module or at least a set of functions with explicit parameter inputs and outputs.
- **Priority**: Medium
- **Effort**: Large

---

### Low

#### L1. Minor test coverage gaps
- **Rationale**: Some tests are stubs (`UltimateDiskCleanup.Tests.ps1` ~895 bytes, `system-update.Tests.ps1` ~743 bytes). They validate loading but not logic.
- **Scope**: Expand tests to cover the main function paths (e.g., `Remove-BloatwareApps` dry-run, `Disable-UnnecessaryServices` mock path).
- **Priority**: Low
- **Effort**: Medium

#### L2. `Common.ps1` is large (55.5 KB) and may contain unused helpers
- **Rationale**: As the shared library grows, some functions may have become dead code. A periodic audit would keep the file focused.
- **Scope**: Run a coverage-style analysis (search for each function name across `Scripts/`) and remove or deprecate unused helpers.
- **Priority**: Low
- **Effort**: Small

#### L3. `README.md` and `AGENTS.md` notes about log locations are stale
- **Rationale**: `README.md` references `C:\Windows\Setup\Scripts\install.log` and other log paths; these may not match current script output locations.
- **Scope**: Verify all documented log paths and registry tweak descriptions against the actual scripts. Update README as needed.
- **Priority**: Low
- **Effort**: Small

#### L4. `Fix Updates.cmd` is an unmaintained CMD wrapper
- **Rationale**: The repo is primarily PowerShell. Maintaining a CMD companion for `Fix-WindowsUpdates.ps1` introduces dual-maintenance overhead.
- **Scope**: Evaluate whether `Fix Updates.cmd` is still used. If not, deprecate and redirect to the `.ps1`.
- **Priority**: Low
- **Effort**: Tiny

#### L5. No semantic versioning or release tags
- **Rationale**: The repo has no Git tags or releases, which makes it hard for users to pin a known-good version.
- **Scope**: Adopt lightweight semantic versioning and create tags after meaningful milestones.
- **Priority**: Low
- **Effort**: Small

---

## File-to-Task Quick Reference

| File(s) | Related Task IDs |
|---------|-------------------|
| `Scripts/reg/RegistryTweaks10.reg` | C1 |
| `Scripts/arc-raiders/ARCRaidersUtility.ps1` | C2, C3, H4, H6, M2 |
| `Scripts/Network-Tweaker.ps1` | C2, C3, H1, M2, M8 |
| `Scripts/UltimateDiskCleanup.ps1` | C2 |
| `Scripts/system-update.ps1` | C3, H2, H6, L1 |
| `Scripts/arc-raiders/game-boost.ps1` | C3, H3, H4, H6 |
| `Scripts/arc-raiders/cleanup-arc-raiders.ps1` | C3, H3, H4 |
| `Scripts/arc-raiders/SkipVideosMod.ps1` | C3, H3, H4 |
| `Scripts/arc-raiders/start-arc-raiders.ps1` | C3, H3, H4 |
| `Scripts/Install-Packages.ps1` | C3, H6 |
| `Scripts/Deploy-Config.ps1` | M1 |
| `Scripts/Setup-Dotfiles.ps1` | M1, M4, H6 |
| `Scripts/Common.ps1` | M2, M3, L2 |
| `Scripts/auto/autounattend.xml` | H7, M5 |
| `Scripts/auto/autounattend-windows10.xml` | H7 |
| `Scripts/debloat-windows.ps1` | H6, M5, M6 |
| `Scripts/system-settings-manager.ps1` | M6 |
| `PSScriptAnalyzerSettings.psd1` | H5 |
| `README.md` | L3 |
| `AGENTS.md` | L3 |
| `Fix Updates.cmd` | L4 |

---

## Recommended Priority Order

1. **Security & Safety**: C1 (UAC reg tweak warning), C2 (global SilentlyContinue), C3 (empty catches), H7 (iex in autounattend)
2. **CI & Testing**: H5 (re-enable analyzer rule), H4 (add missing tests), M4 (deployment integration tests)
3. **Refactoring**: H1 (split Network-Tweaker), H2 (split system-update), H3 (deduplicate arc-raiders)
4. **Usability & Maintenance**: H6 (WhatIf propagation), M6 (restore params), M3 (Write-Host cleanup), M7 (changelog), L2 (dead code audit)
