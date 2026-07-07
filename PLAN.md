# Implementation Plan: Reference-Repo Evaluation (Ven0m0/Win)

## Context

`TODO.md` and this file carry two buckets of pending work: (A) evaluating a set of
external reference repositories for patterns/tweaks worth adopting, and (B) three
concrete new features. Per the scoping decision for this handoff, **this plan covers
bucket (A) only** — the reference-repo evaluation. The three features are explicitly
deferred (see "Deferred" at the end) with their scoping already captured so a later
session can pick them up cleanly.

The deliverable of bucket (A) is **an evaluation, not a blind port**: for each external
repo, produce a findings table (pattern → does our repo already cover it? → adopt /
skip / adapt → where it would land), then implement only the accepted items behind a
user approval gate. The repo already has mature coverage in most of these areas, so the
main risk is re-adding things that exist under different names.

This is a research + review task first, a coding task second. Treat "skip, already
covered" as a first-class, valuable outcome — do not manufacture changes.

## Current-Repo Baseline (what already exists — compare against this before adopting anything)

Established during exploration; use it to reject redundant suggestions:

- **Bootstrap**: `bootstrap.ps1` (internet entry, self-elevate, clone) → `install.conf.yaml` +
  `Scripts/Setup-Dotfiles.ps1` (winget packages, SHA256 hash-based config deploy, PATH).
  Cochange group: `install.conf.yaml`, `Scripts/Setup-Dotfiles.ps1`, `README.md`.
- **PowerShell profile**: tracked under `user/.dotfiles/config/powershell/`.
- **WSL config**: tracked area `user/.dotfiles/config/wsl/` already exists.
- **Scoop config**: tracked area `user/.dotfiles/config/scoop/` already exists.
- **Debloat / privacy**: `Scripts/debloat-windows.ps1` (bloatware removal, telemetry),
  `Remove-AppxPackageSafe` in `Common.ps1`, telemetry/advertising/suggested-apps keys
  documented in `.claude/rules/windows-os.md`.
- **Repair**: `Scripts/fix-system.ps1` — hub with `-Action System|WindowsUpdate|All`
  (SFC/DISM/WU repair inline). This is the integration target for Windows-Repair-Tool.
- **Maintenance**: `Scripts/system-maintenance.ps1` — `-Action Defrag|Disk|Shader|Extra|All`.
- **System settings**: `Scripts/system-settings-manager.ps1` — power, visual, privacy,
  GPU/display, keyboard.
- **Shared helpers**: `Scripts/Common.ps1` (~1838 lines) — registry (`Set-RegistryValue`,
  `Get-NvidiaGpuRegistryPath`), restore points (`New-RestorePoint`), UI/menu, logging,
  service ops (`Invoke-ServiceOperation`), operation runner + summary
  (`Invoke-Operation` / `Show-Summary`), appx removal, winget wrappers.

## Reference Repos to Evaluate

Process each independently; produce one findings section per repo. Fetch source via
`WebFetch`/`gh` (or the `github-smart` skill for whole-repo markdown). Do **not** run
any downloaded code.

### 1. chawyehsu/dotfiles — https://github.com/chawyehsu/dotfiles
Compare four surfaces against our baseline:
- `install.ps1` → vs `Scripts/Setup-Dotfiles.ps1` (bootstrap idempotency, package install flow).
- `.config/powershell/profile.ps1` → vs `user/.dotfiles/config/powershell/` (aliases, prompt,
  module loading, lazy-init patterns worth borrowing).
- `.config/wsl` → vs `user/.dotfiles/config/wsl/` (wsl.conf / distro setup).
- `.config/scoop/config.json` → vs `user/.dotfiles/config/scoop/` (buckets, aria2, cache settings).
Structural note: also assess whether their file/folder layout suggests any worthwhile
reorg, but bias toward keeping our current layout (churn cost is high).

### 2. pratyakshm/WinRice — https://github.com/pratyakshm/WinRice
Debloat/tweak toolkit. Extract candidate tweaks NOT already in `debloat-windows.ps1` /
`system-settings-manager.ps1` / `.reg` files under `Scripts/reg/`. For each candidate,
record the exact registry path/value or command so adoption is mechanical.

### 3. caglaryalcin/after-format — https://github.com/caglaryalcin/after-format
Post-format automation. Same treatment as WinRice — diff its tweaks against our debloat +
settings coverage; flag only the net-new, reversible ones.

### 4. Mohabdo21/Windows-Repair-Tool — https://github.com/Mohabdo21/Windows-Repair-Tool
**Integration target: `Scripts/fix-system.ps1`.** Identify repair routines it has that our
`-Action System|WindowsUpdate|All` lacks (e.g. component-store repair variants, network
stack reset, WMI repository rebuild, specific DISM/SFC sequencing). Map each to an existing
or new `-Action` value rather than a new script.

### 5. nohuto/win-config — https://github.com/nohuto/win-config
General sweep for tweaks/settings/optimizations not covered elsewhere. Lowest priority;
same diff-against-baseline discipline.

## Approach

Per repo, in this order:

1. **Fetch & skim** the relevant files only (not the whole tree unless small).
2. **Diff against baseline** — for every pattern, decide: already covered / adopt / adapt / skip.
   Cite our existing file where "already covered."
3. **Record findings** in a table: `Pattern | Reference location | Our coverage | Verdict | Target file`.
4. **Gate**: present consolidated findings to the user via `AskUserQuestion`; implement ONLY
   approved items. Do not batch-implement.
5. **Implement approved items** following repo conventions (below), one cochange group at a time.

