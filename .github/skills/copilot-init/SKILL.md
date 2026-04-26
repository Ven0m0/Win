---
name: copilot-init
description: Refresh Copilot bootstrap assets for the Win repository so guidance matches its Windows dotfiles, PowerShell, dotbot, and registry-focused workflows.
allowed-tools: 'Read, Write, Edit, Glob, Grep, Bash'
---

# Copilot init for Win

Create or refresh the smallest set of Copilot assets that improve understanding of this repository.

## Audit first

- Confirm the real stack from `AGENTS.md`, `README.md`, `install.conf.yaml`, `Scripts/Setup-Dotfiles.ps1`, and `.github/workflows/`.
- Treat the repository as a Windows dotfiles repo built around PowerShell, dotbot, CMD or Batch files, AutoHotkey v2, registry assets, and tracked config under `user/.dotfiles/config/`.
- Do not add guidance or workflows for Bun, uv, Node app builds, or other stacks that the repo does not use.

## Expected split

- `.github/copilot-instructions.md`: short startup bootstrap only
- `AGENTS.md`: canonical repo-wide guide
- `.github/instructions/`: narrow language or topic rules
- `.github/skills/`: reusable repo workflows such as validation or recurring Windows dotfiles tasks

## Deliverables for this repo

- `.github/workflows/copilot-setup-steps.yml` tailored to the repo's actual setup needs
- concise, repo-specific instruction files
- reusable skills that point agents toward the right files and validations
- no duplicated large rule blocks across always-loaded files

## Repo-specific rules

- Keep `Scripts/Common.ps1` as the shared PowerShell helper surface.
- Keep tracked config under `user/.dotfiles/config/`.
- Review `install.conf.yaml` and `Scripts/Setup-Dotfiles.ps1` together for bootstrap changes.
- Prefer moving detailed conventions into `.github/skills/win-patterns/SKILL.md` instead of bloating always-loaded context.

## Validation

- Verify every referenced path and command exists.
- Re-run the repo commands referenced by changed guidance when practical.
- For `.github/` guidance changes, run `npx -y @yawlabs/ctxlint --depth 3 --mcp --strict --yes`.
