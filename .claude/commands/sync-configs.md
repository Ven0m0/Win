---
description: Pull latest dotfile changes from remote and redeploy updated configs
allowed-tools: Read, Bash
---

Pull the latest dotfile changes from the remote repository and redeploy updated configurations. $ARGUMENTS

**Pull and redeploy everything:**
```powershell
git pull
dotbot -c install.conf.yaml
```

**Pull only (no deployment):**
```powershell
git pull
```

**Pull then deploy a specific config group:**
```powershell
git pull
pwsh -File Scripts/Setup-Dotfiles.ps1 -Target 'PowerShell profile'
```

**Force redeploy even if no changes detected:**
```powershell
git pull
dotbot -c install.conf.yaml --force
```

**Dry-run (see what would change without applying):**
```powershell
git pull
dotbot -c install.conf.yaml -p
```

**After syncing, verify the PowerShell profile loads correctly:**
```powershell
pwsh -NoProfile -Command ". $PROFILE"
```

Deployment uses SHA256 hash comparison — only files where the source differs from the destination are copied. If $ARGUMENTS mentions a specific branch, pull from that branch first: `git pull origin <branch>`.
