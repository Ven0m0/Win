# AGENTS.md — AI Assistant Guide

> `CLAUDE.md` must remain a symlink to this file. Update `AGENTS.md`, not `CLAUDE.md`.

---

## Quick Start

| Task | Command or Reference |
|------|---------------------|
| Fresh Windows 11 install | `.\Scripts\Setup-Win11.ps1` or one-command: `iwr ...bootstrap.ps1 \| iex` |
| Deploy dotfiles | `mise run deploy` or `dotbot -c install.conf.yaml` |
| Deploy single config | `pwsh -File Scripts\Setup-Dotfiles.ps1 -Target 'PowerShell profile'` |
| Debloat Windows | `.\Scripts\Debloat-Windows.ps1` or Kilo: `.\Debloat-Windows.md` |
| Gaming optimization | `.\Scripts\Optimize-Gaming.ps1` or Kilo: `.\Optimize-Gaming.md` |
| Validate changes | `.\Scripts\Validate-Changes.ps1` or `.\Invoke-ScriptAnalyzer.ps1` |
| Create restore point | `.\Scripts\New-RestorePointSafe.ps1` |

See `.kilo/commands/` for documented workflows (Kilo agents use these references).

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
| `user/.dotfiles/config/` | Tracked dotfile content (deployed by hash, no symlinks) |
| `install.conf.yaml` | Dotbot configuration → delegates to `Scripts/Setup-Dotfiles.ps1` |
| `.github/scripts/bootstrap.ps1` | Internet bootstrap entry point |
| `.kilo/` | Kilo AI configuration (skills, agents, rules, command reference) |

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
- `.kilo/skills/bootstrap-deployment.md`

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
| `powershell-expert` | PowerShell script authoring, refactoring, commenting, CI compliance | New or modified `.ps1` files, function extraction, script review |
| `windows-system-agent` | Registry tweaks, debloating, gaming optimizations, network tuning, NVIDIA GPU handling | System modifications, service and task management, registry changes |
| `config-deployer-agent` | Dotbot YAML, tracked config management, deployment path mapping, templates | `install.conf.yaml` edits, new tracked configs, deployment logic |

Always load relevant skills first: `windows-dotfiles`, `bootstrap-deployment`, `validation`.

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

**Agents** (`.kilo/agents/`):
- `powershell-expert.agent.md` — PowerShell script specialist
- `windows-system-agent.agent.md` — Windows optimization & registry specialist
- `config-deployer-agent.agent.md` — dotfile deployment & dotbot specialist

**Rules** (`.kilo/rules/`):
- `powershell.md` — PowerShell 5.1+/7+, required and prohibited patterns, elevation, CI
- `windows-os.md` — Win10/Win11 detection, feature guarding, telemetry differences
- `registry-security.md` — safe registry ops, restore points, GPU discovery

**Commands** (`.kilo/commands/` — markdown reference only):
- `Setup-Win11.md`, `Deploy-Configs.md`, `Validate-Changes.md`, `Invoke-ScriptAnalyzer.md`
- `Update-WingetPackages.md`, `New-RestorePointSafe.md`, `Optimize-Gaming.md`
- `Debloat-Windows.md`, `Sync-Configs.md`, `Backup-CurrentConfigs.md`, `Test-Environment.md`

---

## Related

- `README.md` — user-facing setup and usage
- `.github/copilot-instructions.md` — short startup guide
- `.github/skills/win-patterns/SKILL.md` — recurring repo workflows
- `.github/instructions/powershell.instructions.md` — PowerShell-specific rules
- `.github/instructions/windows-11-setup.instructions.md` — Win11 setup rules
