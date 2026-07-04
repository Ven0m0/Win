# AGENTS.md — AI Assistant Guide

`CLAUDE.md` is a symlink to this file. Edit `AGENTS.md`, never `CLAUDE.md`.

## Quick Start

| Task                     | Command                                                                      |
| ------------------------ | ---------------------------------------------------------------------------- |
| Fresh Windows 11 install | `Scripts/Setup-Win11.ps1` or `iwr ...bootstrap.ps1 \| iex`                   |
| Deploy dotfiles          | `mise run deploy` or `dotbot -c install.conf.yaml`                           |
| Deploy single config     | `pwsh -File Scripts/Setup-Dotfiles.ps1 -Target 'PowerShell profile'`         |
| Debloat Windows          | `Scripts/debloat-windows.ps1`                                                |
| Validate PS file         | `Invoke-ScriptAnalyzer -Path <file> -Settings PSScriptAnalyzerSettings.psd1` |
| Run tests                | `Invoke-Pester -Path tests/ -Output Minimal`                                 |
| Run single test          | `Invoke-Pester -Path tests/<File>.Tests.ps1 -Output Detailed`                |
| Full bootstrap           | `mise run bootstrap`                                                         |

## Repository Identity

**Ven0m0/Win** — Windows dotfiles and optimization suite. PowerShell automation, tracked application config, registry tweaks, and game-specific tuning assets.

**Stack:** PowerShell 5.1+/7+, CMD/Batch, AutoHotkey v2, registry files, Windows Terminal, winget, dotbot.

**Bootstrap layers:**

1. **Internet** (`bootstrap.ps1`) — one-command entry; self-elevates, installs prereqs, clones repo
2. **Repo** (`install.conf.yaml` → `Scripts/Setup-Dotfiles.ps1`) — winget packages, hash-based config deployment, PATH setup
3. **Unattended USB** (`Scripts/auto/autounattend-windows10.xml`) — fully self-contained; no companion flat files

Configs live in `user/.dotfiles/config/` and deploy by hash (no symlinks).

## Main Repo Areas

| Path                                      | Purpose                                                 |
| ----------------------------------------- | ------------------------------------------------------- |
| `Scripts/`                                | PowerShell automation surface                           |
| `Scripts/Common.ps1`                      | Shared helper library — always import, never duplicate  |
| `Scripts/arc-raiders/`                    | Arc Raiders game-specific scripts                       |
| `Scripts/reg/`                            | Registry `.reg` files and priority tweaks               |
| `Scripts/auto/autounattend-windows10.xml` | Unattended Windows 10 USB installer                     |
| `tests/`                                  | Pester test files (`*.Tests.ps1`)                       |
| `setup.Tests.ps1`                         | Root-level Pester tests                                 |
| `user/.dotfiles/config/`                  | Tracked dotfile content (deploy targets)                |
| `install.conf.yaml`                       | Dotbot configuration                                    |
| `.kilo/`                                  | Kilo AI configuration (skills, agents, rules, commands) |
| `.github/workflows/`                      | CI pipeline definitions                                 |

**Notable scripts:**

| Script                        | Purpose                                                      |
| ----------------------------- | ------------------------------------------------------------ |
| `debloat-windows.ps1`         | Remove bloatware, disable telemetry                          |
| `system-settings-manager.ps1` | Power, visual, privacy, GPU/display, keyboard tweaks         |
| `system-maintenance.ps1`      | Maintenance hub (`-Action Defrag\|Disk\|Shader\|Extra\|All`) |
| `system-update.ps1`           | Winget + scoop update runner                                 |
| `Network-Tweaker.ps1`         | TCP/IP and adapter optimizations                             |
| `shell-setup.ps1`             | Shell environment configuration                              |
| `fix-system.ps1`              | Repair hub (`-Action System\|WindowsUpdate\|All`)            |
| `DLSS-force-latest.ps1`       | Force latest DLSS version across games                       |
| `New-SteamShortcut.ps1`       | Steam shortcut creator                                       |
| `encode-av1.ps1`              | Batch-encode MP4 → AV1/Opus MKV                              |

## High-Signal Rules

