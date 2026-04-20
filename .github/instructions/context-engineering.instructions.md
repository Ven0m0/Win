---
applyTo: "**"
---

# Context Engineering for Win

- Start with the smallest real set of files that explains the change.
- For `Scripts/*.ps1`, open the target script plus `Scripts/Common.ps1`.
- If a script deploys config or registry data, also open the referenced files under `user/.dotfiles/config/` or `Scripts/reg/`.
- For bootstrap work, review `.yadm/bootstrap`, `Scripts/Setup-Dotfiles.ps1`, `README.md`, and `AGENTS.md` together.
- For tracked config changes, read both the config file and the script that deploys or references it.
- For `.github` guidance changes, keep `.github/copilot-instructions.md` short and move detailed reusable flows into `.github/skills/` or `.github/instructions/`.
- Prefer examples from real repo paths such as `Scripts/system-update.ps1`, `user/.dotfiles/config/powershell/profile.ps1`, and `.github/workflows/powershell.yml`.
- When asking Copilot for multi-file work, name the exact repo paths involved.
- Before broad refactors, inspect the current layout with targeted file reads instead of assuming a conventional source tree.
