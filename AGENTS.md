# AGENTS.md — AI Assistant Guide

`CLAUDE.md` is a symlink to this file. Update AGENTS.md, not CLAUDE.md.

## Quick Start

| Task | Command |
|------|---------|
| Fresh Windows 11 install | `Scripts\Setup-Win11.ps1` or `iwr ...bootstrap.ps1 \| iex` |
| Deploy dotfiles | `mise run deploy` or `dotbot -c install.conf.yaml` |
| Deploy single config | `pwsh -File Scripts\Setup-Dotfiles.ps1 -Target 'PowerShell profile'` |
| Debloat Windows | `Scripts\Debloat-Windows.ps1` or Kilo: `/Debloat-Windows` |
| Gaming optimization | `Scripts\Optimize-Gaming.ps1` or Kilo: `/Optimize-Gaming` |
| Validate changes | `Scripts\Validate-Changes.ps1` or Kilo: `/Validate-Changes` |
| Lint PowerShell | Kilo: `/Invoke-ScriptAnalyzer <path>` |
| Security audit | Kilo: `/Audit-Security` |
| Code review | Kilo: `/Review-Code <path>` |

## Repository Identity

**Ven0m0/Win** — Windows dotfiles and optimization suite. PowerShell automation, tracked application config, registry tweaks, and game-specific tuning assets.

**Stack:** PowerShell 5.1+/7+, CMD/Batch, AutoHotkey v2, registry files, Windows Terminal, winget, dotbot.

**Bootstrap layers:**
1. **Internet** (`.github/scripts/bootstrap.ps1`) — one-command entry; self-elevates, installs prereqs, clones repo
2. **Repo** (`install.conf.yaml` → `Scripts/Setup-Dotfiles.ps1`) — winget packages, hash-based config deployment, PATH setup
3. **Unattended USB** (`Scripts/auto/autounattend.xml`) — fully self-contained; no companion flat files

Configs live in `user/.dotfiles/config/` and deploy by hash (no symlinks).

## Main Repo Areas

| Path | Purpose |
|------|---------|
| `Scripts/` | PowerShell automation surface |
| `Scripts/Common.ps1` | Shared helper library (reuse first) |
| `Scripts/arc-raiders/` | Game-specific optimization scripts |
| `Scripts/auto/autounattend.xml` | Unattended Windows 11 USB installer |
| `tests/` | Pester test files (*.Tests.ps1) |
| `user/.dotfiles/config/` | Tracked dotfile content |
| `install.conf.yaml` | Dotbot configuration |
| `.kilo/` | Kilo AI configuration (skills, agents, rules, commands, kilo.json) |

## High-Signal Rules

- **Reuse `Scripts/Common.ps1`** for shared PowerShell behavior (registry, restore points, UI, GPU discovery)
- **Tracked config** → always under `user/.dotfiles/config/`
- **Windows compatibility** → preserve PowerShell 5.1+/7+ support; use `$PSScriptRoot`, `$HOME`, `$env:*`
- **Reversible changes** → prefer `-Restore` / `-Undo` parameters for system modifications
- **Guidance splits**:
  - `.github/copilot-instructions.md` — short startup bootstrap only
  - `AGENTS.md` — canonical repo-wide guide
  - `.kilo/rules/` — coding and system standards
  - `.github/skills/` — reusable repo workflows
  - `.kilo/skills/` — agent-facing workflow knowledge
  - `.kilo/agents/` — agent identity and handoff rules
  - `.kilo/commands/` — documented command workflows

## PowerShell Scripts

- Follow existing admin elevation patterns (`Request-AdminElevation` from `Common.ps1`)
- Prefer helpers in `Scripts/Common.ps1` over new one-off functions
- Use comment-based help; `[CmdletBinding(SupportsShouldProcess)]` for system modifications
- **Never** use global `$ErrorActionPreference = 'SilentlyContinue'` or `Invoke-Expression` with untrusted input
- CI enforces `PSAvoidGlobalAliases` and `PSAvoidUsingConvertToSecureStringWithPlainText`
- **Pipeline model** — `Return` only exits early; suppress with `$null = <expr>`
- **String comparisons** — `.NET` string methods are case-sensitive; pass `'CurrentCultureIgnoreCase'` for case-insensitive
- **External commands** — use `&` operator; never bare `curl` — always `curl.exe`
- **Downloads** — set `$ProgressPreference = 'SilentlyContinue'` before `Invoke-WebRequest`

## Registry & System Tweaks

