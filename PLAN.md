# <plan id="win-repo-audit" v="1">
## <meta>
Audit: 2026-05-03 | Scope: code quality, arch, prod readiness, maintainability
Prev TODOs: None found. All tasks below are newly identified.
</meta>

## <exec_order>
1. Security & Safety  → C1, C2, C3, H7
2. CI & Testing       → H5, H4, M4
3. Refactor           → H1, H2, H3
4. UX & Maintenance   → H6, M6, M3, M7, L2
</exec_order>

---

## <tasks prio="critical">

<task id="C1">
<summary>RegistryTweaks10.reg disables UAC unconditionally (EnableLUA=0)</summary>
<why>Silent .reg import w/o warning. Breaks elevation expectations, reduces security posture.</why>
<do>Add warning header in .reg or guard behind explicit opt-in param in caller scripts. Consider removing the key entirely.</do>
<files>Scripts/reg/RegistryTweaks10.reg</files>
<effort>S</effort>
</task>

<task id="C2">
<summary>Global $ErrorActionPreference = 'SilentlyContinue' in 3 scripts</summary>
<why>Hides all failures; prohibited per repo rules.</why>
<do>Replace w/ per-cmdlet -ErrorAction SilentlyContinue or try/catch + Write-Warning.</do>
<files>Scripts/arc-raiders/ARCRaidersUtility.ps1 (~L26)
Scripts/Network-Tweaker.ps1 (~L2255, ~L2383)
Scripts/UltimateDiskCleanup.ps1 (~L18)</files>
<effort>S</effort>
</task>

<task id="C3">
<summary>19 empty catch {} blocks across 6 files</summary>
<why>Swallow exceptions silently. PSAvoidUsingEmptyCatchBlock excluded in settings hides this.</why>
<do>Add Write-Verbose/Write-Warning/Add-Log in every catch. Re-enable analyzer rule after cleanup.</do>
<files>Scripts/arc-raiders/cleanup-arc-raiders.ps1 (2)
Scripts/arc-raiders/game-boost.ps1 (2)
Scripts/arc-raiders/SkipVideosMod.ps1 (3)
Scripts/arc-raiders/start-arc-raiders.ps1 (1)
Scripts/Install-Packages.ps1 (2)
Scripts/system-update.ps1 (9)</files>
<effort>M</effort>
</task>

</tasks>

## <tasks prio="high">

<task id="H1">
<summary>Network-Tweaker.ps1 is a 240 KB / ~4,224 line monolith</summary>
<why>Unreviewable, untestable, unmaintainable. Mostly WinForms boilerplate mixed w/ registry tweaks.</why>
<do>Split into: UI forms, adapter logic, registry helpers, event handlers. Prune dead WinForms code.</do>
<files>Scripts/Network-Tweaker.ps1</files>
<effort>L</effort>
</task>

<task id="H2">
<summary>system-update.ps1 (~1,576 lines) is over-complex and under-tested</summary>
<why>Scheduled tasks, winget timeouts, hooks, WSL, cleanup all in one file. Test is 743 bytes (stub).</why>
<do>Extract modules: Update-WingetPackages, Update-Windows, Update-WSLDistros. Add Pester happy-path + timeout tests.</do>
<files>Scripts/system-update.ps1</files>
<effort>L</effort>
</task>

