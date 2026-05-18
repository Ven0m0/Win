# AGENTS.md — AI Assistant Guide

`CLAUDE.md` is a symlink to this file. Edit `AGENTS.md`, never `CLAUDE.md`.

## Quick Start

| Task | Command |
|------|---------|
| Fresh Windows 11 install | `Scripts/Setup-Win11.ps1` or `iwr ...bootstrap.ps1 \| iex` |
| Deploy dotfiles | `mise run deploy` or `dotbot -c install.conf.yaml` |
| Deploy single config | `pwsh -File Scripts/Setup-Dotfiles.ps1 -Target 'PowerShell profile'` |
| Debloat Windows | `Scripts/debloat-windows.ps1` |
| Validate PS file | `Invoke-ScriptAnalyzer -Path <file> -Settings PSScriptAnalyzerSettings.psd1` |
| Run tests | `Invoke-Pester -Path tests/ -Output Minimal` |
| Run single test | `Invoke-Pester -Path tests/<File>.Tests.ps1 -Output Detailed` |
| Full bootstrap | `mise run bootstrap` |

## Repository Identity

**Ven0m0/Win** — Windows dotfiles and optimization suite. PowerShell automation, tracked application config, registry tweaks, and game-specific tuning assets.

**Stack:** PowerShell 5.1+/7+, CMD/Batch, AutoHotkey v2, registry files, Windows Terminal, winget, dotbot.

**Bootstrap layers:**
1. **Internet** (`bootstrap.ps1`) — one-command entry; self-elevates, installs prereqs, clones repo
2. **Repo** (`install.conf.yaml` → `Scripts/Setup-Dotfiles.ps1`) — winget packages, hash-based config deployment, PATH setup
3. **Unattended USB** (`Scripts/auto/autounattend.xml`) — fully self-contained; no companion flat files

Configs live in `user/.dotfiles/config/` and deploy by hash (no symlinks).

## Main Repo Areas

| Path | Purpose |
|------|---------|
| `Scripts/` | PowerShell automation surface |
| `Scripts/Common.ps1` | Shared helper library — always import, never duplicate |
| `Scripts/arc-raiders/` | Arc Raiders game-specific scripts |
| `Scripts/reg/` | Registry `.reg` files and priority tweaks |
| `Scripts/auto/autounattend.xml` | Unattended Windows 11 USB installer |
| `Scripts/auto/autounattend-windows10.xml` | Unattended Windows 10 USB installer |
| `tests/` | Pester test files (`*.Tests.ps1`) |
| `setup.Tests.ps1` | Root-level Pester tests |
| `user/.dotfiles/config/` | Tracked dotfile content (deploy targets) |
| `install.conf.yaml` | Dotbot configuration |
| `.kilo/` | Kilo AI configuration (skills, agents, rules, commands) |
| `.github/workflows/` | CI pipeline definitions |

## High-Signal Rules

- **Reuse `Scripts/Common.ps1`** for shared behavior — registry, restore points, UI, GPU discovery, logging
- **Tracked config** → always under `user/.dotfiles/config/`
- **Windows compatibility** → preserve PowerShell 5.1+/7+ support; use `$PSScriptRoot`, `$HOME`, `$env:*`
- **Reversible changes** → prefer `-Restore` / `-Undo` parameters for system modifications
- **New script names** → lowercase-with-dashes (e.g., `debloat-windows.ps1`); legacy PascalCase scripts remain as-is
- **Guidance splits**:
  - `.github/copilot-instructions.md` — short startup bootstrap only
  - `AGENTS.md` — canonical repo-wide guide
  - `.kilo/rules/` and `.claude/rules/` — narrow coding and system standards (symlinked)
  - `.kilo/skills/` and `.claude/skills/` — reusable workflow knowledge (symlinked)
  - `.kilo/agents/` — agent identity and handoff rules
  - `.kilo/commands/` — documented command workflows

## PowerShell Scripts