- Use `Set-RegistryValue`, `Remove-RegistryValue`, `Get-NvidiaGpuRegistryPaths`, `New-RestorePoint` from `Common.ps1`
- Always create a restore point before HKLM changes (unless `-NoRestorePoint`)
- Support both apply (`-Action Enable`) and restore (`-Restore`) behavior
- **Never** hardcode GPU PCI IDs; use `Get-NvidiaGpuRegistryPaths` for device discovery
- Avoid sensitive registry keys: `HKLM\SECURITY`, `HKLM\SAM`, `HKLM\SYSTEM\...\Lsa`

## Config Deployment

- Preserve native file formats; do not reformat (JSON, YAML, REG, etc.)
- Hash-based deployment (SHA256) — copies only when source differs
- Template files use `##template` suffix; dotbot handles substitution
- Machine-local overrides go in untracked local profile (`$HOME\.config\powershell\local.ps1`)

## Bootstrap Changes

Review together:
- `install.conf.yaml`
- `Scripts/Setup-Dotfiles.ps1`
- `README.md` (setup sections)

## AI Guidance Changes

- Keep `.github/copilot-instructions.md` minimal
- Broader rules → `AGENTS.md`
- Narrow rules → `.kilo/rules/`
- Reusable workflows → `.github/skills/` and `.kilo/skills/`
- After editing `.github/` guidance: run `ctxlint --depth 3 --mcp --strict --fix --yes`

## Validation

| Changed Area | Primary Check | Secondary |
|-------------|---------------|-----------|
| `Scripts/**/*.ps1` | `Invoke-ScriptAnalyzer -Path <file> -Settings PSScriptAnalyzerSettings.psd1` | — |
| `install.conf.yaml` | Path resolution, hash logic integrity | `README.md` consistency |
| `Scripts/Setup-Dotfiles.ps1` | ScriptAnalyzer + deployment manifest review | Config paths verification |
| `user/.dotfiles/config/*` | Format preservation (no cosmetic re-serialization) | Deployment manifest correctness |
| `Scripts/auto/autounattend.xml` | `$xml = [xml]::new(); $xml.Load(path)`; check `ExtractScript` entity encoding | Embedded script paths valid |
| `.kilo/rules/*.md` | Validate syntax and path references | `ctxlint --fix-safe` |
| `.github/workflows/*` | YAML syntax, tool availability check | — |
| `.kilo/` config changes | Validate JSON or YAML syntax; ensure paths correct | Run `ctxlint` on guidance if touched |

**Current CI:** `.github/workflows/powershell.yml` runs `PSScriptAnalyzer`. Enforced: `PSAvoidGlobalAliases`, `PSAvoidUsingConvertToSecureStringWithPlainText`.

**Pester:** Run only when tests already exist for the area or when adding new testable logic.

## Agent Delegation

Delegate by scope:

| Agent | Specialization | When to Delegate |
|-------|----------------|------------------|
| `powershell-expert` | PowerShell script authoring, refactoring, CI compliance | New or modified `.ps1` files, function extraction, PSScriptAnalyzer remediation |
| `windows-system-agent` | Registry tweaks, debloating, gaming optimizations, NVIDIA GPU handling | System modifications, service management, registry changes |
| `config-deployer-agent` | Dotbot YAML, tracked config management, deployment path mapping | `install.conf.yaml` edits, new tracked configs, hash-based manifest updates |
| `code-reviewer` | Read-only code review, best-practice verification, CI compliance | Before merging PowerShell changes, after refactoring |
| `security-auditor` | Security audits, credential detection, unsafe pattern flagging | Before committing scripts that touch credentials, registry, or elevation |
| `documentation-writer` | Markdown docs, README updates, AGENTS.md maintenance | New command or agent docs, README sync after feature changes |
| `explore-codebase` | Fast read-only codebase exploration, mapping, locating symbols | Finding where a function lives, mapping dependencies |

Always load relevant skills first: `windows-dotfiles`, `bootstrap-deployment`, `validation`, `agent-delegation`.

## MCP Servers

Configured in `.kilo/kilo.json` under the `mcp` key.

| Server | Type | Purpose |
|--------|------|---------|
| `ref-tools` | remote | Reference and citation tools |
| `github` | remote | GitHub API integration |
| `exa` | remote | Live web search and content crawling |
| `octocode` | local | Local code search, LSP navigation, filesystem traversal |
| `context7` | remote | Library documentation lookup (disabled by default) |

Every enabled MCP server adds tokens to context. Prefer built-in tools for simple operations; disable unused servers if context warnings appear.

## Plugins

Installed in `.kilo/kilo.json` under the `plugin` key:

