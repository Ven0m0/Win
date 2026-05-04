---
name: bootstrap-deployment
description: Use when changing Win bootstrap entry points, dotbot deployment, or Windows 11 setup guidance.
allowed-tools: 'Read, Glob, Grep, Bash(git:*)'
---

# Bootstrap Deployment

Use this skill when the task touches `.github/scripts/bootstrap.ps1`, `Scripts/Setup-Win11.ps1`, `Scripts/Setup-Dotfiles.ps1`, `install.conf.yaml`, or tracked config deployment.

## Audit together

- `.github/scripts/bootstrap.ps1`
- `install.conf.yaml`
- `Scripts/Setup-Dotfiles.ps1`
- `README.md`
- `AGENTS.md`

## Repo-specific expectations

- Internet bootstrap installs prerequisites, clones the repo, then delegates to dotbot.
- Repo bootstrap is `install.conf.yaml` calling `Scripts/Setup-Dotfiles.ps1`.
- Tracked config stays under `user/.dotfiles/config/` and deploys by SHA256 hash comparison.
- Reuse `Scripts/Common.ps1` helpers instead of new bootstrap-only utilities.
- Preserve PowerShell 5.1+/7+ compatibility and environment-based paths.

## Validation

- Verify every referenced source path exists under `user/.dotfiles/config/`.
- For bootstrap PowerShell edits, run `Invoke-ScriptAnalyzer -Path <file> -Settings PSScriptAnalyzerSettings.psd1`.
- Re-run the narrowest repo command that matches the change:
  - `dotbot -c install.conf.yaml`
  - `pwsh -File Scripts/Setup-Dotfiles.ps1 -Target 'PowerShell profile' -SkipWingetTools -SkipWSL`
- For unattended setup changes, validate `Scripts/auto/autounattend*.xml` with `$xml = [xml]::new(); $xml.Load('<path>')`.
- For `.github/` guidance changes, run `npx -y @yawlabs/ctxlint --depth 3 --mcp --strict --yes`.