- Follow existing admin elevation patterns (`Request-AdminElevation` from `Common.ps1`)
- Prefer helpers in `Scripts/Common.ps1` over new one-off functions
- Use comment-based help; `[CmdletBinding(SupportsShouldProcess)]` for system modifications
- **Never** use global `$ErrorActionPreference = 'SilentlyContinue'` or `Invoke-Expression` with untrusted input
- CI enforces `PSAvoidGlobalAliases` and `PSAvoidUsingConvertToSecureStringWithPlainText`
- **Pipeline model** — `Return` only exits early; suppress output with `$null = <expr>`
- **String comparisons** — `.NET` string methods are case-sensitive; pass `'CurrentCultureIgnoreCase'` explicitly
- **External commands** — use `&` operator; never bare `curl` — always `curl.exe`
- **Downloads** — set `$ProgressPreference = 'SilentlyContinue'` before `Invoke-WebRequest`
- **Braces** — OTBS style, 2-space indent

## Common.ps1 — Use These Helpers

```powershell
# Admin / UI
Request-AdminElevation                          # elevation check (always first)
Initialize-ConsoleUI -Title "..."               # console setup
Show-Menu / Get-MenuChoice                      # interactive menus
Wait-ForKeyPress                                # pause for user

# Registry
Set-RegistryValue / Remove-RegistryValue        # safe registry ops
Get-RegistryValueSafe                           # read without throwing

# NVIDIA
Get-NvidiaGpuRegistryPath                       # discover all NVIDIA adapter registry paths (function name is singular)
Get-NvidiaGpuPath / Set-NvidiaGpuRegistryValue  # GPU-specific ops
Set-NvidiaSignatureOverride / Get-NvidiaSignatureStatus
Set-FullscreenMode / Set-MultiPlaneOverlay      # display tweaks

# System
New-RestorePoint                                # before any HKLM changes
Remove-AppxPackageSafe                          # safe appx removal
Invoke-ServiceOperation                         # start/stop/query services
Invoke-CommandChecked                           # run external command, throw on failure
Invoke-RegImport                                # import .reg files safely
Invoke-Winget                                   # winget wrapper
Wait-ForWinget                                  # wait for winget lock

# Files / Paths
Get-FileFromWeb -URL "..." -File "..."          # downloads (sets ProgressPreference)
Clear-DirectorySafe -Path "..."                 # safe directory clear
Clear-PathSafe -Path "..."                      # safe path removal
Ensure-Directory -Path "..."                    # mkdir -p equivalent

# Logging
Add-Log / Get-Log / Clear-Log                   # session logging

# Utilities
ConvertFrom-VDF / ConvertTo-VDF                 # Steam VDF parsing
Get-FolderSize / Format-Size                    # size reporting
Measure-Execution                               # timing
Show-Summary                                    # display results summary
```

## Registry & System Tweaks

- Always create a restore point before HKLM changes (unless `-NoRestorePoint`)
- Support both apply and restore: `-Action Enable` / `-Restore`
- **Never** hardcode GPU PCI IDs — use `Get-NvidiaGpuRegistryPath` for device discovery
- Avoid sensitive keys: `HKLM\SECURITY`, `HKLM\SAM`, `HKLM\SYSTEM\...\Lsa`

## Config Deployment

- Preserve native file formats — do not reformat (JSON, YAML, REG, etc.)
- Hash-based deployment (SHA256) — copies only when source differs
- Template files use `##template` suffix; dotbot handles substitution
- Machine-local PS overrides go in untracked `$HOME\.dotfiles\config\powershell\local.ps1`

**Tracked config areas** (`user/.dotfiles/config/`):

| Subdirectory | Contents |
|---|---|
| `powershell/` | PS profile |
| `nvidia/` | Performance tweaks, profiles, optional reg tweaks |
| `games/arc-raiders/` | Engine.ini, GameUserSettings.ini, keybindings |
| `games/bf2/` | BF2 config and options |
| `games/bo6/` | Black Ops 6 save data and settings |
| `windows-terminal/` | Terminal settings.json |
| `cmd/` | CMD aliases and helper batch files |
| `cursors/` | Custom cursor set |
| `firefox/` | user.js prefs |
| `brave/` | Debloat registry |
| `bleachbit/` | Custom cleaner XMLs and winapp2.ini |
| `DDU/` | Display Driver Uninstaller config |
| `mise/` | mise config.toml |
| `msi-afterburner/` | Afterburner skin |
| `nvidia-inspector/` | Inspector settings script |
| `scoop/` | Scoop config |
| `winget-configs/` | Winget settings |

