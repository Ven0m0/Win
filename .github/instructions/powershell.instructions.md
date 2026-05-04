---
description: PowerShell conventions for scripts, modules, profiles, and bootstrap helpers in Ven0m0/Win.
applyTo: "Scripts/**/*.ps1, Scripts/**/*.psm1, Scripts/**/*.psd1, .github/scripts/**/*.ps1, user/.dotfiles/config/powershell/**/*.ps1"
---

# PowerShell Instructions

- Reuse helpers from `Scripts/Common.ps1` before adding new utilities.
- Preserve PowerShell 5.1+ and PowerShell 7+ compatibility.
- Use environment-based paths such as `$PSScriptRoot`, `$HOME`, and `$env:*`; avoid machine-specific paths.
- Follow OTBS braces, 2-space indentation, and full cmdlet names.
- Use comment-based help on entry-point scripts and `[CmdletBinding(SupportsShouldProcess)]` for system-changing actions.
- Avoid global `$ErrorActionPreference = 'SilentlyContinue'`, untrusted `Invoke-Expression`, and bare `curl`; use `curl.exe` when needed.
- For downloads, set `$ProgressPreference = 'SilentlyContinue'` before `Invoke-WebRequest`.
- Validate each changed PowerShell file with `Invoke-ScriptAnalyzer -Path <file> -Settings PSScriptAnalyzerSettings.psd1`.
- If the changed area already has tests, run `Invoke-Pester -Path tests/ -Output Minimal`.
