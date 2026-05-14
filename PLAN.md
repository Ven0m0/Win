# Implementation Plan: Ven0m0/Win Repository

## Current Status: Updated 2026-05-14

## Completed Items

### Steam Optimization (DONE)
- `Scripts/Optimize-Steam.ps1` - Cleans Steam redist installers and integrates NoSteamWebHelper
- `Scripts/New-SteamShortcut.ps1` - Creates optimized Steam desktop shortcut with launch args

### Parser / Lint Fixes (DONE this session)
- `Scripts/arc-raiders/SkipVideosMod.ps1` line 29 - Fixed truncated `| Select-Object -Ex` → `.SteamPath` property access
- `Scripts/shell-setup.ps1` lines 95-96 - Fixed bare `curl` → `curl.exe` per AGENTS.md conventions
- `Scripts/Deploy-Config.ps1` - Fixed misplaced `#!/usr/bin/env pwsh` shebang; added `#Requires -Version 5.1`
- `Scripts/Install-Packages.ps1`, `Steam-Config.ps1`, `steam.ps1`, `enable-timer-res.ps1` - Added missing `#Requires -Version 5.1` headers
- `.kilo/kilo.json` - Fixed trailing comma in `agent` block (invalid JSON5)

### JSON Formatting (DONE this session)
- Ran `@biomejs/biome format --write` on all tracked JSON files:
  `renovate.json`, `.ctxlintrc.json`, `.vscode/extensions.json`, `.kilo/kilo.json`, `.kilo/package.json`,
  `user/.dotfiles/config/windows-terminal/settings.json`, `user/.dotfiles/config/scoop/config.json`,
  `user/.dotfiles/config/winget-configs/settings.json`, `.claude/settings.json`

---

## Remaining Tasks

### Priority 1: Script Quality

#### Task 1.1: Verify Network-Tweaker.ps1 Parser Errors
- File is 4,233 lines; previously flagged around lines 2395-2396
- Current scan shows no obvious truncation, but needs full PSScriptAnalyzer run
- Run: `Invoke-ScriptAnalyzer -Path Scripts\Network-Tweaker.ps1 -Settings PSScriptAnalyzerSettings.psd1`

#### Task 1.2: Fix enable-timer-res.ps1 Hardcoded Path
- Line 4: `$ExePath = "C:\SetTimerResolution.exe"` — violates no-hardcoded-paths rule
- Fix: use `$env:SystemDrive` or make configurable via parameter with a documented default

#### Task 1.3: Fix reg/priority.ps1 TODO
- Line 4: `# === QoS PowerShell equivalent === TODO: fix broken Qos commands`
- Broken QoS netsh commands need to be replaced with working alternatives

#### Task 1.4: Add Missing Test Coverage
Scripts with no Pester tests:
- `Scripts/New-SteamShortcut.ps1`
- `Scripts/Optimize-Steam.ps1`
- `Scripts/Steam-Config.ps1`
- `Scripts/enable-timer-res.ps1`

---

### Priority 2: Add Notepad Replacer
- **Reference:** https://www.binaryfortress.com/NotepadReplacer
- **Download:** `https://www.binaryfortress.com/Data/Download/?Package=notepadreplacer&Log=100`
- **Requires:** Notepad++ installed first
- **Action:** Add to `Scripts/Install-Packages.ps1` or winget config
- **Open question:** Verify silent install support (`/S` or `/quiet` flag)

---

### Priority 3: Steam VDF Consolidation
- `Scripts/steam.ps1` and `Scripts/Steam-Config.ps1` both implement VDF parsing logic
- `Common.ps1` already exports `ConvertFrom-VDF` / `ConvertTo-VDF`
- **Action:** Audit steam.ps1 and Steam-Config.ps1 VDF implementations; remove redundant copies
  and ensure all callers use the `Common.ps1` versions

---

### Priority 4: Implement chawyehsu Dotfiles Patterns

#### Task 4.1: Install Bootstrap
- **Reference:** https://github.com/chawyehsu/dotfiles/blob/main/install.ps1
- **Action:** Study and potentially incorporate patterns into `Scripts/Setup-Dotfiles.ps1`

#### Task 4.2: PowerShell Profile
- **Reference:** https://github.com/chawyehsu/dotfiles/blob/main/.config/powershell/profile.ps1
- **Action:** Review for useful aliases, prompt customizations to add to `user/.dotfiles/config/powershell/profile.ps1`

#### Task 4.3: WSL Configuration
- **Reference:** https://github.com/chawyehsu/dotfiles/tree/main/.config/wsl
- **Action:** Consider adding WSL config deployment to `user/.dotfiles/config/wsl/`

#### Task 4.4: Scoop Configuration
- **Reference:** https://github.com/chawyehsu/dotfiles/blob/main/.config/scoop/config.json
- **Action:** Review and update `user/.dotfiles/config/scoop/config.json`

---

### Priority 5: Feature Improvements

#### Task 5.1: GPU Monitoring Script
- Current `gpu-display-manager.ps1` manages settings but has no real-time monitoring
- Potential: Add `Watch-GpuMetrics` helper to `Common.ps1` using `nvidia-smi` or WMI
- Surface: temperature, clock, VRAM, power in a compact dashboard view

#### Task 5.2: Unified Game Launcher
- `Scripts/arc-raiders/start-arc-raiders.ps1` has launch optimization patterns
- Could generalize into a `Start-OptimizedGame.ps1` that accepts game name + preset
- Reuse `game-boost.ps1` logic; integrate with `arc-raiders/ARCRaidersUtility.ps1`

#### Task 5.3: Windows Health Checks
- `fix-system.ps1` repairs problems but no proactive health-check mode
- Add a `Test-SystemHealth` command (similar to `Test-Environment` kilo command) that
  reports on: disk health, pending updates, service anomalies, large temp dirs, startup items

---

## Validation Checklist

- [x] SkipVideosMod.ps1 parses without error
- [x] shell-setup.ps1 uses `curl.exe` not bare `curl`
- [x] All JSON files pass `@biomejs/biome format`
- [x] `#Requires -Version 5.1` present on all root-level scripts
- [ ] Network-Tweaker.ps1 PSScriptAnalyzer clean
- [ ] enable-timer-res.ps1 hardcoded path replaced
- [ ] reg/priority.ps1 QoS TODO resolved
- [ ] Notepad Replacer added to package installation
- [ ] Steam VDF consolidation complete
- [ ] Test coverage added for New-SteamShortcut, Optimize-Steam, Steam-Config, enable-timer-res
- [ ] chawyehsu patterns evaluated and implemented where beneficial
