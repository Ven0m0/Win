---
description: Create a Windows System Restore Point before making system changes
allowed-tools: Read, Bash
---

Create a Windows System Restore Point. $ARGUMENTS

Show the user the commands to run in an elevated PowerShell session:

```powershell
# Create restore point with auto-generated description
New-RestorePoint -Description "Before Win dotfiles changes - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"

# Or use the Common.ps1 helper directly (if already in a script context):
. "$PSScriptRoot\Scripts\Common.ps1"
New-RestorePoint -Description "Before <specific change>"
```

To list recent restore points:
```powershell
Get-ComputerRestorePoint | Select-Object -Last 10 SequenceNumber, Description, CreationTime
```

**When to create a restore point:**
- Before any batch registry changes (HKLM)
- Before running `debloat-windows.ps1`
- Before applying gaming optimizations
- Before significant script changes that modify services or system settings

Note: System Restore must be enabled on the system drive. Check with:
```powershell
Get-ComputerRestorePoint
```
If the command returns nothing, System Protection may be disabled. Enable it in System Properties > System Protection.

This complements but does not replace git-based rollback for tracked config files.
