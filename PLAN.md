# Implementation Plan: Feature Ideas (Ven0m0/Win)

## Handoff Context

This plan covers the three "Feature Ideas" from `TODO.md`. Scope decisions were made with the
user before writing this plan — do not re-litigate them:

- **Depth: MVP-first.** Smallest working version of each feature. No new abstractions beyond what's
  listed below.
- **Placement: fold into existing files.** No new top-level scripts except where explicitly called out.
- Work the three features **in the order listed** — each section is independent of the others except
  where noted, so they can also be split across sessions.

Read `AGENTS.md` and the rule files under `.claude/rules/` before editing (PowerShell style, registry
safety, bootstrap conventions). This repo targets PS 5.1 + 7 compatibility.

## Baseline (verified against current code — re-check if this plan is picked up much later)

- `Scripts/Common.ps1` (2022 lines) — shared helpers. Has `Get-NvidiaGpuSetting` (registry-based
  static GPU config, NOT live telemetry), `New-RestorePoint`, `Get-FolderSize`, `Invoke-Operation`
  (DryRun/error-handling wrapper + `-Command`/`-CaptureOutput` for external processes),
  `Invoke-ServiceOperation`, `Show-Summary` (status-string color coding: `HEALTHY|COMPLETE|...` = green,
  `FAIL|ERROR` = red, `SKIP|DRY RUN` = yellow, `PARTIAL|SCHEDULED` = cyan), `Invoke-CommandChecked`.
  No `nvidia-smi` invocation or live-metrics helper exists today — this is a net-new capability.
- `Scripts/fix-system.ps1` (619 lines) — `-Action System|WindowsUpdate|All`, already wired through
  `Invoke-Operation`/`Show-Summary`.
- `Scripts/system-maintenance.ps1` (731 lines) — `-Action Defrag|Disk|Shader|Extra|DriverCleanup|All`.
- `Scripts/arc-raiders/game-boost.ps1` (542 lines) — the actual generic engine to generalize (see
  Feature 2). Already game-agnostic in structure: kill-list, power-plan swap/restore, memory trim,
  process-priority, launch, monitor-until-exit, crash-recovery state file
  (`$env:TEMP\arc-boost-state.json`). Only `$GAME_NAMES` and `$STEAM_GAME_ID` (plus cosmetic
  `ARC RAIDERS` banner strings) are Arc-Raiders-specific.
- `Scripts/arc-raiders/start-arc-raiders.ps1` (194 lines) and `cleanup-arc-raiders.ps1` (255 lines) —
  **not** targets for generalization. These are deeply Arc-Raiders/Steam-specific (VDF file rewriting
  for `sharedconfig.vdf`/`localconfig.vdf`, Steam friends-UI toggles, `SetTimerResolution.exe` path).
  Leave them alone.
- `Scripts/arc-raiders/ArcRaidersCommon.ps1` (302 lines) — shared arc-raiders helpers: `Remove-Glob`,
  `Invoke-MemoryTrim`, `Set-GameProcessPriority`, `Set-ContentNoNewline`, `Optimize-FixedVolume`,
  `Set-VdfValue`, `Find-ArcRaidersInstallPath`.

## Feature 1 — `Watch-GpuMetrics` (new helper in `Common.ps1`)

**Goal:** single-pass or `-Loop`ed GPU telemetry dashboard (utilization, temp, power draw, VRAM),
first telemetry-style helper in the repo (everything else in `Common.ps1` is static config).

**Design:**
- New function `Watch-GpuMetrics` in `Common.ps1`, placed near the other Nvidia helpers
  (`Get-NvidiaGpuSetting` region, ~line 316).
- Primary data source: `nvidia-smi --query-gpu=... --format=csv,noheader,nounits`, invoked via
  `Invoke-Operation -Command 'nvidia-smi' -ArgumentList ... -CaptureOutput` — do **not** call
  `& nvidia-smi` directly; route through the existing operation wrapper so DryRun/logging stay
  consistent with the rest of the repo.
