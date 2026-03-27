# Architecture Rules

## Module boundary: Common.ps1 is the only shared library

- `Scripts/Common.ps1` is the single shared utility module. All scripts dot-source it: `. "$PSScriptRoot\Common.ps1"`
- If logic is used in two or more scripts, it MUST be extracted to `Common.ps1`, not copy-pasted
- Do not create additional `*.psm1` modules unless there is a compelling reason (e.g., the `minify-ps1/` submodule is pre-existing — don't add peers)

## Where new files go

| Artifact | Location |
|---|---|
| New PowerShell scripts | `Scripts/` (top level, `lowercase-with-dashes.ps1`) |
| Shared utility functions | `Scripts/Common.ps1` |
| Registry `.reg` files | `Scripts/reg/` |
| User config files | `user/.dotfiles/config/<app>/` |
| PowerShell profile | `user/.dotfiles/config/powershell/profile.ps1` |
| Windows Terminal config | `user/.dotfiles/config/windows-terminal/` |
| Game configs | `user/.dotfiles/config/games/<game-name>/` |
| GitHub Actions workflows | `.github/workflows/` |
| Copilot instructions | `.github/instructions/` |

## Deprecated paths — never use

- `.config/` at repo root — deprecated, use `user/.dotfiles/config/` instead
- Any config file at repo root that should be under `user/.dotfiles/config/`

## Script structure requirement

Every script in `Scripts/` that modifies system state must follow the interactive menu loop pattern (not a one-shot script):

```
header (#Requires, dot-source Common.ps1)
→ Request-AdminElevation
→ Initialize-ConsoleUI
→ define functions (Enable-X, Disable-X, Show-Status)
→ while ($true) { Show-Menu → Get-MenuChoice → switch }
```

One-shot scripts (no menu) are only acceptable for utilities called from other scripts or CI.

## Import order

1. `#Requires` directives
2. `. "$PSScriptRoot\Common.ps1"` dot-source
3. Function definitions
4. Top-level execution (elevation check, menu loop)

## What NOT to touch

- `Scripts/minify-ps1/` — PSMinifier module, managed by CI and Renovate. Don't modify manually.
- `Scripts/win-iso/` — standalone ISO tooling with its own conventions
- `.github/workflows/*.yml` — CI config; only change when adding a new workflow or updating action versions (use Renovate/Dependabot)
- `renovate.json` — dependency update config managed by Renovate bot
