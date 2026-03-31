# Claude Code Automation Setup

**Date Completed:** 2026-03-30
**Repository:** Ven0m0/Win (Windows dotfiles & optimization suite)
**Optimization Goal:** Agentic AI agent workflows

This document summarizes all Claude Code automations configured for this repository.

---

## Quick Start

All automations are **already configured**. No user action required—they activate automatically on:

- **Script edits** → PSScriptAnalyzer auto-lint + ps-reviewer validation
- **New scripts** → `/new-ps-script` skill generates templates
- **Test coverage** → `/expand-pester-coverage` generates Pester tests

Invoke skills:
```powershell
/new-ps-script --name my-script
/expand-pester-coverage
/ps-script-validator
```

---

## What Was Set Up

### 1. Configuration (`.claude/settings.json`)

**Auto-Linting Hook:**
- Triggers on every `.ps1` edit
- Runs `Invoke-ScriptAnalyzer` automatically
- **Blocks edits if lint errors found**

**Permissions:**
- Allows: `Edit`, `Write`, `Bash(git *)`, `Bash(git log)`
- Blocks: `.gitconfig`, `.ssh/*`, `powershell/local.ps1`, `.yadm/*`

**Agent Configuration:**
- `ps-reviewer` agent: `model: opus`, tools: `[Read, Grep, Bash]`
- Auto-invokes after script edits for quality review

---

### 2. Skills

#### **ps-script-validator** (Claude-only)
**Purpose:** Validate PowerShell scripts against AGENTS.md conventions

