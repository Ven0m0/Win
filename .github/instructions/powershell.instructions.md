---
applyTo: "**/*.ps1,**/*.psm1,**/*.psd1"
---

# PowerShell Guidelines for Win

These instructions apply to repository PowerShell files such as `Scripts/*.ps1`, `setup.ps1`, and tracked PowerShell config under `user/.dotfiles/config/`.

## Repository patterns

- Reuse helpers from `Scripts/Common.ps1` instead of duplicating shared logic.
- Match the repository style: OTBS braces, 2-space indentation, and full cmdlet names.
- Preserve Windows PowerShell 5.1 and PowerShell 7+ compatibility.
- Prefer environment-based paths such as `$PSScriptRoot`, `$HOME`, and `$env:*`.
- Keep new tracked config in `user/.dotfiles/config/`.

## Script structure

- Use `Set-StrictMode -Version Latest` and set `$ErrorActionPreference = 'Stop'` in standalone scripts when appropriate.
- Follow the existing admin elevation pattern used by scripts in `Scripts/` when the task changes machine state.
- Use comment-based help for public functions and entry-point scripts.
- Prefer one focused function per operation instead of long linear blocks.

## Parameters and output

- Use approved Verb-Noun function names and PascalCase parameter names.
- Use `[switch]` for boolean flags.
- Validate limited options with `ValidateSet` and required strings with `ValidateNotNullOrEmpty` when it helps.
- Return rich objects for automation scenarios; use formatted host output only for interactive status.
- Use `Write-Verbose`, `Write-Warning`, and structured errors instead of hiding failures.

## Safety and error handling

- Use `SupportsShouldProcess` for operations that change the system, registry, or files.
- In advanced functions, prefer `$PSCmdlet.WriteError()` or `$PSCmdlet.ThrowTerminatingError()` over loose string errors.
- Avoid global `$ErrorActionPreference = 'SilentlyContinue'`.
- Avoid `Invoke-Expression` with untrusted input.
- Check external command exit codes when calling tools such as `reg.exe`, `winget`, or other Windows utilities.

## Shared helpers to prefer

Reach for existing helpers in `Scripts/Common.ps1` before adding new ones, especially for:

- registry reads and writes
- restore point creation
- downloads and temp files
- safe directory cleanup
- NVIDIA registry discovery
- VDF parsing and writing

## Performance and maintainability

- Prefer `[System.Collections.Generic.List[T]]::new()` when building large collections.
- Keep related config deployment logic close to the script that owns it.
- When touching bootstrap behavior, review `install.conf.yaml` and `Scripts/Setup-Dotfiles.ps1` together.

## Validation

- Run `Invoke-ScriptAnalyzer -Path <changed-script>` for every changed PowerShell file.
- Use Pester only when tests already exist for the affected area or when you add new testable logic.