| Plugin | Purpose |
|--------|---------|
| `opencode-ignore` | Respect `.gitignore` and ignore patterns |
| `opencode-agent-identity` | Agent identity and persona management |
| `opencode-background-agents` | Background agent execution |
| `subtask2` | Subtask decomposition and tracking |
| `openslimedit` | Slim edit operations |
| `opencode-agent-skills` | Dynamic skill loading for agents |
| `opencode-betterglob` | Enhanced glob matching |
| `opencode-bettergrep` | Enhanced grep/search |
| `opencode-betterread` | Enhanced file reading |
| `opencode-helicone-session` | Session tracking via Helicone |
| `opencode-sequential-thinking` | Sequential reasoning chains |

Local plugins (`.kilo/plugins/`):
- `context-shield` — output compaction, read limit enforcement, subagent routing
- `json-healer` — auto-repair malformed JSON in tool args/outputs
- `custom-tools` — `json_repair`, `hl_edit`, `hl_read`, `hl_grep`, `sg`, `sgr`
- `gitingest` — fetch external GitHub repos via gitingest.com API

## Tools

Custom tools in `.kilo/tools/` provide domain-specific functionality:

| Tool | Purpose |
|------|---------|
| `json_repair` | Repair malformed/incomplete JSON. Modes: `repair`, `extract`, `extract_all`, `strip` |
| `hl_edit` | Hash-anchored file editor (Quick mode and Hash mode for concurrent-safe editing) |
| `hl_read` | Read file with `LINE#HASH|content` annotations. Supports pagination |
| `hl_grep` | Search files with hash-annotated results (directly usable as `hl_edit` anchors) |
| `sg` / `sgr` | AST structural code search/replace via ast-grep |

## Skills (`.kilo/skills/`)

Load with the `skill` tool. Reusable workflow knowledge for agents.

| Skill | Description |
|-------|-------------|
| `windows-dotfiles` | Repo conventions, Common.ps1 helpers, path rules |
| `bootstrap-deployment` | Three-layer bootstrap, dotbot patterns, deployment order |
| `validation` | Per-change-type validation matrix with decision table |
| `agent-delegation` | Orchestrate tasks across agents with proper context handoff |
| `mcp-server-management` | Configure, troubleshoot, and optimize MCP servers |
| `opencode-migration` | Migrate configs from Claude Code, Cursor, and other tools |
| `repo-cleanup` | Systematic repo cleanup: dead code, doc pruning, legacy removal |
| `script-merge-guide` | Merge and consolidate PowerShell scripts safely |
| `test-relocation` | Move and reorganize Pester test files |
| `dead-code-cleanup` | Identify and remove unused code |

## Commands (`.kilo/commands/`)

Invoke with `/Command-Name`:

| Command | Description |
|---------|-------------|
| `Audit-Security` | Run security checks across the repository |
| `Backup-CurrentConfigs` | Backup current configs before changes |
| `Debloat-Windows` | Windows debloating workflow |
| `Deploy-Configs` | Deploy a single config group |
| `Invoke-ScriptAnalyzer` | Lint PowerShell files |
| `Lint-Guidance` | Validate AGENTS.md and `.kilo/` guidance files |
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

- Use `git` for repo changes; `dotbot` for dotfile deployment
- Commit messages: `<type>: <subject>` with types: `feat`, `fix`, `docs`, `refactor`, `style`, `chore`, `perf`
- **Never** commit credentials, tokens, private keys, machine-specific overrides
- Avoid hardcoded local paths; never silently swallow system-command failures

## Sensitive Content

- Credentials, tokens, private keys
- Machine-specific local overrides (keep in untracked files)
- Exported hive files (full `.reg` of HKCU/HKLM)
- Hardcoded user paths (`C:\Users\...`) — use `$HOME`, `$env:USERPROFILE`

## Commands Reference

```powershell
# Lint a PowerShell file
Invoke-ScriptAnalyzer -Path Scripts\<changed>.ps1 -Settings PSScriptAnalyzerSettings.psd1

# Validate autounattend.xml
$xml = [xml]::new(); $xml.Load("$PWD\Scripts\auto\autounattend.xml")

# Deploy all dotfiles
mise run deploy

# Deploy single config
pwsh -File Scripts/Setup-Dotfiles.ps1 -Target 'PowerShell profile' -SkipWingetTools -SkipWSL

# Full bootstrap
mise run bootstrap

# One-command fresh Windows 11 install
iwr https://raw.githubusercontent.com/Ven0m0/Win/main/.github/scripts/bootstrap.ps1 -UseBasicParsing | iex
```

## Related

- `README.md` — user-facing setup and usage
- `.github/copilot-instructions.md` — short startup guide
- `.github/skills/win-patterns/SKILL.md` — recurring repo workflows
- `.kilo/rules/powershell.md` — PowerShell coding rules
- `.kilo/rules/bootstrap-deployment.md` — bootstrap and deployment rules