- **Reuse `Scripts/Common.ps1`** — registry, restore points, UI, GPU discovery, logging. Read the file before adding helpers; groups: Admin/UI, Output/Logging, Registry, NVIDIA/Display, System, Files/Paths, Utilities.
- **Tracked config** → always under `user/.dotfiles/config/`
- **Windows compatibility** → preserve PowerShell 5.1+/7+ support; use `$PSScriptRoot`, `$HOME`, `$env:*`
- **Reversible changes** → prefer `-Restore` / `-Undo` parameters for system modifications
- **New script names** → lowercase-with-dashes (e.g., `debloat-windows.ps1`); legacy PascalCase remains as-is
- **Guidance splits**: `AGENTS.md` canonical; `.kilo/rules/` + `.claude/rules/` narrow constraints; `.claude/skills/` workflows; `.kilo/agents/` agent identity; `.kilo/commands/` documented workflows

## PowerShell Standards

Full rules in `.kilo/rules/powershell.md`. Key constraints:

- `[CmdletBinding(SupportsShouldProcess)]` for any function modifying system state
- No global `$ErrorActionPreference = 'SilentlyContinue'`; no `Invoke-Expression` with variable input
- OTBS braces, 2-space indent, 115-char line limit; splatting over backtick continuation
- Full cmdlet names (`Get-ChildItem`, not `gci`); full parameter names (no positional shorthand)
- `& curl.exe` not bare `curl`; `$ProgressPreference = 'SilentlyContinue'` before web requests
- **CI enforces:** `PSAvoidGlobalAliases`, `PSAvoidUsingConvertToSecureStringWithPlainText`

## Registry & System Tweaks

Full rules in `.kilo/rules/registry-security.md`. Key constraints:

- `New-RestorePoint` before any HKLM changes (unless `-NoRestorePoint`)
- Use `Set-RegistryValue` / `Remove-RegistryValue` from Common.ps1, not raw `Set-ItemProperty`
- Never hardcode GPU PCI IDs — use `Get-NvidiaGpuRegistryPath`
- Avoid: `HKLM\SECURITY`, `HKLM\SAM`, `HKLM\SYSTEM\...\Lsa`

## Config Deployment

- Hash-based (SHA256) — copies only when source differs; preserve native file formats
- Template files use `##template` suffix; dotbot handles substitution
- Machine-local PS overrides: untracked `$HOME\.dotfiles\config\powershell\local.ps1`

**Tracked config areas** (`user/.dotfiles/config/`): `powershell/`, `nvidia/` (incl. `msi-afterburner/`), `games/arc-raiders/`, `games/bf2/`, `games/bo6/`, `games/fortnite/`, `games/minecraft/`, `windows-terminal/`, `cmd/`, `browser/`, `bleachbit/`, `DDU/`, `mise/`, `nvidia-inspector/`, `scoop/`, `winget-configs/`, `cursors/`, `kilo/`, `opencode/`, `wsl/`

## Cochange Rules

**Arc Raiders** — all six scripts and config change together:
`arc-raiders/ARCRaidersUtility.ps1`, `ArcRaidersCommon.ps1`, `game-boost.ps1`, `start-arc-raiders.ps1`, `cleanup-arc-raiders.ps1`, `SkipVideosMod.ps1`, `user/.dotfiles/config/games/arc-raiders/`

**Bootstrap** — always change together: `install.conf.yaml`, `Scripts/Setup-Dotfiles.ps1`, `README.md` (setup sections)

## Validation Matrix

| Changed Area                              | Primary Check                                                                | Secondary                                                      |
| ----------------------------------------- | ---------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `Scripts/**/*.ps1`                        | `Invoke-ScriptAnalyzer -Path <file> -Settings PSScriptAnalyzerSettings.psd1` | Pester if test exists                                          |
| `install.conf.yaml`                       | Path resolution, hash logic integrity                                        | `README.md` consistency                                        |
| `Scripts/Setup-Dotfiles.ps1`              | ScriptAnalyzer + manifest review                                             | Config paths verification                                      |
| `user/.dotfiles/config/*`                 | Format preservation (no cosmetic re-serialization)                           | Manifest correctness                                           |
| `Scripts/auto/autounattend-windows10.xml` | `$xml = [xml]::new(); $xml.Load(path)`                                       | `ExtractScript` entity encoding                                |
| `.kilo/` config changes                   | JSON/YAML syntax; correct paths                                              | `npx -y @yawlabs/ctxlint --depth 5 --mcp --strict --fix --yes` |
| `.github/workflows/*`                     | YAML syntax, tool availability                                               | —                                                              |

