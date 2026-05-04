# Windows 11 Setup Rules for Claude Work in Ven0m0/Win

Apply these when Claude edits bootstrap or setup files such as `.github/scripts/bootstrap.ps1`, `Scripts/Setup-Win11.ps1`, `Scripts/Setup-Dotfiles.ps1`, `install.conf.yaml`, `Scripts/auto/autounattend*.xml`, or setup sections in `README.md`.

## Bootstrap Model

- Treat setup as three layers: internet bootstrap (`.github/scripts/bootstrap.ps1`), repo bootstrap (`install.conf.yaml` + `Scripts/Setup-Dotfiles.ps1`), and unattended USB (`Scripts/auto/autounattend*.xml`).
- Review `install.conf.yaml`, `Scripts/Setup-Dotfiles.ps1`, `README.md`, and `AGENTS.md` together when bootstrap behavior changes.
- Keep tracked config under `user/.dotfiles/config/`; deployment remains hash-based copy, not symlinks.
- Preserve the one-command entry point:

```powershell
iwr https://raw.githubusercontent.com/Ven0m0/Win/main/.github/scripts/bootstrap.ps1 -UseBasicParsing | iex
```

## Avoid

- Flat companion scripts beside `Scripts/auto/autounattend.xml`
- New bootstrap-only helpers when `Scripts/Common.ps1` already covers the behavior
- Machine-specific paths or irreversible setup changes

## Validation

- Validate unattended XML with `$xml = [xml]::new(); $xml.Load('<path>')`.
- For `.github/` guidance or workflow changes, run `npx -y @yawlabs/ctxlint --depth 3 --mcp --strict --yes`.