<task id="H3">
<summary>Arc Raiders scripts duplicate process-control & error-handling logic</summary>
<why>game-boost, cleanup, SkipVideosMod, start-arc-raiders all replicate game-discovery, priority-set, empty-catch patterns.</why>
<do>Centralize helpers in Common.ps1 or Scripts/arc-raiders/ArcRaidersCommon.ps1. Parameterize mode.</do>
<files>Scripts/arc-raiders/*.ps1</files>
<effort>M</effort>
</task>

<task id="H4">
<summary>6 scripts have zero test coverage</summary>
<why>Untested deployment/gaming scripts risk regressions.</why>
<do>Add smoke tests: param validation, ShouldProcess forwarding, no-throw dry-run. Mock WinForms where needed.</do>
<files>Scripts/Fix-WindowsUpdates.ps1
Scripts/arc-raiders/ARCRaidersUtility.ps1
Scripts/arc-raiders/cleanup-arc-raiders.ps1
Scripts/arc-raiders/game-boost.ps1
Scripts/arc-raiders/SkipVideosMod.ps1
Scripts/arc-raiders/start-arc-raiders.ps1</files>
<effort>M</effort>
</task>

<task id="H5">
<summary>PSScriptAnalyzerSettings.psd1 excludes PSAvoidUsingEmptyCatchBlock</summary>
<why>Masks C3 systemic problem.</why>
<do>Re-enable rule; fix all violations (see C3). Review PSReviewUnusedParameter exclusion.</do>
<files>PSScriptAnalyzerSettings.psd1</files>
<effort>S</effort>
</task>

<task id="H6">
<summary>Elevation relaunch does not consistently propagate -WhatIf / -Confirm</summary>
<why>Breaks SupportsShouldProcess contract when script auto-elevates via Start-Process -Verb RunAs.</why>
<do>Audit all Start-Process -Verb RunAs call sites. Add: if ($WhatIfPreference) { $argList += ' -WhatIf' }.</do>
<files>Scripts/arc-raiders/game-boost.ps1
Scripts/gpu-display-manager.ps1
Scripts/Install-Packages.ps1
Scripts/Setup-Dotfiles.ps1
Scripts/Setup-Win11.ps1
Scripts/shell-setup.ps1
Scripts/system-update.ps1</files>
<effort>S</effort>
</task>

<task id="H7">
<summary>autounattend.xml uses Invoke-Expression (iex) for WinUtil</summary>
<why>Prohibited pattern per repo rules.</why>
<do>Replace iex with powershell.exe -File <downloaded_ps1> or embedded script path.</do>
<files>Scripts/auto/autounattend.xml
Scripts/auto/autounattend-windows10.xml</files>
<effort>S</effort>
</task>

</tasks>

## <tasks prio="medium">

<task id="M1">
<summary>Deploy-Config.ps1 duplicates Setup-Dotfiles.ps1 logic</summary>
<why>Two deployment paths = drift risk. Setup-Dotfiles.ps1 is canonical hash-aware impl.</why>
<do>Compare both. Consolidate into Setup-Dotfiles.ps1 if Deploy-Config is a subset; else document diff.</do>
<files>Scripts/Deploy-Config.ps1, Scripts/Setup-Dotfiles.ps1</files>
<effort>S</effort>
</task>

<task id="M2">
<summary>Common.ps1 functions lack [CmdletBinding()]</summary>
<why>Blocks -Verbose, -WhatIf, pipeline support. At least vdf_mkdir affected; Network-Tweaker helpers too.</why>
<do>Add [CmdletBinding()] to all Common.ps1 functions. Audit Network-Tweaker.ps1 helper funcs.</do>
<files>Scripts/Common.ps1, Scripts/Network-Tweaker.ps1</files>
<effort>S</effort>
</task>

<task id="M3">
<summary>Write-Host used outside UI helpers in 25 files</summary>
<why>Non-capturable in CI/unattended modes.</why>
<do>Replace w/ Write-Verbose / Write-Information / Add-Log.</do>
<files>Scripts/*.ps1 (broad scan needed)</files>
<effort>M</effort>
</task>

<task id="M4">
<summary>No integration tests for install.conf.yaml / dotbot deployment</summary>
<why>Primary repo value is config deployment, but zero end-to-end validation.</why>
<do>Add CI job: pwsh -File Scripts/Setup-Dotfiles.ps1 -WhatIf for all targets on every PR.</do>
<files>.github/workflows/*.yml</files>
<effort>M</effort>
</task>

<task id="M5">
<summary>autounattend.xml hardcodes Appx list inline, not shared w/ debloat-windows.ps1</summary>
<why>Dual maintenance. XML edits don't propagate to debloat script.</why>
<do>Extract Appx list to shared JSON/CSV. Generate XML from manifest or load shared list.</do>
<files>Scripts/auto/autounattend*.xml, Scripts/debloat-windows.ps1</files>
<effort>M</effort>
</task>

<task id="M6">
<summary>Most optimization scripts lack -Restore / -Undo switch</summary>
<why>Repo rules recommend rollback, but debloat, system-update, settings, network only apply.</why>
<do>Add -Restore to highest-risk scripts first (debloat, system-settings-manager).</do>
<files>Scripts/debloat-windows.ps1
Scripts/system-settings-manager.ps1
Scripts/Network-Tweaker.ps1</files>
<effort>L</effort>
</task>

<task id="M7">
<summary>No CHANGELOG or release tags</summary>
<why>Users can't track changes across commits.</why>
<do>Add CHANGELOG.md (Keep a Changelog). Consider lightweight semver + git tags.</do>
<files>CHANGELOG.md (new)</files>
<effort>S</effort>
</task>

<task id="M8">
<summary>Network-Tweaker.ps1 uses global/script-scoped vars for UI state</summary>
<why>Untestable, side-effect heavy.</why>
<do>Encapsulate UI + events into functions/module w/ explicit params/returns.</do>
<files>Scripts/Network-Tweaker.ps1</files>
<effort>L</effort>
</task>

</tasks>

## <tasks prio="low">

<task id="L1">
<summary>Stub tests for UltimateDiskCleanup and system-update</summary>
<why>Only validate load, not logic.</why>
<do>Expand to cover main function paths (dry-run, mock service/registry ops).</do>
<files>tests/UltimateDiskCleanup.Tests.ps1
tests/system-update.Tests.ps1</files>
<effort>M</effort>
</task>

<task id="L2">
<summary>Common.ps1 may contain dead helpers</summary>
<why>55.5 KB shared lib = likely unused funcs.</why>
<do>Search each function name across Scripts/. Remove / deprecate zero-hit helpers.</do>
<files>Scripts/Common.ps1</files>
<effort>S</effort>
</task>

<task id="L3">
<summary>README/AGENTS.md log path references may be stale</summary>
<why>C:\Windows\Setup\Scripts\install.log etc. need verification.</why>
<do>Audit all documented log paths vs actual script output. Update docs.</do>
<files>README.md, AGENTS.md</files>
<effort>S</effort>
</task>

<task id="L4">
<summary>Fix Updates.cmd is unmaintained CMD wrapper</summary>
<why>Dual maintenance overhead in a PS-first repo.</why>
<do>Evaluate usage. Deprecate + redirect to Fix-WindowsUpdates.ps1 if unused.</do>
<files>Scripts/Fix Updates.cmd</files>
<effort>XS</effort>
</task>

<task id="L5">
<summary>No semantic versioning or release tags</summary>
<why>No pinned known-good versions for users.</why>
<do>Create git tags after milestones. Document in README.</do>
<files>—</files>
<effort>S</effort>
</task>

</tasks>

## <xref>
| File | Tasks |
|---|---|
| Scripts/reg/RegistryTweaks10.reg | C1 |
| Scripts/arc-raiders/ARCRaidersUtility.ps1 | C2, C3, H4, H6, M2 |
| Scripts/Network-Tweaker.ps1 | C2, C3, H1, M2, M8 |
| Scripts/UltimateDiskCleanup.ps1 | C2 |
| Scripts/system-update.ps1 | C3, H2, H6, L1 |
| Scripts/arc-raiders/game-boost.ps1 | C3, H3, H4, H6 |
| Scripts/arc-raiders/cleanup-arc-raiders.ps1 | C3, H3, H4 |
| Scripts/arc-raiders/SkipVideosMod.ps1 | C3, H3, H4 |
| Scripts/arc-raiders/start-arc-raiders.ps1 | C3, H3, H4 |
| Scripts/Install-Packages.ps1 | C3, H6 |
| Scripts/Deploy-Config.ps1 | M1 |
| Scripts/Setup-Dotfiles.ps1 | M1, M4, H6 |
| Scripts/Common.ps1 | M2, M3, L2 |
| Scripts/auto/autounattend*.xml | H7, M5 |
| Scripts/debloat-windows.ps1 | H6, M5, M6 |
| Scripts/system-settings-manager.ps1 | M6 |
| PSScriptAnalyzerSettings.psd1 | H5 |
| README.md, AGENTS.md | L3 |
| Scripts/Fix Updates.cmd | L4 |
</xref>

## <legend>
Effort: XS = <1h, S = 1-4h, M = 4-16h, L = 16-40h
</legend>

</plan>