- If `nvidia-smi` is not on PATH (AMD/Intel GPU, or missing driver), fall back to a WMI probe
  (`Get-CimInstance Win32_VideoController` — utilization won't be available there, so state that
  limitation in a warning rather than silently returning zeros).
- Parameters: `-IntervalSeconds` (default 2), `-Loop` (switch; without it, single pass and return),
  `-Count` (max iterations when looping; 0/unset = infinite until Ctrl+C).
- Output: one `[pscustomobject]` per GPU per sample (`Timestamp, GpuName, UtilizationPercent,
  TemperatureC, PowerDrawW, MemoryUsedMB, MemoryTotalMB`) — matches the "one object type per
  function" rule in `.claude/rules/powershell.md`. Let the caller pipe to `Format-Table`/
  `Export-Csv`; don't build a custom renderer.
- `[CmdletBinding()]`, comment-based help, `#Requires -Version 5.1` guard not needed (it's a
  function inside `Common.ps1`, which is dot-sourced — follow the file's existing convention of no
  per-function `#Requires`).

**Skipped (MVP boundary):** historical logging/export to file, a TUI/curses-style dashboard,
alerting/thresholds. Add when a caller actually needs trend data, not speculatively.

**Files touched:** `Scripts/Common.ps1` only.

**Verification:** `Invoke-ScriptAnalyzer -Path Scripts/Common.ps1 -Settings PSScriptAnalyzerSettings.psd1`
clean; manual run on a machine with an Nvidia GPU (`Watch-GpuMetrics`, `Watch-GpuMetrics -Loop -Count 3`);
confirm the WMI fallback path doesn't throw when `nvidia-smi` is renamed/absent (test via
`$env:PATH` manipulation or a non-Nvidia box if available). Add one `Describe` block to
`tests/Common.Tests.ps1` (or create it if it doesn't exist) that mocks `Invoke-Operation` and
asserts the returned object shape — do not require real GPU hardware in CI.

## Feature 2 — `Start-OptimizedGame.ps1` (generalize `game-boost.ps1`)

**Goal:** the kill/power-plan/mem-trim/priority/monitor engine in `game-boost.ps1`, usable for any
game via a per-game manifest, not just Arc Raiders.

**Prerequisite (do this first, blocks the extraction below):**
`ArcRaidersCommon.ps1::Optimize-FixedVolume` (line ~251) and the equivalent inline block in
`cleanup-arc-raiders.ps1` (line ~162) both nest the `try { if {} else {} } catch {}` and the
following `if/else` one indent level too deep inside the `ForEach-Object { }` scriptblock. Braces
are net-balanced (script runs), but the misindentation trips `PSUseConsistentIndentation` and makes
the block hard to safely refactor. Fix the indentation in both files before touching them further —
a bad diff here would be easy to miss once mixed with the extraction changes below.

**Extraction plan:**
1. Promote `Remove-Glob`, `Set-ContentNoNewline`, and the memory-trim `Add-Type` block (currently
   duplicated three times: `ArcRaidersCommon.ps1::Invoke-MemoryTrim`, inline in
   `start-arc-raiders.ps1`, inline in `game-boost.ps1::Import-MemApi`) into `Common.ps1` as a single
   shared helper. Keep the `TypeName` parameter pattern from `Invoke-MemoryTrim` so re-invocation
   within one process doesn't collide on the `Add-Type` class name.
2. Do **not** move `Set-GameProcessPriority`, `Set-VdfValue`, or `Find-ArcRaidersInstallPath` —
   those stay Arc-Raiders-specific or become manifest-driven (priority) per below.
3. New `Scripts/start-optimized-game.ps1` (top-level, not under `arc-raiders/`, since it's
   general-purpose now). Copy `game-boost.ps1`'s structure (self-elevation, state-file crash
   recovery, kill-list, power-plan swap/restore, monitor loop) and parameterize the
   Arc-Raiders-specific constants via a `-GameManifest <path-to-psd1>` parameter:
   ```powershell
   # Scripts/games/arc-raiders.psd1 (example manifest, migrate the existing constants here)
   @{
     ProcessNames = @('ARC', 'pioneergame', 'ARC-Win64-Shipping')
     SteamAppId   = '1808500'
     Priority     = 'High'
     LaunchType   = 'Steam'   # or 'Direct' with an ExePath key
   }
   ```
   Keep the existing `$KILL_LIST`/`$PROTECTED` tables as script-level defaults (shared across all
   games) rather than per-manifest — they're OS/app hygiene, not game-specific.