**Checks:**
- ✓ Header requirements (#Requires, Common.ps1 import, admin elevation)
- ✓ Error handling (Set-StrictMode, $ErrorActionPreference)
- ✓ Code reuse (Common.ps1 functions, no duplication)
- ✓ Registry patterns (NVIDIA discovery, HKLM vs HKCU)
- ✓ Paths (no hardcoded C:\Users\, use variables)
- ✓ Documentation (comment-based help)
- ✓ Style (OTBS, 2-space indent)
- ✓ Testing (Pester tests for complex functions)

**Location:** `.claude/skills/ps-script-validator/SKILL.md`

---

#### **new-ps-script** (User-invocable)
**Purpose:** Generate new PowerShell script templates with boilerplate

**Features:**
- Includes required headers (#Requires, Common.ps1 import)
- Admin elevation setup (Request-AdminElevation, Initialize-ConsoleUI)
- Interactive menu structure
- Registry operation examples
- Error handling templates
- Comment-based help blocks

**Usage:**
```powershell
/new-ps-script --name my-feature-script --description "Brief description"
```

**Location:** `.claude/skills/new-ps-script/SKILL.md`

---

#### **expand-pester-coverage** (User-invocable)
**Purpose:** Generate Pester tests for PowerShell functions

**Features:**
- Arrange-Act-Assert pattern templates
- Safe registry mocking (no HKLM mutations)
- NVIDIA GPU path mocking
- File operations mocking
- Menu input mocking
- Coverage analysis (shows which scripts need tests)

**Current Status:**
- 2 test files exist
- 13 scripts need test coverage
- High-priority: Common.ps1, gpu-display-manager.ps1

**Usage:**
```powershell
/expand-pester-coverage
```

**Running locally:**
```powershell
Invoke-Pester -Path Scripts/
```

**Location:** `.claude/skills/expand-pester-coverage/SKILL.md`

---

### 3. Subagents

#### **ps-reviewer**
**Purpose:** Specialized code review for PowerShell scripts

**Responsibilities:**
- Code quality: OTBS braces, Verb-Noun naming, error handling
- Registry safety: GPU paths, HKLM vs HKCU, hardcoded paths
- Common.ps1 reuse: Detects code duplication
- NVIDIA patterns: GPU registry discovery, EDID overrides
- Admin elevation: #Requires, Request-AdminElevation checks

**Model:** Opus (stronger analysis for complex PowerShell patterns)

**Tools:** Read, Grep, Bash

**Invocation:**
- Auto: Triggered after script edits (via hook)
- Manual: User requests explicit review

**Output:** Pass/Fail with specific line numbers and suggestions

**Location:** `.claude/agents/ps-reviewer.md`

---

## Automated Workflows

### Workflow 1: Script Creation & Validation
```
User invokes /new-ps-script
         ↓
Skill generates template with boilerplate
         ↓
User customizes template
         ↓
User saves file
         ↓
Hook: PSScriptAnalyzer auto-lint (blocks if errors)
         ↓
Hook: ps-reviewer agent reviews quality
         ↓
Review complete → User can commit
```

### Workflow 2: Existing Script Modification
```
User edits Scripts/my-script.ps1
         ↓
Hook: PSScriptAnalyzer runs (blocks if lint errors)
         ↓
Hook: ps-reviewer agent auto-reviews
         ↓
If blockers found → User must fix
         ↓
If only warnings → Commit with suggestions noted
```

### Workflow 3: Test Coverage Expansion
```
User identifies untested function
         ↓
User invokes /expand-pester-coverage
         ↓
Skill generates test file with templates
         ↓
User customizes tests (arrange-act-assert)
         ↓
User runs: Invoke-Pester -Path Scripts/
         ↓
Hook: Auto-test runs on related script edits
         ↓
Coverage increases
```

---

## For Agentic AI Workflows

### Parallel Agent Orchestration

**Scenario:** Team of agents expanding test coverage

```
Agent-A: Identifies untested functions → finds 5 candidates
Agent-B: Runs /expand-pester-coverage in parallel → generates 5 test files
Agent-C: Customizes tests for each file (independent paths)
Agent-D: Runs Invoke-Pester on all 5 simultaneously (via hooks)
Agent-E: Commits test files with coverage metrics
```

### Validation Checkpoints

After any script creation/modification, agents encounter:

1. **Lint Gate:** PSScriptAnalyzer (blocks if errors)
   - Prevents malformed PowerShell
   - Enforces style consistency

2. **Quality Gate:** ps-reviewer agent review
   - Validates registry safety
   - Checks Common.ps1 reuse
   - Confirms admin elevation
   - May block or warn (agent decides)

3. **Test Gate:** Invoke-Pester (hook auto-runs related tests)
   - Ensures functions work as intended
   - Catches regressions

### Safety Rails

**Sensitive Files Blocked:**
- `.gitconfig` — prevents credential commits
- `.ssh/*` — prevents key commits
- `powershell/local.ps1` — prevents machine-specific config leaks
- `.yadm/*` — prevents dotfile system pollution

**Registry Operations Protected:**
- Mock environments in tests (no real HKLM mutations)
- `Get-NvidiaGpuRegistryPaths` required (no hardcoded paths)
- HKLM vs HKCU validation (correct scope)

---

## Configuration Files

### `.claude/settings.json`
Contains:
- PSScriptAnalyzer hook trigger
- Permission allow/block lists
- Agent configuration (ps-reviewer)

### `.claude/skills/`
Contains:
- `ps-script-validator/SKILL.md` — Validation checklist
- `new-ps-script/SKILL.md` — Template generator
- `expand-pester-coverage/SKILL.md` — Test generator

### `.claude/agents/`
Contains:
- `ps-reviewer.md` — Subagent configuration & responsibilities

---

## Next Steps

### For Users:
1. **Create new scripts:** `/new-ps-script --name script-name`
2. **Expand tests:** `/expand-pester-coverage`
3. **Verify compliance:** Observe auto-lint & review hooks

### For Agents:
1. **Auto-validation:** Edits trigger PSScriptAnalyzer + ps-reviewer
2. **Safe mutations:** Sensitive files blocked (`.gitconfig`, `.ssh/`, etc.)
3. **Parallel workflows:** Multiple agents can work on different scripts
4. **Test integration:** Hooks auto-run Pester tests on edits

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Hook not triggering | Restart Claude Code session |
| PSScriptAnalyzer errors | Review lint output; fix per `.github/instructions/powershell.instructions.md` |
| ps-reviewer blocks commit | Address blocker (hardcoded paths, missing help, etc.) |
| Pester test fails | Debug via `Invoke-Pester -Path Scripts/X.Tests.ps1 -Verbose` |
| Sensitive file editing | Remove from blocked list in `.claude/settings.json` (only if needed) |

---

## Related Documentation

- **AGENTS.md** — Authoritative conventions & style guide
- **.github/instructions/powershell.instructions.md** — Detailed PowerShell standards
- **.github/workflows/powershell.yml** — CI/CD PSScriptAnalyzer setup
- **Scripts/Common.ps1** — Shared utilities (always use, don't duplicate)

---

**Setup completed:** All automations active and ready for agentic AI workflows.
