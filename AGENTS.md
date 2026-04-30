# AGENTS.md — AI Assistant Guide

> `CLAUDE.md` must remain a symlink to this file. Update `AGENTS.md`, not `CLAUDE.md`.

---

## Table of Contents

- [Quick Start](#quick-start)
- [OpenCode/Kilo Configuration](#opencodekilo-configuration)
- [Repository Identity](#repository-identity)
- [Commands](#commands)
- [High-Signal Rules](#high-signal-rules)
- [Main Repo Areas](#main-repo-areas)
- [Change Guidance](#change-guidance)
- [Validation](#validation)
- [Agent Delegation](#agent-delegation)
- [MCP Servers](#mcp-servers)
- [Plugins](#plugins)
- [Skills & Commands Reference](#skills--commands-reference)
- [Git & Commits](#git--commits)
- [Sensitive Content](#sensitive-content)
- [Kilo Reference](#kilo-reference)
- [Related](#related)

---

## Quick Start

| Task | Command or Reference |
|------|---------------------|
| Fresh Windows 11 install | `Scripts\Setup-Win11.ps1` or one-command: `iwr ...bootstrap.ps1 \| iex` |
| Deploy dotfiles | `mise run deploy` or `dotbot -c install.conf.yaml` |
| Deploy single config | `pwsh -File Scripts\Setup-Dotfiles.ps1 -Target 'PowerShell profile'` |
| Debloat Windows | `Scripts\Debloat-Windows.ps1` or Kilo: `/Debloat-Windows` |
| Gaming optimization | `Scripts\Optimize-Gaming.ps1` or Kilo: `/Optimize-Gaming` |
| Validate changes | `Scripts\Validate-Changes.ps1` or Kilo: `/Validate-Changes` |
| Create restore point | `Scripts\New-RestorePointSafe.ps1` or Kilo: `/New-RestorePointSafe` |
| Lint PowerShell | Kilo: `/Invoke-ScriptAnalyzer <path>` |
| Security audit | Kilo: `/Audit-Security` |
| Code review | Kilo: `/Review-Code <path>` |

---

## OpenCode/Kilo Configuration

Project config lives in `.kilo/kilo.json`. Schema: `https://app.kilo.ai/config.json`.

### Key Sections

| Section | Purpose |
|---------|---------|
| `instructions` | Glob paths to rule files loaded for every session |
| `skills` | Skill search paths (`.kilo/skills`, `.claude/skills`) |
| `permission` | Global tool permissions (`read`, `edit`, `bash`, etc.) |
| `provider` / `disabled_providers` | LLM provider API keys and enablement |
| `plugin` | Installed OpenCode plugins |
| `formatter` | Per-extension formatters (biome, ruff) |
| `watcher` | Filesystem ignore patterns |
| `mcp` | MCP server definitions (local and remote) |
| `lsp` | Language server definitions |
| `agent` | Primary and subagent configurations |
| `compaction` | Context compaction settings |
| `experimental` | Feature flags |

### Adding MCP Servers

**Remote** — HTTP endpoint, no local install:

```json
"mcp": {
  "my-remote": {
    "type": "remote",
    "url": "https://api.example.com/mcp",
    "enabled": true,
    "headers": { "Authorization": "Bearer {env:MY_API_KEY}" }
  }
}
```

**Local** — spawned as a subprocess:

```json
"mcp": {
  "my-local": {
    "type": "local",
    "command": ["npx", "-y", "@scope/mcp@latest"],
    "enabled": true
  }
}
```

Use remote for APIs and knowledge bases; use local for filesystem, browser, or language-specific tools. Always use `{env:VAR_NAME}` for secrets — never commit literal keys.

### Adding Plugins

Plugins use npm or GitHub prefixes:

| Prefix | Example |
|--------|---------|
| npm | `"opencode-ignore@1.1.0"` |
| GitHub | `"github:user/repo"` |
| GitHub tag | `"github:user/repo@tag"` |

Add to the `plugin` array in `kilo.json`. Restart the session to apply changes.

### Agent Configuration

Agents are defined under the `agent` key. Each entry supports:

| Field | Description |
|-------|-------------|
| `mode` | `primary` (orchestrator) or `subagent` (delegated task) |
| `model` | Provider/model slug — optional; omit to inherit from session (Recommended) |
| `temperature` | Sampling temperature (0.0–1.0); lower for deterministic tasks |
| `permission` | Per-tool overrides (`edit`, `bash`, `task`, etc.) |

Primary agents (`build`, `plan`) handle user-facing work. Subagents are delegated scoped tasks. See [Agent Delegation](#agent-delegation) for the full roster.

---

## Repository Identity

**Ven0m0/Win** — Windows dotfiles and optimization suite. Centered on PowerShell automation, tracked application config, registry tweaks, and game-specific tuning assets.

**Primary stack:** PowerShell 5.1+/7+, CMD/Batch, AutoHotkey v2, registry files, Windows Terminal, winget, dotbot.

**Bootstrap layers:**

1. **Internet bootstrap** (`.github/scripts/bootstrap.ps1`) — one-command entry; self-elevates, installs prereqs (winget, Git, pwsh, Python, dotbot), clones repo, then delegates.
2. **Repo bootstrap** (`install.conf.yaml` → `Scripts/Setup-Dotfiles.ps1`) — installs winget packages, deploys configs via SHA256 hash comparison (copies only when content differs), configures PATH, creates directories.
3. **Unattended USB install** (`Scripts/auto/autounattend.xml`) — fully self-contained XML; copy to USB root and Windows Setup auto-detects. Scripts are embedded via `ExtractScript` and extracted to `C:\Windows\Setup\Scripts\` at runtime; **no companion flat files** alongside the XML.

Configs live in `user/.dotfiles/config/` and deploy by hash (no symlinks), preserving Windows compatibility without admin rights.

---

## Commands

```powershell
# Lint a changed PowerShell file
Invoke-ScriptAnalyzer -Path Scripts\<changed>.ps1 -Settings PSScriptAnalyzerSettings.psd1

# Validate autounattend.xml
$xml = [xml]::new(); $xml.Load("$PWD\Scripts\auto\autounattend.xml")

# Deploy all dotfiles (dotbot must be installed)
mise run deploy          # or: dotbot -c install.conf.yaml

# Deploy a single config group (no dotbot needed)
pwsh -File Scripts/Setup-Dotfiles.ps1 -Target 'PowerShell profile' -SkipWingetTools -SkipWSL
# Available targets: 'PowerShell profile', 'Windows Terminal settings', 'BleachBit cleaners',
#   'Firefox user.js', 'Brave policies', 'CMD aliases',
#   'Star Wars Battlefront II (2017) configs', 'Call of Duty Black Ops 6 configs',
#   'Call of Duty Black Ops 7 configs', 'NVIDIA assets'

# Full bootstrap (installs dotbot then deploys all)
mise run bootstrap       # or: pip install dotbot && dotbot -c install.conf.yaml

# One-command fresh Windows 11 install
iwr https://raw.githubusercontent.com/Ven0m0/Win/main/.github/scripts/bootstrap.ps1 -UseBasicParsing | iex
```

---

## High-Signal Rules

- **Reuse `Scripts/Common.ps1`** for shared PowerShell behavior (registry, restore points, UI, GPU discovery).
- **Tracked config** → always under `user/.dotfiles/config/`.
- **Windows compatibility** → preserve PowerShell 5.1+/7+ support; use environment-based paths (`$PSScriptRoot`, `$HOME`, `$env:*`, `A_ScriptDir`).
- **Reversible changes** → prefer `-Restore` / `-Undo` parameters for system modifications.
- **Guidance splits**:
  - `.github/copilot-instructions.md` — short startup bootstrap only
  - `AGENTS.md` — canonical repo-wide guide (this file)
  - `.github/instructions/` — narrow language or topic rules
  - `.github/skills/` — reusable repo workflows
  - `.kilo/skills/` — agent-facing workflow knowledge
  - `.kilo/agents/` — agent identity and handoff rules
  - `.kilo/rules/` — enforce coding and system standards
  - `.kilo/commands/` — documented command workflows (markdown reference)

---

## Main Repo Areas

| Path | Purpose |
|------|---------|
| `Scripts/` | PowerShell automation surface (executable scripts) |
| `Scripts/Common.ps1` | Shared helper library (reuse first) |
| `Scripts/auto/autounattend.xml` | Unattended Windows 11 USB installer (fully self-contained; embedded `ExtractScript`) |
| `Scripts/arc-raiders/` | Game-specific optimization scripts (ARC Raiders, Steam boosters) |
| `tests/` | Pester test files (*.Tests.ps1) |
| `user/.dotfiles/config/` | Tracked dotfile content (deployed by hash, no symlinks) |
| `install.conf.yaml` | Dotbot configuration → delegates to `Scripts/Setup-Dotfiles.ps1` |
| `.github/scripts/bootstrap.ps1` | Internet bootstrap entry point |
| `.kilo/` | Kilo AI configuration (skills, agents, rules, commands, `kilo.json`) |

---

## Change Guidance

### PowerShell Scripts

- Follow existing admin elevation patterns (`Request-AdminElevation` from `Common.ps1`).
- Prefer helpers in `Scripts/Common.ps1` over new one-off functions.
- Use comment-based help; `[CmdletBinding(SupportsShouldProcess)]` for system modifications.
- **Never** use global `$ErrorActionPreference = 'SilentlyContinue'` or `Invoke-Expression` with untrusted input.
- CI enforces `PSAvoidGlobalAliases` and `PSAvoidUsingConvertToSecureStringWithPlainText`.
- **Pipeline model** — `Return` only exits early; all unassigned expression results enter the pipeline stream. Suppress with `$null = <expr>` (faster than `| Out-Null`).
- **String comparisons** — `.NET` string methods (`.StartsWith()`, `.Contains()`, etc.) are case-sensitive; pass `'CurrentCultureIgnoreCase'` when case-insensitive matching is needed.
- **External commands** — use `&` operator for full-path executables or paths with spaces; never use bare `curl` (PowerShell alias for `Invoke-WebRequest`) — always `curl.exe`.
- **Download performance** — set `$ProgressPreference = 'SilentlyContinue'` before `Invoke-WebRequest`; default progress rendering severely throttles throughput.

### Registry & System Tweaks

- Use `Set-RegistryValue`, `Remove-RegistryValue`, `Get-NvidiaGpuRegistryPaths`, `New-RestorePoint` from `Common.ps1`.
- Always create a restore point before HKLM changes (unless `-NoRestorePoint`).
- Support both apply (`-Action Enable`) and restore (`-Restore`) behavior.
- **Never** hardcode GPU PCI IDs; use `Get-NvidiaGpuRegistryPaths` for device discovery.
- Avoid sensitive registry keys: `HKLM\SECURITY`, `HKLM\SAM`, `HKLM\SYSTEM\...\Lsa` (security policies), `HKCU\...\Start_TrackProgs` (Start menu pinning; use cautiously).

### Config Deployment

- Preserve native file formats; do not reformat (JSON, YAML, REG, etc.).
- Hash-based deployment (SHA256) — copies only when source differs.
- Template files use `##template` suffix; dotbot handles substitution.
- Machine-local overrides go in untracked local profile (`$HOME\.config\powershell\local.ps1`).

### Bootstrap Changes

Review together:
- `install.conf.yaml`
- `Scripts/Setup-Dotfiles.ps1`
- `README.md` (setup sections)
- `.kilo/skills/bootstrap-deployment/SKILL.md`

### AI Guidance Changes

- Keep `.github/copilot-instructions.md` minimal (startup only).
- Broader repo rules → `AGENTS.md`.
- Narrow rules → `.github/instructions/`.
- Reusable workflows → `.github/skills/` **and** `.kilo/skills/`.
- Agent definitions → `.kilo/agents/`.
- Coding and system standards → `.kilo/rules/`.
- After editing any `.github/` guidance: run `ctxlint --depth 3 --mcp --strict --fix --yes`. Install with: [npm i -g @yawlabs/ctxlint](https://www.npmjs.com/package/@yawlabs/ctxlint).

---

## Validation

Apply the narrowest checks for what changed:

| Changed Area | Primary Check | Secondary |
|-------------|---------------|-----------|
| Any `Scripts/**/*.ps1` | `Invoke-ScriptAnalyzer -Path <file> -Settings PSScriptAnalyzerSettings.psd1` | — |
| `install.conf.yaml` | Path resolution, hash logic integrity | `README.md` consistency |
| `Scripts/Setup-Dotfiles.ps1` | ScriptAnalyzer + deployment manifest review | Config paths verification |
| `user/.dotfiles/config/*` | Format preservation (no cosmetic re-serialization) | Deployment manifest still points correctly |
| `Scripts/auto/autounattend.xml` | `$xml = [xml]::new(); $xml.Load(path)`; check `ExtractScript` entity encoding | Embedded script paths valid |
| `.github/instructions/*` | Verify all referenced paths and commands exist | `ctxlint --fix-safe` |
| `.github/skills/*` | Skill references valid? Load `validate` skill | — |
| `.github/workflows/*` | YAML syntax, tool availability check | — |
| `.kilo/` config changes | Validate JSON or YAML syntax; ensure paths correct | Run `ctxlint` on guidance if touched |

**Current CI:**
- `.github/workflows/powershell.yml` runs `PSScriptAnalyzer`.
- Enforced: `PSAvoidGlobalAliases`, `PSAvoidUsingConvertToSecureStringWithPlainText`.

**Pester:** run only when tests already exist for the area or when adding new testable logic.

---

## Agent Delegation

Kilo agents are specialized; delegate by scope:

| Agent | Specialization | When to Delegate |
|-------|----------------|------------------|
| `powershell-expert` | PowerShell script authoring, refactoring, commenting, CI compliance | New or modified `.ps1` files, function extraction, script review, PSScriptAnalyzer remediation |
| `windows-system-agent` | Registry tweaks, debloating, gaming optimizations, network tuning, NVIDIA GPU handling | System modifications, service and task management, registry changes, restore point operations |
| `config-deployer-agent` | Dotbot YAML, tracked config management, deployment path mapping, templates | `install.conf.yaml` edits, new tracked configs, deployment logic, hash-based manifest updates |
| `code-reviewer` | Read-only code review, best-practice verification, CI compliance | Before merging PowerShell changes, after refactoring, when adding new public functions |
| `security-auditor` | Security audits, credential detection, unsafe pattern flagging | Before committing scripts that touch credentials, registry, or elevation; periodic repo audits |
| `documentation-writer` | Markdown docs, README updates, AGENTS.md maintenance | New command or agent docs, README sync after feature changes, guidance rewrites |
| `explore-codebase` | Fast read-only codebase exploration, mapping, locating symbols | Finding where a function lives, mapping dependencies, locating test coverage |

Always load relevant skills first: `windows-dotfiles`, `bootstrap-deployment`, `validation`, `agent-delegation`.

---

## MCP Servers

Configured in `.kilo/kilo.json` under the `mcp` key.

### Enabled

| Server | Type | Purpose |
|--------|------|---------|
| `ref-tools` | remote | Reference and citation tools |
| `context7` | remote | Library documentation lookup (code examples, SDKs) |
| `github` | remote | GitHub API integration (PRs, issues, code search) |
| `exa` | remote | Live web search and content crawling |
| `octocode` | local | Local code search, LSP navigation, filesystem traversal |

### Disabled (Ready to Enable)

| Server | Type | Purpose |
|--------|------|---------|
| `gh_grep` | remote | GitHub code search via grep.app |
| `serena` | local | Advanced codebase analysis (requires `uvx`) |
| `playwright` | local | Browser automation (headless) |
| `sentry` | remote | Error tracking and monitoring |
| `browser-tools` | local | Browser instrumentation |
| `filesystem` | local | Dedicated filesystem MCP |
| `git-mcp` | local | Git operations MCP |
| `sqlite` | local | SQLite query interface |

### Context Budget

Every enabled MCP server adds tokens to the context window. Prefer built-in tools for simple file operations; enable MCP servers only when domain-specific filtering or live data is required. Disable unused servers if context limit warnings appear.

---

## Plugins

Installed plugins are listed in `.kilo/kilo.json` under the `plugin` key.

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
| `opencode-web-search` | Built-in web search fallback |

Plugins are resolved via npm or GitHub. Update versions in `kilo.json` and restart the session to apply changes.

### Local Plugins (`.kilo/plugins/`)

These custom plugins are registered as local paths in kilo.json:

| Plugin | Purpose | Key Tools |
|--------|---------|-----------|
| `context-shield` | Output compaction, read limit enforcement, subagent routing | `cshield_toggle` |
| `json-healer` | Auto-repair malformed JSON in tool args/outputs | (automatic) |
| `custom-tools` | Register custom tools from `.kilo/tools/` | `json_repair`, `hl_edit`, `hl_read`, `hl_grep`, `sg`, `sgr` |
| `gitingest` | Fetch external GitHub repos via gitingest.com API | `gitingest` |

### Hash-Anchored Editing Workflow

Custom tools (`hl_read`, `hl_grep`, `hl_edit`) provide a hash-anchored editing workflow that prevents stale edits:

1. **Read** → `hl_read` returns each line as `LINE#HASH|content`
2. **Search** → `hl_grep` returns matches with hash-annotated line references
3. **Edit** → `hl_edit` validates hash anchors before applying changes; overlapping ranges are rejected

**Example workflow:**
```
hl_read path/to/file.ts
hl_grep "function hello"
hl_edit { filePath: "path/to/file.ts", edits: [{ op: "replace", pos: "10#VK", lines: "function hello() {\n  return 42;\n}" }] }
```

---

## Tools

Custom tools in `.kilo/tools/` are registered via `custom-tools` plugin and provide domain-specific functionality:

| Tool | Purpose |
|------|---------|
| `json_repair` | Repair malformed/incomplete JSON. Modes: `repair` (structural fix), `extract` (first JSON block from prose), `extract_all` (all JSON blocks as array), `strip` (remove LLM wrappers then repair). Pass file path or raw string. |
| `hl_edit` | Hash-anchored file editor. Two modes: **Quick** (`start_line`/`end_line`/`new_code`) and **Hash** (`edits[]` with `LINE#ID` anchors for concurrent-safe editing). Handles BOM/CRLF automatically. |
| `hl_read` | Read file with `LINE#HASH|content` annotations. Supports pagination via `offset`/`limit`. On directories, returns tree listing with file sizes. Binary files rejected. |
| `hl_grep` | Search files with hash-annotated results. Uses ripgrep if available, falls back to fs-based search. Results are directly usable as `hl_edit` anchors. |
| `sg` / `sgr` | AST structural code search/replace via ast-grep. Meta-vars: `$VAR` (single node), `$$$` (multi-node). 25+ languages supported. Requires `@ast-grep/cli` in PATH. |

---

## Skills & Commands Reference

### Skills (`.kilo/skills/`)

Load with the `skill` tool. Reusable workflow knowledge for agents.

| Skill | Description |
|-------|-------------|
| `windows-dotfiles` | Repo conventions, `Common.ps1` helpers, path rules |
| `bootstrap-deployment` | Three-layer bootstrap, dotbot patterns, deployment order |
| `validation` | Per-change-type validation matrix with decision table |
| `agent-delegation` | Orchestrate tasks across agents with proper context handoff |
| `mcp-server-management` | Configure, troubleshoot, and optimize MCP servers |
| `opencode-migration` | Migrate configs from Claude Code, Cursor, and other tools |
| `repo-cleanup` | Systematic repo cleanup: dead code, doc pruning, legacy removal |
| `script-merge-guide` | Merge and consolidate PowerShell scripts safely |
| `test-relocation` | Move and reorganize Pester test files |
| `dead-code-cleanup` | Identify and remove unused code |

### Commands (`.kilo/commands/`)

Invoke with `/Command-Name`. Markdown prompt templates.

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

---

## Git & Commits

- Use `git` for repo changes; `dotbot` for dotfile deployment.
- Commit messages: `<type>: <subject>`
  - Types: `feat`, `fix`, `docs`, `refactor`, `style`, `chore`, `perf`
- **Never** commit credentials, tokens, private keys, machine-specific overrides.
- Avoid hardcoded local paths; never silently swallow system-command failures.

---

## Sensitive Content

- ❌ Credentials, tokens, private keys
- ❌ Machine-specific local overrides (keep in untracked files)
- ❌ Exported hive files (full `.reg` of HKCU/HKLM)
- ❌ Hardcoded user paths (`C:\Users\...`) — use `$HOME`, `$env:USERPROFILE`

---

## Kilo Reference

**Skills** (`.kilo/skills/`):
- `windows-dotfiles.md` — repo conventions, Common.ps1 helpers, path rules
- `bootstrap-deployment.md` — three-layer bootstrap, dotbot patterns, deployment order
- `validation.md` — per-change-type validation matrix with decision table
- `agent-delegation.md` — orchestrate tasks across agents with proper context handoff
- `mcp-server-management.md` — configure, troubleshoot, and optimize MCP servers
- `opencode-migration.md` — migrate configs from Claude Code, Cursor, and other tools
- `repo-cleanup.md` — systematic repo cleanup: dead code, doc pruning, legacy removal
- `script-merge-guide.md` — merge and consolidate PowerShell scripts safely
- `test-relocation.md` — move and reorganize Pester test files
- `dead-code-cleanup.md` — identify and remove unused code

**Agents** (`.kilo/agents/`):
- `powershell-agent.md` — PowerShell script specialist
- `windows-optimizer.md` — Windows optimization & registry specialist
- `config-deployer.md` — dotfile deployment & dotbot specialist
- `code-reviewer.md` — read-only code review and CI compliance
- `security-auditor.md` — security audits and credential detection
- `documentation-writer.md` — markdown docs, README, and AGENTS.md maintenance
- `explore-codebase.md` — fast read-only codebase exploration

**Rules** (`.kilo/rules/`):
- `powershell.md` — PowerShell 5.1+/7+, required and prohibited patterns, elevation, CI
- `windows-os.md` — Win10/Win11 detection, feature guarding, telemetry differences
- `registry-security.md` — safe registry ops, restore points, GPU discovery
- `shell-strategy.md` — non-interactive shell mandates and banned commands
- `agent-orchestration.md` — task decomposition, wave planning, context passing
- `skills-workflows.md` — skill naming, frontmatter, maintenance
- `commands-custom.md` — command file structure, placeholders, organization
- `mcp-integration.md` — MCP server selection, context budget, fallback chains

**Commands** (`.kilo/commands/` — markdown reference):
- `Setup-Win11.md`, `Deploy-Configs.md`, `Validate-Changes.md`, `Invoke-ScriptAnalyzer.md`
- `Update-WingetPackages.md`, `New-RestorePointSafe.md`, `Optimize-Gaming.md`
- `Debloat-Windows.md`, `Sync-Configs.md`, `Backup-CurrentConfigs.md`, `Test-Environment.md`
- `Set-ExecutionPolicySafe.md`
- `Audit-Security.md`, `Review-Code.md`, `Migrate-Config.md`, `Optimize-Repository.md`, `Lint-Guidance.md`

---

## Related

- `README.md` — user-facing setup and usage
- `.github/copilot-instructions.md` — short startup guide
- `.github/skills/win-patterns/SKILL.md` — recurring repo workflows
- `.github/instructions/powershell.instructions.md` — PowerShell-specific rules
- `.github/instructions/windows-11-setup.instructions.md` — Win11 setup rules