4. Leave `Scripts/arc-raiders/game-boost.ps1` in place as a thin wrapper that calls
   `start-optimized-game.ps1 -GameManifest Scripts/games/arc-raiders.psd1` (or delete it and update
   its Pester test + any docs/shortcuts that reference it directly — check `tests/game-boost.Tests.ps1`
   and grep the repo for `game-boost.ps1` callers before deleting).

**Skipped (MVP boundary):** `LaunchArgs[preset]` multi-preset support, `SavedPaths` backup/restore —
these were in the original deferred scoping note but add real complexity (config diffing, backup
rotation) for no concrete game that needs them yet. Add when a second game manifest actually
requires it.

**Files touched:** `Scripts/Common.ps1` (new shared helper), new `Scripts/start-optimized-game.ps1`,
new `Scripts/games/arc-raiders.psd1`, `Scripts/arc-raiders/game-boost.ps1` (thin wrapper or removed),
`Scripts/arc-raiders/ArcRaidersCommon.ps1` (indentation fix + drop the promoted functions, keep
callers working via `Common.ps1` dot-source), `Scripts/arc-raiders/cleanup-arc-raiders.ps1`
(indentation fix only — not otherwise in scope), `tests/game-boost.Tests.ps1` (update or replace).

**Verification:** `PSScriptAnalyzer` clean on every touched file. `Invoke-Pester -Path tests/` for
the arc-raiders and new game-boost tests. Manual dry-run: `start-optimized-game.ps1 -GameManifest
Scripts\games\arc-raiders.psd1 -DryRun` should print the same candidate kill list and power-plan
target as the old `game-boost.ps1 -DryRun` did before the change (diff the two outputs).

## Feature 3 — `Test-SystemHealth` (new `-Action Health` on `fix-system.ps1`)

**Goal:** proactive health checks — disk/volume health, pending updates, service anomalies, large
temp dirs, startup items — composed from existing helpers, not a new script.

**Design:**
- Add `'Health'` to the `[ValidateSet('System', 'WindowsUpdate', 'All')]` on line 39 of
  `fix-system.ps1` → `[ValidateSet('System', 'WindowsUpdate', 'Health', 'All')]`. Decide whether
  `'All'` should include `Health` — recommend **not** including it by default (health checks are
  read-only diagnostics, not repairs; bundling changes what `-Action All` means for existing callers/
  scheduled tasks). Add a separate `-IncludeHealth` switch on the `All` path instead if the user
  wants it bundled.
- New `Start-SystemHealthCheck` function (mirrors `Start-SystemFix`/`Start-WindowsUpdateFix`
  structure at line 60/547), driven through `Invoke-Operation`/`Show-Summary` like the rest of the
  file so the `HEALTHY` status-regex in `Show-Summary` (already present, `Common.ps1:1634`) lights up
  correctly with no changes needed there.
