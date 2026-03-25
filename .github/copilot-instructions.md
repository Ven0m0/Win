# GitHub Copilot Instructions

This is a **Windows dotfiles and optimization suite** managed with [yadm](https://yadm.io/). Scripts target PowerShell 5.1+/7+ on Windows with administrator privileges.

See `AGENTS.md` at the repo root for the full AI assistant guide.

---

## Project Context

- **Language focus:** PowerShell, CMD/Batch, AutoHotkey v2, registry (.reg)
- **Per-language rules:** See `.github/instructions/` (applied automatically by Copilot)
- **Shared utilities:** Always use `Scripts/Common.ps1` — never duplicate its functions
- **Config location:** `user/.dotfiles/config/` (not `.config/`, which is deprecated)

---

## PowerShell Patterns

Every script follows this structure:

```powershell
#Requires -RunAsAdministrator
. "$PSScriptRoot\Common.ps1"

Request-AdminElevation
Initialize-ConsoleUI -Title "Script Name (Administrator)"
```

**Key Common.ps1 functions** (use these, don't reimplement):

```powershell
Request-AdminElevation              # Elevate if not admin
Initialize-ConsoleUI -Title "..."   # Console setup
Show-Menu -Title "..." -Options @() # Interactive menu
Get-MenuChoice -Min 1 -Max N        # Menu input
Set-RegistryValue -Path "HKLM\..." -Name "..." -Type "REG_DWORD" -Data "1"
Remove-RegistryValue -Path "HKLM\..." -Name "..."
Get-NvidiaGpuRegistryPaths          # NVIDIA GPU registry discovery
Get-FileFromWeb -URL "..." -File "C:\..."
Clear-DirectorySafe -Path "C:\..."  # Safe delete via robocopy
ConvertFrom-VDF / ConvertTo-VDF     # Steam VDF parsing
```

**Style rules:**
- OTBS braces, 2-space indent, spaces around operators and pipes
- `Set-StrictMode -Version Latest` + `$ErrorActionPreference = "Stop"` at top
- Comment-based help (`<# .SYNOPSIS .DESCRIPTION .PARAMETER .EXAMPLE #>`) on all functions
- File names: `lowercase-with-dashes.ps1`
- No hardcoded paths — use `$PSScriptRoot`, `$HOME`, `$env:*`
- No `$ErrorActionPreference = "SilentlyContinue"` globally
- No `Invoke-Expression` with untrusted input

---

## Registry Conventions

- Use NVIDIA registry path discovery: `Get-NvidiaGpuRegistryPaths`
- Always support both enable and disable (restore defaults) operations
- Key paths:
  - NVIDIA GPU class: `HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\`
  - User preferences: `HKCU\Software\`

---

## Git & yadm

- **yadm** manages dotfiles from `$HOME` (git-compatible commands)
- **git** manages this repo directly
- Commit format: `<type>: <subject>` — types: `feat`, `fix`, `docs`, `refactor`, `style`, `chore`
- Never commit: credentials, `.gitconfig` with real email, `.ssh/` keys, `local.ps1`

---

## CI

- PSScriptAnalyzer runs on all `.ps1`/`.psm1`/`.psd1` files on push/PR
- PSMinifier workflow available for script compression
- Run locally: `Invoke-ScriptAnalyzer -Path Scripts/your-script.ps1`
