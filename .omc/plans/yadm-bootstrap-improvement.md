# Plan: Improved yadm Setup & Autobootstrap

**Date:** 2026-03-30
**Goal:** Full one-command setup — clone repo, run bootstrap, walk away with a working environment
**Automation level:** Fully automated with optional `-WhatIf` preview

---

## Requirements Summary

### Current gaps in `.yadm/bootstrap`
1. **Tools checked but not installed** — step 5 reports missing tools, never installs them
2. **Configs skip if they already exist** — can't re-run to update after dotfile changes
3. **Covers only 2 configs** — PS profile + Windows Terminal; NVIDIA, BleachBit, games configs untouched
4. **Execution policy manual** — tells user to run `allow-scripts.cmd`, doesn't fix it
5. **PATH addition is interactive** — prompts user with `Read-Host`, breaks automation
6. **No `-WhatIf` support** — can't preview what would change without applying

### What "done" looks like
- `yadm clone <repo> && yadm bootstrap` → fully configured machine, no manual steps
- Re-runnable: subsequent runs update changed configs, skip unchanged ones
- `-WhatIf` shows exactly what would be copied/installed without touching anything
- All configs in `user/.dotfiles/config/` have a known destination and are deployed

---

## Acceptance Criteria

- [ ] Bootstrap completes without any `Read-Host` prompts when run non-interactively
- [ ] All winget tools install if missing; skip if already installed (exit code 0 in both cases)
- [ ] All config files in `user/.dotfiles/config/` have an explicit destination mapping
- [ ] Re-running bootstrap overwrites changed configs (verified by hash comparison)
- [ ] `-WhatIf` prints all planned actions and exits without writing any files
- [ ] Execution policy set to `RemoteSigned` for CurrentUser automatically
- [ ] Scripts directory added to PATH without prompting
- [ ] Bootstrap exits non-zero on any hard failure (bad winget exit code, missing source file)
- [ ] `$ErrorActionPreference = 'Stop'` throughout (consistent with `setup.ps1` convention)
- [ ] Total runtime under 3 minutes on a machine that already has all tools installed

---

## Architecture

```
yadm clone
    └─▶  .yadm/bootstrap  (thin wrapper — admin elevation + call)
              └─▶  Scripts/Setup-Dotfiles.ps1  (canonical implementation)
                        ├── Phase 1: Prerequisites & execution policy
                        ├── Phase 2: Install tools via winget
                        ├── Phase 3: Deploy all configs
                        ├── Phase 4: PATH + directory setup
                        └── Phase 5: Verification summary
```

`setup.ps1` (existing interactive menu script) is **not changed** — it serves a different purpose (ongoing optimization). The new `Setup-Dotfiles.ps1` handles initial machine provisioning only.

---

## Config Destination Map

All sources relative to `$HOME\user\.dotfiles\config\`:

| Source | Destination |
|--------|------------|
| `powershell\profile.ps1` | `$PROFILE` |
| `windows-terminal\settings.json` | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` |
| `bleachbit\cleaners\*.xml` | `%APPDATA%\BleachBit\cleaners\` (each file) |
| `nvidia\` | TBD — requires exploring NVIDIA Inspector paths (see Phase 3 implementation note) |
| `games\bf2\` | TBD — requires BF2 config path research |
| `games\bo6\`, `games\bo7\` | TBD — COD config paths vary by install |
| `cmd\` | `$HOME` (cmd aliases/doskey macros) |
| `firefox\` | TBD — Firefox profile path varies |
| `brave\` | TBD — Brave user data path |

**Implementation note:** Mark TBD destinations as `[SKIP - destination unknown]` with a warning in the first pass. Add destinations incrementally as they are confirmed.

---

## Implementation Steps

### Step 1 — Create `Scripts/Setup-Dotfiles.ps1`

File: `Scripts/Setup-Dotfiles.ps1`

Structure:
```powershell
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param(
  [switch]$WhatIf
)

. "$PSScriptRoot\Common.ps1"
Request-AdminElevation

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$configRoot = Join-Path $HOME 'user\.dotfiles\config'

# --- Helper: deploy one config file ---
function Deploy-Config { ... }  # hash-compare, copy if different, WhatIf-aware

# --- Phase 1: Prerequisites ---
# Set execution policy RemoteSigned for CurrentUser (non-interactive)

# --- Phase 2: Tool installation ---
# winget install each tool silently; exit codes 0 and -1978335189 (already installed) both = success

# --- Phase 3: Config deployment ---
# Deploy each known config using Deploy-Config helper
# Warn (don't fail) for TBD destinations

# --- Phase 4: PATH + directories ---
# Add Scripts dir to PATH (no prompt)
# Create .local\bin, .cache, Projects