- Checks, each one `Invoke-Operation` entry:
  - **Disk/volume health**: `Get-PhysicalDisk | Get-StorageReliabilityCounter` (SMART-ish data
    where supported) + `Get-Volume` free-space threshold (flag any fixed volume under ~10% free —
    no such free-space probe exists in `Common.ps1` today; write it as a small local function in
    `fix-system.ps1`, don't over-generalize into `Common.ps1` until something else needs it).
  - **Pending updates**: reuse the existing WU session-COM-object pattern already present in
    `Start-WindowsUpdateFix` (grep for how it enumerates pending updates there) rather than adding
    the `PSWindowsUpdate` module as a new dependency.
  - **Service anomalies**: `Get-Service` filtered to `StartType -eq 'Automatic' -and Status -ne
    'Running'` — flag, don't auto-restart (this is a diagnostic action, not a repair one).
  - **Large temp dirs**: `Get-FolderSize` (`Common.ps1:1292`, already exists) against `$env:TEMP`,
    `$env:windir\Temp`, and `SoftwareDistribution\Download`; flag over a threshold (start at 5 GB).
  - **Startup items**: enumerate `HKCU:\...\Run`, `HKLM:\...\Run`, and the Startup folder shortcuts;
    report count + names only — this is informational, no action taken.
- Support `-DryRun` consistently (all checks are read-only anyway, so `-DryRun` mostly just skips
  the summary side-effects) and respect existing `-NoReport` switch.

**Skipped (MVP boundary):** historical trend tracking across runs, auto-remediation of flagged items
(that's what `-Action System`/`WindowsUpdate` are for — Health only diagnoses), a dedicated report
file format beyond what `-NoReport`/console output already gives.

**Files touched:** `Scripts/fix-system.ps1` only.

**Verification:** `PSScriptAnalyzer` clean. Manual run: `fix-system.ps1 -Action Health -DryRun` and
`fix-system.ps1 -Action Health` on a real machine; confirm `Show-Summary` renders each check with a
sensible status color (HEALTHY/PARTIAL/FAIL as appropriate — do not invent new status keywords
outside the set `Show-Summary` already regex-matches). Add/extend a Pester test under `tests/` if
`fix-system.ps1` already has one; if not, skip — don't add a full test harness for a single new
`-Action` value (YAGNI, matches this repo's existing test coverage pattern of testing what's risky,
not everything).

## Conventions (apply to all three features)

- PowerShell style: `.claude/rules/powershell.md` — `[CmdletBinding()]`, OTBS braces, 2-space indent,
  115-char lines, full cmdlet/param names, splatting over backticks, PS 5.1 + 7 compatible.
- Registry/state changes: `.claude/rules/registry-security.md` — N/A for Features 1 and 3 (read-only).
  Feature 2 doesn't touch the registry either (power plan via `powercfg`, not registry).
- Reuse `Common.ps1` — read the relevant function before adding a new one; none of these three
  features should duplicate an existing helper.
- Commits: `<type>: <subject>` (`feat`/`fix`/`chore`/`refactor`). One commit per feature section
  above is a reasonable granularity; keep the ArcRaidersCommon.ps1/cleanup-arc-raiders.ps1
  indentation fix as its own preceding commit since it's a prerequisite, not part of the feature.

## Suggested Session Order

1. Feature 1 (`Watch-GpuMetrics`) — fully independent, smallest, good warm-up.
2. Feature 3 (`Test-SystemHealth`) — independent of the other two, contained to one file.
3. Feature 2 (`Start-OptimizedGame`) — largest, has the prerequisite indentation fix and touches the
   most files; do last so any context-window pressure hits the best-scoped work first.

If picked up across multiple sessions, each numbered feature section above is a complete,
self-contained handoff on its own — a new session can start at any one of them without reading the
others, as long as it reads this file's Baseline section first.

## Post-Completion

Update `TODO.md`: remove completed items from "Feature Ideas"; if any feature's scope changed during
implementation (e.g. the `-IncludeHealth` switch was rejected, or `game-boost.ps1` was deleted rather
than kept as a wrapper), note the actual outcome the way the previous reference-repo-evaluation entry
did, then delete that summary once it's no longer useful (don't let TODO.md accumulate stale history
indefinitely — this repo's convention favors trimming completed context, not archiving it).

## Validation Checklist

- [ ] `ArcRaidersCommon.ps1` / `cleanup-arc-raiders.ps1` indentation fixed (prerequisite for Feature 2)
- [ ] `Watch-GpuMetrics` implemented in `Common.ps1`, PSScriptAnalyzer clean, manual GPU test run
- [ ] `Test-SystemHealth` implemented as `fix-system.ps1 -Action Health`, PSScriptAnalyzer clean,
      manual run confirms sensible `Show-Summary` output
- [ ] `Start-OptimizedGame.ps1` implemented, `game-boost.ps1` behavior preserved via manifest,
      Pester tests updated, dry-run output diffed against pre-change `game-boost.ps1 -DryRun`
- [ ] `TODO.md` updated to remove completed items
