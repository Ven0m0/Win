---
description: Show how to set PowerShell execution policy safely for running repository scripts
allowed-tools: Read, Bash
---

Set or check PowerShell execution policy for running scripts in this repository. $ARGUMENTS

**Recommended setting** (`RemoteSigned` at `CurrentUser` — no admin required):
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

**Verify current policies across all scopes:**
```powershell
Get-ExecutionPolicy -List
```

**Other scenarios:**

```powershell
# Machine-wide (requires admin)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

# Reset to system defaults
Set-ExecutionPolicy -ExecutionPolicy Undefined -Scope CurrentUser -Force

# View what policy is in effect for the current session
Get-ExecutionPolicy
```

**Policy reference:**

| Policy | Effect |
|--------|--------|
| `RemoteSigned` | Local scripts run freely; downloaded scripts require a signature (recommended) |
| `AllSigned` | All scripts require a digital signature |
| `Restricted` | No scripts — interactive commands only |
| `Unrestricted` | All scripts run with a warning prompt |
| `Undefined` | Inherits from parent scope |

Repository scripts require at least `RemoteSigned` at `CurrentUser` or `LocalMachine`. The bootstrap script (`Scripts/Setup-Win11.ps1`) sets this automatically during initial setup.
