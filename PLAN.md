# Implementation Plan: Ven0m0/Win Repository

## Current Status: Updated 2026-06-08

## Completed Items

### Script Quality
- `Scripts/Network-Tweaker.ps1` — PSScriptAnalyzer clean (4,233 lines, no warnings/errors)
- `Scripts/enable-timer-res.ps1` — fixed hardcoded `C:\SetTimerResolution.exe` → `$env:SystemDrive`; replaced `WebClient.DownloadFile` with `Get-FileFromWeb`; fixed duplicate step label
- `Scripts/Steam-Config.ps1` — removed dead `#[console]::Title` comment, trailing blank lines
- `Scripts/arc-raiders/SkipVideosMod.ps1` line 29 — fixed truncated `| Select-Object -Ex` → `.SteamPath`
- `Scripts/shell-setup.ps1` lines 95-96 — fixed bare `curl` → `curl.exe`
- `Scripts/Deploy-Config.ps1` — fixed misplaced shebang; added `#Requires -Version 5.1`
- `Scripts/Install-Packages.ps1`, `Steam-Config.ps1`, `steam.ps1`, `enable-timer-res.ps1` — added `#Requires -Version 5.1`
- `Scripts/reg/priority.ps1` — resolved QoS TODO; added `PioneerGame-d.exe` / `PioneerGame-e.exe` CPU priority

### JSON / Lint
- All tracked JSON files formatted with biome v2.4.16
- `biome.json` migrated to schema 2.4.16; `user/.dotfiles/**` excluded from formatting
- `.kilo/kilo.json` — fixed trailing comma in `agent` block

### Steam Optimization
- `Scripts/Optimize-Steam.ps1` — cleans Steam redist installers, integrates NoSteamWebHelper
- `Scripts/New-SteamShortcut.ps1` — creates optimized Steam desktop shortcut

---

## Remaining Tasks

### Priority 1: Test Coverage

Scripts with no Pester tests:

| Script | Test file to create |
|---|---|
| `Scripts/New-SteamShortcut.ps1` | `tests/New-SteamShortcut.Tests.ps1` |
| `Scripts/Optimize-Steam.ps1` | `tests/Optimize-Steam.Tests.ps1` |
| `Scripts/Steam-Config.ps1` | `tests/Steam-Config.Tests.ps1` |
| `Scripts/enable-timer-res.ps1` | `tests/enable-timer-res.Tests.ps1` |

Use Pester Arrange-Act-Assert; mock registry/file/network operations (never touch HKLM in tests).

---

### Priority 2: Add Notepad Replacer

- **Reference:** https://www.binaryfortress.com/NotepadReplacer
- **Download:** `https://www.binaryfortress.com/Data/Download/?Package=notepadreplacer&Log=100`
- **Requires:** Notepad++ installed first
- **Action:** Add to `Scripts/Install-Packages.ps1`
- **Open question:** Verify silent install flag (`/S` or `/quiet`)

---

### Priority 3: Steam VDF Consolidation

`Steam-Config.ps1` uses a hand-rolled VDF parser (typed classes, `ensureblock`, comment-skipping) that is more capable than `Common.ps1`'s `ConvertFrom-VDF`/`ConvertTo-VDF`. Merging is a behavioral risk.

**Action:**
1. Audit what `steam.ps1` and `Steam-Config.ps1` each set in `localconfig.vdf` — document overlap
2. Decide: extend `Common.ps1` with the missing capabilities OR accept two parsers long-term
3. If extending: port `Steam-Config.ps1` to use `Common.ps1`; remove custom classes

**Overlapping keys (currently set by both scripts):**
- `LibraryLowBandwidthMode`, `LibraryLowPerfMode`, `LibraryDisableCommunityContent`
- `friends.SignIntoFriends`

---

### Priority 4: Evaluate chawyehsu Dotfiles Patterns

- Bootstrap patterns: [install.ps1](https://github.com/chawyehsu/dotfiles/blob/main/install.ps1) → compare with `Scripts/Setup-Dotfiles.ps1`
- PS profile features: [profile.ps1](https://github.com/chawyehsu/dotfiles/blob/main/.config/powershell/profile.ps1) → review aliases/prompt
- WSL config: [.config/wsl](https://github.com/chawyehsu/dotfiles/tree/main/.config/wsl) → consider adding `user/.dotfiles/config/wsl/`
- Scoop config: [config.json](https://github.com/chawyehsu/dotfiles/blob/main/.config/scoop/config.json) → compare with existing

---

### Priority 5: Feature Improvements

- **`Watch-GpuMetrics`** — add to `Common.ps1`; real-time nvidia-smi/WMI GPU dashboard (temp, clock, VRAM, power)
- **`Start-OptimizedGame.ps1`** — generalize `start-arc-raiders.ps1` launch patterns; accept game name + preset; reuse `game-boost.ps1`
- **`Test-SystemHealth`** — proactive checks: disk health, pending updates, service anomalies, large temp dirs, startup items

---

## Validation Checklist

- [x] All `Scripts/*.ps1` pass PSScriptAnalyzer (including Network-Tweaker.ps1)
- [x] All root scripts have `#Requires -Version 5.1`
- [x] All tracked JSON files pass biome format
- [x] `reg/priority.ps1` QoS TODO resolved
- [x] `enable-timer-res.ps1` hardcoded path replaced
- [x] `shell-setup.ps1` uses `curl.exe`
- [ ] Pester tests for New-SteamShortcut, Optimize-Steam, Steam-Config, enable-timer-res
- [ ] Notepad Replacer added to package installation
- [ ] Steam VDF consolidation complete or documented decision
- [ ] chawyehsu patterns evaluated
