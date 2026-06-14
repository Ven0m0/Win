---
description: Guide a complete fresh Windows 11 setup using the bootstrap script or local Scripts/Setup-Win11.ps1
allowed-tools: Read, Bash
---

Guide a complete Windows 11 setup from fresh install or existing machine. $ARGUMENTS

**Option A — Fresh machine, one-liner from internet:**
```powershell
iwr https://raw.githubusercontent.com/Ven0m0/Win/main/bootstrap.ps1 -UseBasicParsing | iex
```
This self-elevates, installs winget/Git/PowerShell 7, clones the repo, and runs the full bootstrap.

**Option B — Repo already cloned, run locally:**
```powershell
pwsh -File Scripts\Setup-Win11.ps1
```

**Flags:**

| Flag | Effect |
|------|--------|
| `-Unattended` | No prompts, accept all defaults |
| `-SkipWSL` | Skip WSL2 installation |
| `-SkipWingetTools` | Skip winget package installation |
| `-Force` | Re-run even if already configured |

**What the bootstrap does:**
1. Elevates to administrator
2. Installs winget if missing
3. Installs Git, PowerShell 7+ via winget
4. Clones `https://github.com/Ven0m0/Win.git` to `$HOME\Win`
5. Runs `dotbot -c install.conf.yaml` to deploy all configs
6. Offers WSL2 installation

**After setup, verify:**
```powershell
pwsh -NoProfile -Command ". $PROFILE"  # profile loads without errors
git --version
code --version
wt --version
```

Read `Scripts/Setup-Win11.ps1` for the full implementation details and the current winget package list.
