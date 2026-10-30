# AGENTS.md — AI Assistant Guide

`CLAUDE.md` is a symlink to this file. Edit `AGENTS.md`, never `CLAUDE.md`.

## Quick Start

| Task                     | Command                                                                      |
| ------------------------ | ---------------------------------------------------------------------------- |
| Fresh Windows 11 install | `Scripts/Setup-Win11.ps1` or `iwr ...bootstrap.ps1 \| iex`                   |
| Deploy dotfiles          | `mise run deploy` or `dotbot -c install.conf.yaml`                           |
| Deploy single config     | `pwsh -File Scripts/Setup-Dotfiles.ps1 -Target 'PowerShell profile'`         |
| Install Claude Code setup | `pwsh -File Scripts/Setup-ClaudeCode.ps1` (marketplaces/plugins/MCP servers from `user/.dotfiles/config/claude/`) |
| Debloat Windows          | `Scripts/debloat-windows.ps1`                                                |
| Validate PS file         | `Invoke-ScriptAnalyzer -Path <file> -Settings PSScriptAnalyzerSettings.psd1` |
| Run tests                | `Invoke-Pester -Path tests/ -Output Minimal`                                 |
| Run single test          | `Invoke-Pester -Path tests/<File>.Tests.ps1 -Output Detailed`                |
| Full bootstrap           | `mise run bootstrap`                                                         |

## Repository Identity

**Ven0m0/Win** — Windows dotfiles and optimization suite. PowerShell automation, tracked application config, registry tweaks, and game-specific tuning assets.

**Stack:** PowerShell 5.1+/7+, CMD/Batch, AutoHotkey v2, registry files, Windows Terminal, winget, dotbot.

**Bootstrap layers:**

1. **Internet** (`bootstrap.ps1`) — one-command entry; self-elevates, installs Git/Python/mise/uv via winget, shallow-clones to `$env:USERPROFILE\project\Win`, then chains into `Scripts/Setup-Win11.ps1` for the full setup (debloat, packages, dotbot deploy, WSL)
2. **Repo** (`install.conf.yaml` → `Scripts/Setup-Dotfiles.ps1`) — single deploy-all dotbot call (not per-target), hash-based config deployment, PATH setup. Works without admin; a failing manifest entry is caught and reported in a "STEPS THAT FAILED" summary at the end instead of aborting the run. Deploy itself runs via mise (`mise install` + `mise run bootstrap`), not bare `dotbot`

`Scripts/Setup-Win11.ps1` no longer clones the repo itself — it operates on `Split-Path -Parent $PSScriptRoot`, assuming layer 1 already put it somewhere.

Configs live in `user/.dotfiles/config/` and deploy by hash (no symlinks).

## Main Repo Areas

| Path                                      | Purpose                                                 |
| ----------------------------------------- | ------------------------------------------------------- |
| `Scripts/`                                | PowerShell automation surface                           |
| `Scripts/Common.ps1`                      | Shared helper library — always import, never duplicate  |
| `Scripts/arc-raiders/`                    | Arc Raiders game-specific scripts                       |
| `Scripts/reg/`                            | Registry `.reg` files and priority tweaks               |
| `tests/`                                  | Pester test files (`*.Tests.ps1`)                       |
| `user/.dotfiles/config/`                  | Tracked dotfile content (deploy targets)                |
| `install.conf.yaml`                       | Dotbot configuration                                    |
| `mise.toml`                                | Tool manifest — Python/uv, uvx-run dotbot, `mise run bootstrap`/`deploy` task |
| `Scripts/packages.psd1`                    | Canonical package catalog — winget/scoop/choco/Bun/npm/Cargo/PS-modules/DISM-features/Appx-removal |
| `docs/`                                   | Per-script documentation (`docs/<script>.md`)           |
| `.claude/`                                | Claude Code agents, commands, rules, skills             |
| `.github/workflows/`                      | CI pipeline definitions                                 |

**Notable scripts:**