## Arc Raiders Scripts

All five scripts change together:

```
Scripts/arc-raiders/ARCRaidersUtility.ps1    # main utility (menu-driven)
Scripts/arc-raiders/game-boost.ps1           # gaming optimization
Scripts/arc-raiders/start-arc-raiders.ps1    # launch wrapper
Scripts/arc-raiders/cleanup-arc-raiders.ps1  # cleanup helper
Scripts/arc-raiders/SkipVideosMod.ps1        # skip intro videos
user/.dotfiles/config/games/arc-raiders/     # Engine.ini, GameUserSettings.ini, keybindings
AGENTS.md                                    # update when adding new game support
```

## Bootstrap Changes

These three always change together:

```
install.conf.yaml
Scripts/Setup-Dotfiles.ps1
README.md  (setup sections)
```

## Validation Matrix

| Changed Area | Primary Check | Secondary |
|---|---|---|
| `Scripts/**/*.ps1` | `Invoke-ScriptAnalyzer -Path <file> -Settings PSScriptAnalyzerSettings.psd1` | Run Pester if test exists |
| `install.conf.yaml` | Path resolution, hash logic integrity | `README.md` consistency |
| `Scripts/Setup-Dotfiles.ps1` | ScriptAnalyzer + deployment manifest review | Config paths verification |
| `user/.dotfiles/config/*` | Format preservation (no cosmetic re-serialization) | Deployment manifest correctness |
| `Scripts/auto/autounattend.xml` | `$xml = [xml]::new(); $xml.Load(path)` | Check `ExtractScript` entity encoding |
| `.kilo/rules/*.md` | Validate syntax and path references | `ctxlint --fix-safe` |
| `.github/workflows/*` | YAML syntax, tool availability | — |
| `.kilo/` config changes | JSON/YAML syntax; correct paths | Run `ctxlint` if guidance touched |

## CI Pipelines

| Workflow | Trigger | What it checks |
|---|---|---|
| `lint-format-test.yml` | push/PR on `*.ps1` | PSScriptAnalyzer + format + Pester |
| `powershell.yml` | push/PR on `*.ps1` | SARIF-based PSScriptAnalyzer (Security tab) |
| `ps-format.yml` | push/PR on `*.ps1/psm1/psd1` | Formatting (indent, BOM, trailing whitespace) |
| `reg-validate.yml` | push/PR on `*.reg` | Registry file validation |
| `secret-scan.yml` | all push/PR | Gitleaks secret detection |
| `copilot-setup-steps.yml` | push/PR on workflow file, `workflow_dispatch` | Copilot environment setup |

**CI enforces:** `PSAvoidGlobalAliases`, `PSAvoidUsingConvertToSecureStringWithPlainText`

**Pester:** 19 test files in `tests/` + `setup.Tests.ps1` at root. Run `Invoke-Pester -Path tests/ -Output Minimal`.

## AI Guidance Changes

- Keep `.github/copilot-instructions.md` minimal (startup only)
- Broader rules → `AGENTS.md`
- Narrow rules → `.kilo/rules/`
- Reusable workflows → `.kilo/skills/`
- After editing `.kilo/` guidance or `.github/copilot-instructions.md`: run `npx -y @yawlabs/ctxlint --depth 5 --mcp --strict --fix --yes`

## Agent Delegation

