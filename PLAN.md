# Plan: Migrate from yadm to dotbot

## Context

The Win dotfiles repo currently identifies as "managed with yadm" but yadm is being replaced with [dotbot](https://github.com/anishathalye/dotbot). The `.yadm/bootstrap` file was already deleted (commit `f4a1214`). The repo uses plain git for tracking and a sophisticated PowerShell-based deployment system (SHA256 hash-based copy, not symlinks). `TODO.md` explicitly requests this migration.

**Goal**: Replace yadm with dotbot as the dotfile manager identity, use mise.toml to manage dotbot, remove all 20 files' worth of yadm references, and update bootstrap scripts.

**Key design decision**: dotbot serves as the **orchestrator** that calls into the existing `Setup-Dotfiles.ps1` deployment logic via `shell` directives. We do NOT rewrite the manifest system as dotbot YAML — the existing hash-based copy system is more sophisticated than dotbot's native features and works well on Windows without admin (no symlinks needed).

---

## Phase 1: Add dotbot infrastructure (new files)

### 1a. Create `mise.toml` (repo root)
```toml
[tools]
python = "3.12"

[tasks.bootstrap]
description = "Install dotbot and deploy dotfiles"
run = ["pip install dotbot", "dotbot -c install.conf.yaml"]

[tasks.deploy]
description = "Deploy dotfiles (dotbot must be installed)"
run = "dotbot -c install.conf.yaml"
```

### 1b. Create `install.conf.yaml` (repo root)
Dotbot config that delegates to existing PowerShell deployment:
```yaml
- defaults:
    shell:
      command: pwsh -NoProfile -ExecutionPolicy Bypass -Command
      stdin: false
      stdout: true
      stderr: true

- shell:
    - command: pwsh -NoProfile -ExecutionPolicy Bypass -File Scripts/Setup-Dotfiles.ps1
      description: Deploy dotfiles and configure environment
      stdout: true
      stderr: true
```

---

## Phase 2: Update bootstrap scripts (3 files)

### 2a. `.github/scripts/bootstrap.ps1`
- **Step 2** (lines 96-113): Replace `winget install yadm.yadm` with `pip install dotbot` (after ensuring Python is available via winget)
- **Step 3** (lines 117-141): Replace `yadm clone`/`yadm pull`/`$yadmDir` with `git clone $repoUrl $HOME` (yadm's bare-repo-to-$HOME model maps to a regular clone). Check if repo already exists via `.git` presence
- **Step 4** (lines 146-163): Replace `Join-Path $yadmDir 'bootstrap'` with `dotbot -c install.conf.yaml` invocation
- Update synopsis/description (lines 3-6)

### 2b. `Scripts/Setup-Win11.ps1`
- **Line 4**: Synopsis — remove yadm reference
- **Line 7**: Description — remove yadm reference
- **Line 65**: Phase 1 header — remove "yadm" from prerequisite list
- **Lines 89-91**: Replace `winget install yadm.yadm` with Python/dotbot install
- **Lines 99-117**: Replace `$yadmDir`, `yadm clone`, `yadm pull` with git clone + dotbot
- **Lines 125-126**: Replace `Join-Path $yadmDir 'bootstrap'` with `dotbot -c` or `Scripts/Setup-Dotfiles.ps1` direct call

### 2c. `.kilo/commands/Setup-Win11.ps1`
- Apply identical changes as 2b (parallel copy of the same script)

---

## Phase 3: Update Setup-Dotfiles.ps1

- **Line 6**: "yadm bootstrap process" -> "dotbot bootstrap process"
- **Line 8**: "via .yadm/bootstrap" -> "via dotbot"
- **Line 455**: Remove `@{ id = 'yadm.yadm'; name = 'yadm' }` from winget tools array

---

## Phase 4: Update profile.ps1

File: `user/.dotfiles/config/powershell/profile.ps1`
- **Line 90**: Change comment from "VCS aliases (git, yadm)" to "VCS aliases (git)"
- **Line 91**: Change `$vcsTools = @('git', 'yadm')` to `$vcsTools = @('git')`
- **Line 3**: Update header comment if it says "Managed by yadm"
- **Line 628**: Change "not tracked by yadm" to "not tracked in git"

---

## Phase 5: Update setup.ps1

- **Line 432**: Remove `Invoke-Winget ... 'Install yadm'` line

---

## Phase 6: Update .gitignore

- **Line 2**: "Git & yadm" -> "Git & dotbot"
- **Line 9**: Remove `.yadm/` entry

---

## Phase 7: Update documentation (12 files)

### Core docs:
1. **`AGENTS.md`** (symlinked as CLAUDE.md):
   - Line 7: "managed with [yadm](https://yadm.io/)" -> "managed with [dotbot](https://github.com/anishathalye/dotbot)"
   - Line 9: "yadm, PowerShell" -> "dotbot, PowerShell"
   - Line 24: Update `.yadm/bootstrap` description -> describe `install.conf.yaml` as dotbot entry point
   - Line 26: ".yadm/bootstrap is the bootstrap entry point" -> "install.conf.yaml is the dotbot configuration"
   - Lines 53-57: Update co-review list (replace `.yadm/bootstrap` with `install.conf.yaml`)
   - Line 80: "yadm for synced home-directory" -> "dotbot for dotfile deployment"

2. **`README.md`**: Major rewrite needed:
   - Line 16: Update description
   - Replace "yadm Usage" section (lines ~255-306) with dotbot/mise usage
   - Update installation instructions, clone commands
   - Update troubleshooting section (line ~444)
   - Replace all `yadm clone`/`yadm pull` examples with `git clone` + `mise run bootstrap`

3. **`TODO.md`**: Remove the dotbot migration item (line 1) since it's now done. Keep the "implement nohuto/win-config" item.

### Copilot/AI guidance files:
4. **`.github/copilot-instructions.md`** (lines 3, 15)
5. **`.github/instructions/windows-11-setup.instructions.md`** (lines 43-125) — rewrite flow diagram
6. **`.github/instructions/context-engineering.instructions.md`** (line 10) — update co-review reference
7. **`.github/instructions/powershell.instructions.md`** (line 55) — update co-review reference
8. **`.github/skills/win-patterns/SKILL.md`** (lines 17, 33)
9. **`.github/skills/copilot-init/SKILL.md`** (lines 3, 13, 14, 35)
10. **`.github/skills/validate/SKILL.md`** (lines 15, 33)
11. **`.claude/skills/win-patterns/SKILL.md`** (lines 22, 195)

### Other scripts with yadm comments:
12. **`Scripts/Deploy-Config.ps1`** (line 6) — comment update
13. **`Scripts/Install-Packages.ps1`** (line 8) — comment update

---

## Phase 8: Verification

1. **Grep for yadm**: `grep -ri "yadm" --include="*"` should return zero results
2. **Validate new files**: Confirm `mise.toml` and `install.conf.yaml` exist and are well-formed
3. **PSScriptAnalyzer**: Run on all modified `.ps1` files:
   - `Invoke-ScriptAnalyzer Scripts/Setup-Dotfiles.ps1`
   - `Invoke-ScriptAnalyzer Scripts/Setup-Win11.ps1`
   - `Invoke-ScriptAnalyzer .github/scripts/bootstrap.ps1`
   - `Invoke-ScriptAnalyzer user/.dotfiles/config/powershell/profile.ps1`
4. **Syntax check**: Verify `install.conf.yaml` parses as valid YAML
5. **Path check**: Verify all file paths referenced in updated docs actually exist

---

## Files modified (20) + Files created (2)

**New files:**
- `mise.toml`
- `install.conf.yaml`

**Modified files (by phase):**
- `.github/scripts/bootstrap.ps1` (Phase 2)
- `Scripts/Setup-Win11.ps1` (Phase 2)
- `.kilo/commands/Setup-Win11.ps1` (Phase 2)
- `Scripts/Setup-Dotfiles.ps1` (Phase 3)
- `user/.dotfiles/config/powershell/profile.ps1` (Phase 4)
- `setup.ps1` (Phase 5)
- `.gitignore` (Phase 6)
- `AGENTS.md` (Phase 7)
- `README.md` (Phase 7)
- `TODO.md` (Phase 7)
- `.github/copilot-instructions.md` (Phase 7)
- `.github/instructions/windows-11-setup.instructions.md` (Phase 7)
- `.github/instructions/context-engineering.instructions.md` (Phase 7)
- `.github/instructions/powershell.instructions.md` (Phase 7)
- `.github/skills/win-patterns/SKILL.md` (Phase 7)
- `.github/skills/copilot-init/SKILL.md` (Phase 7)
- `.github/skills/validate/SKILL.md` (Phase 7)
- `.claude/skills/win-patterns/SKILL.md` (Phase 7)
- `Scripts/Deploy-Config.ps1` (Phase 7)
- `Scripts/Install-Packages.ps1` (Phase 7)