| Script                        | Purpose                                                      |
| ----------------------------- | ------------------------------------------------------------ |
| `debloat-windows.ps1`         | Remove bloatware, disable telemetry                          |
| `system-settings-manager.ps1` | Power, visual, privacy, GPU/display, keyboard tweaks         |
| `system-maintenance.ps1`      | Maintenance hub (`-Action Defrag\|Disk\|Shader\|Extra\|All`) |
| `system-update.ps1`           | Winget + scoop update runner                                 |
| `Network-Tweaker.ps1`         | TCP/IP and adapter optimizations                             |
| `fix-system.ps1`              | Repair hub (`-Action System\|WindowsUpdate\|All`)            |
| `Get-BedrockPackUpdate.ps1`   | Report of outdated Bedrock packs/mods in LeviLauncher (read-only by default). `-Update` auto-maps new packs into `bedrock-packs.psd1` (manifest URL, sibling re-release, CurseForge search with `$env:CURSEFORGE_API_KEY` or Bitwarden `api-keys`/`curseforge`), downloads updates, backs up old packs, repoints world pack lists; supports `-WhatIf` |
| `dedupe-media.ps1`            | Remove duplicate media: fclones exact pass, czkawka fuzzy image/video passes. Run **before** `optimize-media.ps1`. Preview by default (`-Apply` to act); czkawka's redundant dup pass is opt-in via `-IncludeDup` |
| `optimize-media.ps1`          | Compress images (oxipng/jpegoptim/cwebp/gifsicle) + re-encode video to H.265/Opus (SSIM-tuned x265, CRF 28, web-optimized MP4) via ffzap (`-ThreadCount` concurrent encodes), replacing validated sources so the folder shrinks. Originals go to `-BackupPath` (default `$env:USERPROFILE\Pictures\optimize-media-bak`, must be outside the scanned tree); `-Encoder Auto\|NVENC\|x265`; `-Denoise`/`-MaxVideoDimension` are opt-in lossy filters for clips that won't otherwise shrink; `-ConvertToWebp` converts JPEG/PNG to WebP (cwebp, metadata kept) instead of in-place compression |

## High-Signal Rules

- **Reuse `Scripts/Common.ps1`** — registry, restore points, UI, GPU discovery, logging. Read the file before adding helpers; groups: Admin/UI, Output/Logging, Registry, NVIDIA/Display, System, Files/Paths, Utilities.
- **Tracked config** → always under `user/.dotfiles/config/`
- **Windows compatibility** → preserve PowerShell 5.1+/7+ support; use `$PSScriptRoot`, `$HOME`, `$env:*`
- **Reversible changes** → prefer `-Restore` / `-Undo` parameters for system modifications
- **New script names** → lowercase-with-dashes (e.g., `debloat-windows.ps1`); legacy PascalCase remains as-is
- **Guidance splits**: `AGENTS.md` canonical; `.claude/rules/` narrow constraints; `.claude/skills/` workflows; `.claude/agents/` agent identity; `.claude/commands/` documented workflows

## PowerShell Standards

Full rules in `.claude/rules/powershell.md`. Key constraints:

- `[CmdletBinding(SupportsShouldProcess)]` for any function modifying system state
- No global `$ErrorActionPreference = 'SilentlyContinue'`; no `Invoke-Expression` with variable input
- OTBS braces, 2-space indent, 115-char line limit; splatting over backtick continuation
- Full cmdlet names (`Get-ChildItem`, not `gci`); full parameter names (no positional shorthand)
- `& curl.exe` not bare `curl`; `$ProgressPreference = 'SilentlyContinue'` before web requests
- **CI enforces:** `PSAvoidGlobalAliases`, `PSAvoidUsingConvertToSecureStringWithPlainText`

## Registry & System Tweaks

Key constraints:

- `New-RestorePoint` before any HKLM changes (unless `-NoRestorePoint`)
- Use `Set-RegistryValue` / `Remove-RegistryValue` from Common.ps1, not raw `Set-ItemProperty`
- Never hardcode GPU PCI IDs — use `Get-NvidiaGpuRegistryPath`
- Avoid: `HKLM\SECURITY`, `HKLM\SAM`, `HKLM\SYSTEM\...\Lsa`

## Config Deployment

- Hash-based (SHA256) — copies only when source differs; preserve native file formats
- Template files use `##template` suffix; dotbot handles substitution
- Machine-local PS overrides: untracked `$HOME\.dotfiles\config\powershell\local.ps1`

**Tracked config areas** (`user/.dotfiles/config/`): `powershell/`, `nvidia/` (incl. `msi-afterburner/`, `nvidia-settings.ps1`), `games/arc-raiders/`, `games/bf2/`, `games/bo6/`, `games/fortnite/`, `emulators/` (dolphin, azaharplus, eden - seed-only: copied when absent, tracked copies have tokens/paths stripped), `bat/`, `cargo/`, `rtk/`, `windows-terminal/`, `cmd/`, `browser/`, `bleachbit/`, `DDU/`, `mise/`, `scoop/`, `winget-configs/`, `cursors/`, `kilo/`, `opencode/`, `wsl/`, `topgrade/`, `ohmyposh/`, `vscode/`, `legcord/`, `handbrake/`, `claude/`, `git/`, `ssh/`, `psmux/`, `obs/`

## Gotchas

- **Pester mocks on `Test-Path` do not stop `& $scriptPath` from running real files.** `Setup-Win11.Tests.ps1` invokes `debloat-windows.ps1`/`Install-Packages.ps1` by computed path; mocking `Test-Path` to return `$true` only fakes the existence check, not the invocation. Always call `Start-SetupWin11` with `-SkipDebloat -SkipPackages` in tests — omitting them can execute live debloat/package-install operations on the test machine.

## Cochange Rules

**Arc Raiders** — remaining scripts and config change together:
`Scripts/arc-raiders/ArcRaidersCommon.ps1`, `cleanup-arc-raiders.ps1`, `SkipVideosMod.ps1`, `user/.dotfiles/config/games/arc-raiders/`

**Bootstrap** — always change together: `bootstrap.ps1`, `Scripts/Setup-Win11.ps1`, `install.conf.yaml`, `Scripts/Setup-Dotfiles.ps1`, `README.md` (setup sections). `bootstrap.ps1` and `Setup-Win11.ps1` share a parameter surface (`-Unattended -Force -SkipWingetTools -SkipWSL -SkipPackages -SkipDebloat`) that must stay in sync since one forwards to the other (`tests/Setup-Win11.Tests.ps1` asserts it by AST). `Install-WingetTool` (Common.ps1) is the single winget install policy; `bootstrap.ps1` keeps its own copy because it cannot dot-source Common.ps1 before the repo is cloned. Per-app/game resolvers and deploys live in `Scripts/Setup-Dotfiles.Apps.ps1`, dot-sourced by `Setup-Dotfiles.ps1`.

## Validation Matrix

| Changed Area                              | Primary Check                                                                | Secondary                                                      |
| ----------------------------------------- | ---------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `Scripts/**/*.ps1`                        | `Invoke-ScriptAnalyzer -Path <file> -Settings PSScriptAnalyzerSettings.psd1` | Pester if test exists                                          |
| `install.conf.yaml`                       | Path resolution, hash logic integrity                                        | `README.md` consistency                                        |
| `Scripts/Setup-Dotfiles.ps1`              | ScriptAnalyzer + manifest review                                             | Config paths verification                                      |
| `user/.dotfiles/config/*`                 | Format preservation (no cosmetic re-serialization)                           | Manifest correctness                                           |
| `.claude/` guidance changes               | JSON/YAML syntax; correct paths                                              | `npx -y @yawlabs/ctxlint --depth 5 --mcp --strict --fix --yes` |
| `.github/workflows/*`                     | YAML syntax, tool availability                                               | —                                                              |

