# Security Rules

## Files you MUST NOT read, write, or stage

These files contain credentials or personal data. Never open, display, or commit them:

- `.gitconfig` / `.gitconfig.local` — may contain real email/identity
- `.github-personal-access-token` — OAuth token
- `user/.dotfiles/config/powershell/local.ps1` — machine-specific secrets/paths
- `.ssh/*` except `.ssh/config` — private keys
- `.gnupg/*` — GPG keyring
- `.config/gh/hosts.yml` — GitHub CLI token
- Any file matching `*.env`, `token`, `*credentials*`, `*secret*`, `*.key`, `*.pem`, `*.pfx`

## Injection prevention

- **Never** use `Invoke-Expression` (or its alias `iex`) with any variable input. Only acceptable with a literal string constant.
- **Never** construct registry paths, file paths, or command strings by concatenating unvalidated user input.
- **Never** use `$ErrorActionPreference = "SilentlyContinue"` at script scope — it silently swallows errors that indicate security failures (e.g., permission denials).

## Script safety requirements

Every script that modifies system state MUST:
1. Confirm admin rights via `Request-AdminElevation` from `Common.ps1`
2. Display what it will do before doing it
3. Require explicit user confirmation (menu selection) before destructive operations
4. Provide a "Restore defaults" option for any registry or config change

## Registry safety

- Never delete a registry key (`Remove-Item -Recurse` on a registry path) — only delete individual values via `Remove-RegistryValue`
- Writes to `HKLM\SYSTEM\CurrentControlSet\Services\*` require an explicit warning comment explaining the reboot requirement and failure risk

## Hardcoded paths are banned

Using `C:\Users\<username>\` or any absolute personal path is a security and portability violation. Always use:
- `$HOME` for user home
- `$PSScriptRoot` for script-relative paths
- `$env:WINDIR`, `$env:PROGRAMFILES`, `$env:APPDATA` for system paths