## Conventions Every Adopted Change Must Follow

- **PowerShell** (`.claude/rules/powershell.md`): `#Requires -Version 5.1`, `[CmdletBinding()]`
  (+ `SupportsShouldProcess` for any state change), OTBS braces, 2-space indent, 115-char
  lines, full cmdlet/param names, splatting over backticks, PS 5.1 + 7 compatibility.
- **Registry** (`.claude/rules/registry-security.md`): `New-RestorePoint` before HKLM changes;
  use `Set-RegistryValue`/`Remove-RegistryValue` from `Common.ps1`, never raw `Set-ItemProperty`;
  never hardcode GPU PCI IDs (`Get-NvidiaGpuRegistryPath`); never touch `HKLM\SECURITY|SAM|Lsa`;
  provide a `-Restore`/`-Undo` path for reversibility.
- **Reuse `Common.ps1`** — read it before adding any helper; extend, don't duplicate.
- **Tracked config** goes under `user/.dotfiles/config/`; preserve native file formats (no
  cosmetic re-serialization); wire new config areas through `install.conf.yaml` +
  `Scripts/Setup-Dotfiles.ps1` (+ `README.md`) as a cochange group.
- **New script names** lowercase-with-dashes; prefer folding into existing hubs over new scripts.
- **Commits**: `<type>: <subject>` (`feat`/`fix`/`chore`/`refactor`/`docs`). Never commit
  hardcoded `C:\Users\...` paths, secrets, or exported hive `.reg` files.

## Critical Files

- Read-only comparison targets: `Scripts/Setup-Dotfiles.ps1`, `bootstrap.ps1`,
  `Scripts/debloat-windows.ps1`, `Scripts/system-settings-manager.ps1`,
  `user/.dotfiles/config/powershell/*`, `user/.dotfiles/config/scoop/*`,
  `user/.dotfiles/config/wsl/*`, `Scripts/reg/*.reg`.
- Likely edit targets (only for approved items): `Scripts/fix-system.ps1` (Windows-Repair-Tool),
  `Scripts/debloat-windows.ps1` / `Scripts/system-settings-manager.ps1` (WinRice/after-format/
  win-config tweaks), `Scripts/Common.ps1` (any new shared helper),
  `user/.dotfiles/config/*` + `install.conf.yaml` + `Scripts/Setup-Dotfiles.ps1` (chawyehsu
  config/profile adoptions).

## Verification

- **Per-changed `.ps1`**: `Invoke-ScriptAnalyzer -Path <file> -Settings PSScriptAnalyzerSettings.psd1`
  (clean, minus the known false positives in memory `project-pssa-false-positives.md`).
- **Pester** where the changed area has coverage: `Invoke-Pester -Path tests/ -Output Minimal`.
- **`install.conf.yaml`**: validate path resolution + hash logic; confirm `README.md` stays consistent.
- **`.reg` additions**: pass `reg-validate.yml` expectations (valid header, no hive exports).
- **Registry tweaks**: dry-run with `-WhatIf`; confirm `-Restore`/`-Undo` reverses the change.
- **Final gate**: no new secrets (Gitleaks), no hardcoded user paths; each adopted tweak is
  reversible and documented.

## Deferred (out of scope for this handoff — captured for a later session)

Three features from `TODO.md`. Decisions already made: target **MVP-first** depth,
**fold into existing** placement.

- **`Watch-GpuMetrics`** (MVP): single-pass/looped GPU telemetry. Note — `Common.ps1` has
  NO `nvidia-smi` or live-metrics helper today (only static registry/WMI config via
  `Get-NvidiaGpuSetting`); this would be the first telemetry integration. Route the external
  call through `Invoke-CommandChecked`/`Invoke-Operation -CaptureOutput`, not raw `& nvidia-smi`.
- **`Start-OptimizedGame`** (MVP, fold near arc-raiders): generalize `game-boost.ps1`'s
  generic kill/power/mem/priority/monitor engine via a per-game PSD1 manifest
  (`ProcessNames`, `SteamAppId`, `SavedPaths`, `LaunchArgs[preset]`, `Priority`, `LaunchType`).
  Prereq cleanup: promote `Remove-Glob`/`Set-ContentNoNewline`/mem-trim out of
  `ArcRaidersCommon.ps1`, and fix the known brace bugs in `ArcRaidersCommon.ps1::Optimize-FixedVolume`
  and `cleanup-arc-raiders.ps1`. Respect the Arc-Raiders 6-file cochange rule.
- **`Test-SystemHealth`** (MVP, fold as a new `-Action` on `fix-system.ps1` or
  `system-maintenance.ps1`): compose from existing `Invoke-Operation` + `Show-Summary`
  (its status regex already matches `HEALTHY`), `Get-Service`, `Get-FolderSize`, plus a new
  free-disk/volume probe (none exists yet). Checks: disk/volume health, pending updates,
  service anomalies, large temp dirs, startup items.

## Post-Completion

Update `TODO.md` to reflect what was evaluated, adopted, and skipped (with the "already
covered" rationale), leaving the three deferred features as the remaining open items.

## Validation Checklist

- [ ] chawyehsu patterns evaluated (bootstrap, PS profile, WSL, scoop)
- [ ] WinRice tweaks evaluated
- [ ] after-format tweaks evaluated
- [ ] Windows-Repair-Tool routines mapped onto `fix-system.ps1`
- [ ] win-config tweaks evaluated
- [ ] Findings presented to user for approval before any implementation
- [ ] Approved items implemented and validated per Verification section
- [ ] `TODO.md` updated to reflect outcome
