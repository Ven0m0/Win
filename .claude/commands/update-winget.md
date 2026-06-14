---
description: Update all winget-installed packages to their latest versions
allowed-tools: Read, Bash
---

Update winget-installed packages to the latest versions. $ARGUMENTS

**Check what's upgradable (no changes):**
```powershell
winget upgrade --source winget
```

**Upgrade all packages:**
```powershell
winget upgrade --all --silent --accept-package-agreements --accept-source-agreements --source winget
```

**Upgrade a specific package:**
```powershell
winget upgrade <PackageId> --silent --accept-package-agreements
```

**Upgrade all except specific packages:**
```powershell
# Get list first
winget upgrade --source winget

# Upgrade everything except pinned packages
winget upgrade --all --silent --accept-package-agreements --accept-source-agreements --source winget `
  --exclude Git.Git --exclude Microsoft.PowerShell
```

**Include Microsoft Store apps:**
```powershell
winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
# (omit --source winget to include Store sources)
```

If $ARGUMENTS mentions specific packages, show the targeted upgrade command for those packages. If the user wants to see what packages are tracked in the repo's install manifest, read `user/.dotfiles/config/winget-configs/` or `Scripts/Install-Packages.ps1`.
