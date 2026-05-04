---
description: Bootstrap and Windows 11 setup rules for the Win dotfiles repository.
applyTo: ".github/scripts/bootstrap.ps1, Scripts/Setup-Win11.ps1, Scripts/Setup-Dotfiles.ps1, install.conf.yaml, Scripts/auto/autounattend*.xml, README.md"
---

# Windows 11 Setup Instructions

- Treat setup as three layers: internet bootstrap (`.github/scripts/bootstrap.ps1`), repo bootstrap (`install.conf.yaml` + `Scripts/Setup-Dotfiles.ps1`), and unattended USB (`Scripts/auto/autounattend*.xml`).
- Review `install.conf.yaml`, `Scripts/Setup-Dotfiles.ps1`, `README.md`, and `AGENTS.md` together when bootstrap behavior changes.
- Keep tracked config under `user/.dotfiles/config/`; deployment remains hash-based copy, not symlinks.
- Preserve the one-command fresh install entry point: `iwr https://raw.githubusercontent.com/Ven0m0/Win/main/.github/scripts/bootstrap.ps1 -UseBasicParsing | iex`.
- Prefer reversible changes and existing `Scripts/Common.ps1` helpers for setup logic.
- Keep `Scripts/auto/autounattend.xml` self-contained; do not add flat companion scripts beside the XML.
- After changing `Scripts/auto/autounattend*.xml`, validate with `$xml = [xml]::new(); $xml.Load('<path>')`.
- After changing `.github/` guidance or workflow files, run `npx -y @yawlabs/ctxlint --depth 3 --mcp --strict --yes`.