# --- Phase 5: Summary ---
# Print ✓/⚠/✗ for each action taken
```

Key implementation details:
- `Deploy-Config` computes SHA256 of source vs destination; skips if identical, copies if different
- `[CmdletBinding(SupportsShouldProcess)]` gives automatic `-WhatIf` support via `$PSCmdlet.ShouldProcess()`
- winget silent install: `winget install --id $id --silent --accept-source-agreements --accept-package-agreements`
- winget already-installed exit code: `-1978335189` (0x8A150021) — treat as success
- Execution policy: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force`

### Step 2 — Rewrite `.yadm/bootstrap`

Replace the 165-line implementation with a thin wrapper:
```powershell
#!/usr/bin/env pwsh
# yadm bootstrap — delegates to Scripts/Setup-Dotfiles.ps1
$setupScript = Join-Path $HOME 'Scripts\Setup-Dotfiles.ps1'
if (-not (Test-Path $setupScript)) {
  Write-Error "Setup-Dotfiles.ps1 not found. Ensure Scripts/ is in your HOME."
  exit 1
}
& $setupScript @args
```

Pass-through `@args` so `-WhatIf` works end-to-end: `yadm bootstrap -- -WhatIf`

### Step 3 — Expand winget tool list

Current 4 tools → expand to cover the full dev environment:

```powershell
$tools = @(
  @{id="Git.Git";                      name="Git"},
  @{id="Microsoft.PowerShell";         name="PowerShell 7+"},
  @{id="Microsoft.WindowsTerminal";    name="Windows Terminal"},
  @{id="Microsoft.VisualStudioCode";   name="VS Code"},
  @{id="Neovim.Neovim";                name="Neovim"},        # if in use
  @{id="yadm.yadm";                    name="yadm"}           # self-bootstrap
)
```

Confirm actual tool list with user before finalizing — only add tools that are genuinely used.

### Step 4 — Research TBD config destinations

Before deploying NVIDIA/games/browser configs, verify paths:
- NVIDIA Inspector: check `user/.dotfiles/config/nvidia/` files and typical install locations
- BF2/BO6/BO7: check game config directories (Documents\CoD, etc.)
- Firefox: `%APPDATA%\Mozilla\Firefox\Profiles\` (profile-specific, may need special handling)

For any config where destination is ambiguous: **skip with a `[WARN]` message**, not a hard failure.

### Step 5 — Update `README.md` and `AGENTS.md`

Update bootstrap documentation to reflect new one-command setup:
```
yadm clone https://github.com/Ven0m0/Win.git
yadm bootstrap           # full setup
yadm bootstrap -- -WhatIf  # preview only
```

---

## Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|-----------|
| winget not available on fresh Windows | Low (Win 11 ships with it) | Detect and print install URL: `aka.ms/getwinget` |
| Config destination paths change (WT package name) | Medium | Glob for `Microsoft.WindowsTerminal_*` instead of exact package name |
| Game config paths vary by install location | High | Skip games configs in first pass; add after path research |
| Bootstrap runs without admin → Set-ExecutionPolicy fails | Medium | Check admin status, re-launch elevated if needed (Common.ps1 `Request-AdminElevation`) |
| `$ErrorActionPreference = 'Stop'` breaks winget exit code handling | Medium | Wrap winget calls in try/catch, treat known exit codes as success |
| Overwriting existing configs user has customized | Low | Hash-compare skips unchanged; only overwrites if source differs. User can review `git diff` after |

---

## Verification Steps

```powershell
# 1. Dry run — should print all planned actions, exit 0, touch nothing
yadm bootstrap -- -WhatIf

# 2. First run on clean machine simulation (rename PROFILE, delete WT settings)
Rename-Item $PROFILE "$PROFILE.bak"
& Scripts\Setup-Dotfiles.ps1
# Verify: $PROFILE exists, WT settings present, tools installed

# 3. Re-run idempotency — should report "already up to date" for all items
& Scripts\Setup-Dotfiles.ps1
# Verify: no files overwritten (hash-compare = skip)

# 4. Drift scenario — modify a deployed config, re-run
Add-Content $PROFILE "# test"
& Scripts\Setup-Dotfiles.ps1
# Verify: profile restored to source version

# 5. Lint
Invoke-ScriptAnalyzer -Path Scripts\Setup-Dotfiles.ps1

# 6. Confirm PATH addition
[Environment]::GetEnvironmentVariable('Path', 'User') | Should -Match 'Scripts'
```

---

## File Changes

| File | Action |
|------|--------|
| `Scripts/Setup-Dotfiles.ps1` | **Create** — canonical setup implementation |
| `.yadm/bootstrap` | **Rewrite** — thin wrapper calling Setup-Dotfiles.ps1 |
| `README.md` | **Update** — bootstrap/quickstart section |
| `AGENTS.md` | **Update** — Bootstrap Process section |

**Not changed:** `setup.ps1` (interactive optimization tool — separate concern)

---

## Out of Scope

- Migrating to chezmoi (evaluated separately, not recommended at this time)
- Automating yadm clone itself (user still runs `yadm clone` manually)
- Windows registry optimization tweaks (handled by `setup.ps1` interactively)
- Symlinks vs Copy-Item — keep Copy-Item for Windows compatibility