## CI Pipelines

| Workflow               | Trigger                      | Checks                                        |
| ---------------------- | ---------------------------- | --------------------------------------------- |
| `lint-format-test.yml` | push/PR on `*.ps1`           | PSScriptAnalyzer + format + Pester            |
| `powershell.yml`       | push/PR on `*.ps1`           | SARIF-based PSScriptAnalyzer (Security tab)   |
| `ps-format.yml`        | push/PR on `*.ps1/psm1/psd1` | Formatting (indent, BOM, trailing whitespace) |
| `reg-validate.yml`     | push/PR on `*.reg`           | Registry file validation                      |
| `secret-scan.yml`      | all push/PR                  | Gitleaks secret detection                     |

**Pester:** 24 test files in `tests/` + `setup.Tests.ps1` at root. Run `Invoke-Pester -Path tests/ -Output Minimal`.

## Agent Delegation

| Agent                  | Specialization                                       | When to Delegate                                               |
| ---------------------- | ---------------------------------------------------- | -------------------------------------------------------------- |
| `powershell-agent`     | Script authoring, refactoring, CI compliance         | New/modified `.ps1`, function extraction, ScriptAnalyzer fixes |
| `windows-optimizer`    | Registry tweaks, debloating, gaming, NVIDIA GPU      | System modifications, service management, registry changes     |
| `config-deployer`      | Dotbot YAML, tracked config, deployment path mapping | `install.conf.yaml` edits, new tracked configs                 |
| `code-reviewer`        | Read-only review, best-practice verification         | Before merging PS changes, after refactoring                   |
| `security-auditor`     | Credential detection, unsafe pattern flagging        | Before committing scripts touching credentials or elevation    |
| `documentation-writer` | Markdown docs, README, AGENTS.md maintenance         | New commands/agents, README sync after features                |
| `explore-codebase`     | Read-only exploration, symbol location               | Finding where a function lives, mapping dependencies           |

Load relevant skills first: `win-patterns`, `validation`.

## Skills & Rules

**Skills** (`.claude/skills/`):
`win-patterns`, `validation`, `code-cleanup`, `karpathy-guidelines`, `windows-dotfiles`, `new-ps-script`, `powershell-windows`, `ps-script-validator`, `ps-dedupe-cleanup`, `session-complete`, `todo-scan`

**Rules** (`.kilo/rules/`):
`powershell.md`, `registry-security.md`, `windows-os.md`, `shell-strategy.md`, `morph-tools.md`
(`.claude/rules/`: `bootstrap-deployment.md`, `powershell.md`, `registry-security.md`, `windows-os.md`)

**Commands** (`.kilo/commands/`):
`Backup-CurrentConfigs`, `Invoke-ScriptAnalyzer`, `Optimize-Repository`, `Sync-Configs`, `Test-Environment`, `Validate-Changes`

## Git & Commits

Format: `<type>: <subject>` — types: `feat`, `fix`, `docs`, `refactor`, `style`, `chore`, `perf`

Examples: `feat: add GPU monitoring script`, `fix: harden bootstrap path handling (#52)`

**Never** commit: credentials, tokens, private keys, machine-specific overrides, exported hive `.reg` files, hardcoded `C:\Users\...` paths (use `$HOME`, `$env:USERPROFILE`).

## AI Guidance Changes

- Keep `.github/copilot-instructions.md` minimal (startup only); broader rules → `AGENTS.md`; narrow rules → `.kilo/rules/`
- After editing `.kilo/` guidance or `.github/copilot-instructions.md`: run `npx -y @yawlabs/ctxlint --depth 5 --mcp --strict --fix --yes`
