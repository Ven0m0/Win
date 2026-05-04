# PowerShell Rules for Claude Work in Ven0m0/Win

Apply these when Claude edits PowerShell files in this repository: `Scripts/**/*.ps1`, `*.psm1`, `*.psd1`, `.github/scripts/**/*.ps1`, and `user/.dotfiles/config/powershell/**/*.ps1`.

## Required Practices

- Reuse helpers from `Scripts/Common.ps1` before adding new utilities.
- Preserve PowerShell 5.1+ and PowerShell 7+ compatibility.
- Use environment-based paths such as `$PSScriptRoot`, `$HOME`, and `$env:*`; avoid machine-specific paths.
- Keep OTBS braces, 2-space indentation, and full cmdlet names.
- Use comment-based help on entry-point scripts and `[CmdletBinding(SupportsShouldProcess)]` for system-changing actions.
- Set `$ProgressPreference = 'SilentlyContinue'` before `Invoke-WebRequest`.

## Avoid

- Global `$ErrorActionPreference = 'SilentlyContinue'`
- Untrusted `Invoke-Expression`
- Bare `curl` in PowerShell; use `curl.exe`
- Hardcoded user paths such as `C:\Users\...`

## Validation

- Run `Invoke-ScriptAnalyzer -Path <file> -Settings PSScriptAnalyzerSettings.psd1` for changed PowerShell files.
- If the changed area already has tests, run `Invoke-Pester -Path tests/ -Output Minimal`.