| Agent | Specialization | When to Delegate |
|---|---|---|
| `powershell-expert` | Script authoring, refactoring, CI compliance | New/modified `.ps1`, function extraction, ScriptAnalyzer fixes |
| `windows-system-agent` | Registry tweaks, debloating, gaming, NVIDIA GPU | System modifications, service management, registry changes |
| `config-deployer-agent` | Dotbot YAML, tracked config, deployment path mapping | `install.conf.yaml` edits, new tracked configs |
| `code-reviewer` | Read-only review, best-practice verification | Before merging PS changes, after refactoring |
| `security-auditor` | Credential detection, unsafe pattern flagging | Before committing scripts touching credentials or elevation |
| `documentation-writer` | Markdown docs, README, AGENTS.md maintenance | New commands/agents, README sync after features |
| `explore-codebase` | Read-only exploration, symbol location | Finding where a function lives, mapping dependencies |

Always load relevant skills first: `win-patterns`, `bootstrap-deployment`, `validation`, `agent-delegation`.

## MCP Servers

Configured in `.kilo/kilo.json` under the `mcp` key.

| Server | Type | Purpose |
|---|---|---|
| `ref-tools` | remote | Reference and citation tools |
| `github` | remote | GitHub API integration |
| `exa` | remote | Live web search and content crawling |
| `octocode` | local | Code search, LSP navigation, filesystem traversal |
| `context7` | remote | Library documentation lookup (disabled by default) |

Every enabled MCP server adds tokens to context. Prefer built-in tools for simple ops; disable unused servers on context warnings.

## Skills (`.kilo/skills/`)

| Skill | Description |
|---|---|
| `win-patterns` | Repo conventions, Common.ps1 helpers, path rules |
| `bootstrap-deployment` | Three-layer bootstrap, dotbot patterns, deployment order |
| `validation` | Per-change-type validation matrix |
| `agent-delegation` | Orchestrate tasks across agents |
| `mcp-server-management` | Configure and troubleshoot MCP servers |
| `opencode-migration` | Migrate configs from Claude Code, Cursor, and other tools |
| `repo-cleanup` | Dead code, doc pruning, legacy removal |
| `script-merge-guide` | Merge and consolidate PowerShell scripts safely |
| `test-relocation` | Move and reorganize Pester test files |
| `dead-code-cleanup` | Identify and remove unused code |
| `windows-dotfiles` | Windows dotfiles conventions and deployment patterns |

## Commands (`.kilo/commands/`)

| Command | Description |
|---|---|
| `Audit-Security` | Security checks across the repository |
| `Backup-CurrentConfigs` | Backup configs before changes |
| `Debloat-Windows` | Windows debloating workflow |
| `Deploy-Configs` | Deploy a single config group |
| `Invoke-ScriptAnalyzer` | Lint PowerShell files |
| `Lint-Guidance` | Validate AGENTS.md and `.kilo/` guidance |
| `Migrate-Config` | Migrate legacy configs to current layout |
| `New-RestorePointSafe` | Create a system restore point |
| `Optimize-Gaming` | Gaming optimization workflow |
| `Optimize-Repository` | Analyze and improve repo maintainability |
| `Review-Code` | Structured code review for PowerShell changes |
| `Set-ExecutionPolicySafe` | Safely set PowerShell execution policy |
| `Setup-Win11` | Fresh Windows 11 setup workflow |
| `Sync-Configs` | Synchronize configs with deployment manifest |
| `Test-Environment` | Validate the local environment |
| `Update-WingetPackages` | Update winget-managed packages |
| `Validate-Changes` | Run validation checks for changed areas |

## Git & Commits

Commit format: `<type>: <subject>` — types: `feat`, `fix`, `docs`, `refactor`, `style`, `chore`, `perf`

Examples: `feat: add GPU monitoring script`, `fix: harden bootstrap path handling (#52)`

**Never** commit: credentials, tokens, private keys, machine-specific overrides, exported hive `.reg` files, hardcoded user paths (`C:\Users\...` — use `$HOME`, `$env:USERPROFILE`).

## Related

- `README.md` — user-facing setup and usage
- `.github/copilot-instructions.md` — short startup guide
- `.kilo/skills/win-patterns/SKILL.md` — recurring repo workflows
- `.kilo/rules/powershell.md` — PowerShell coding rules
- `.kilo/rules/bootstrap-deployment.md` — bootstrap and deployment rules