## CI Pipelines

| Workflow               | Trigger                      | Checks                                        |
| ---------------------- | ---------------------------- | --------------------------------------------- |
| `ci.yml`               | push to/PR on `main`         | PSScriptAnalyzer + full Pester suite, posts check annotations/inline comments |
| `lint-format-test.yml` | push/PR on `*.ps1`           | Format check + `dotbot --dry-run` + Setup-Dotfiles `-WhatIf` |
| `ps-format.yml`        | push/PR on `*.ps1/psm1/psd1` | Formatting (indent, BOM, trailing whitespace) |
| `reg-validate.yml`     | push/PR on `*.reg`           | Registry file validation                      |

**Pester:** 39 test files in `tests/`. Run `Invoke-Pester -Path tests/ -Output Minimal`.

## Agent Delegation

| Agent                  | Specialization                                       | When to Delegate                                               |
| ---------------------- | ---------------------------------------------------- | -------------------------------------------------------------- |
| `powershell-agent`     | Script authoring, refactoring, CI compliance         | New/modified `.ps1`, function extraction, ScriptAnalyzer fixes |
| `windows-optimizer`    | Registry tweaks, debloating, gaming, NVIDIA GPU      | System modifications, service management, registry changes     |
| `config-deployer`      | Dotbot YAML, tracked config, deployment path mapping | `install.conf.yaml` edits, new tracked configs                 |
| `code-reviewer`        | Read-only review, best-practice verification         | Before merging PS changes, after refactoring                   |
| `security-auditor`     | Credential detection, unsafe pattern flagging        | Before committing scripts touching credentials or elevation    |
| `documentation-writer` | Markdown docs, README, AGENTS.md maintenance         | New commands/agents, README sync after features                |
| `winget-package-curator` | Read-only audit of `packages.psd1` / `install.conf.yaml` package IDs | Packages added/removed, before a release          |
| `bedrock-data-analyst` | Read-only Minecraft Bedrock world (LevelDB) inspection | "What's in this world", entity/inventory lookups             |
| `Explore`              | Read-only exploration, symbol location               | Finding where a function lives, mapping dependencies           |

Load relevant skills first: `win-patterns`, `validation`.

## Skills & Rules

**Skills** (`.claude/skills/`):
`win-patterns`, `validation`, `powershell-windows`, `ps-script-validator`, `ps-dedupe-cleanup`, `dotbot-manifest-check`, `winget-audit`

**Rules** (`.claude/rules/`):
`bootstrap-deployment.md`, `powershell.md`, `skills.md`, `windows-os.md`

**Commands** (`.claude/commands/`):
`audit-security`, `backup-configs`, `debloat-windows`, `deploy-configs`, `invoke-scriptanalyzer`, `lint-guidance`, `migrate-config`, `optimize-repository`, `review-code`, `sync-configs`, `test-environment`, `update-changelog`, `validate-changes`

## Git & Commits

Format: `<type>: <subject>` — types: `feat`, `fix`, `docs`, `refactor`, `style`, `chore`, `perf`

Examples: `feat: add GPU monitoring script`, `fix: harden bootstrap path handling (#52)`

**Never** commit: credentials, tokens, private keys, machine-specific overrides, exported hive `.reg` files, hardcoded `C:\Users\...` paths (use `$HOME`, `$env:USERPROFILE`).

## AI Guidance Changes

- Broader rules → `AGENTS.md`; narrow rules → `.claude/rules/`
- After editing `.claude/` guidance: run `npx -y @yawlabs/ctxlint --depth 5 --mcp --strict --fix --yes`

## Implementation Plans

`PLAN.md` (repo root) is generated with the `superpowers:writing-plans` skill — pass it the root path explicitly, since its default target is `docs/superpowers/plans/`. Use `oh-my-claudecode:plan` only for interview-style scoping or high-stakes consensus review of a plan before it's written; hand the result to `writing-plans` to produce the actual `PLAN.md`.
