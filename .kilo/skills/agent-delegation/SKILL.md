---
name: agent-delegation
description: "Orchestrate complex tasks across specialized agents with proper context handoff"
compatibility: opencode
---

# Agent Delegation Skill

Use this skill when a task is too large for a single agent or requires cross-domain expertise. Covers task decomposition, wave planning, context passing, permission boundaries, and recovery from subagent failures.

## When to Delegate

Delegate when any of the following are true:

- The task touches more than two distinct domains (e.g., PowerShell + registry + config deployment)
- Research and implementation can run in parallel
- A specialist agent exists for the subtask (e.g., `windows-system-agent`, `powershell-expert`)
- The task exceeds a reasonable token budget for a single context window

## Task Decomposition Patterns

### Functional Split

Break work by function rather than by file:

- **Research** → gather docs, APIs, registry keys
- **Implementation** → write/modify code
- **Validation** → lint, test, review
- **Documentation** → update AGENTS.md, README, inline help

### Layer Split

Break work by system layer:

- Bootstrap layer (`bootstrap.ps1`, `install.conf.yaml`)
- Script layer (`Scripts/**/*.ps1`)
- Config layer (`user/.dotfiles/config/`)
- Guidance layer (`.github/`, `.kilo/`, `AGENTS.md`)

### Dependency-First Split

Order subtasks by dependency:

1. Shared helpers (`Scripts/Common.ps1`)
2. Scripts that import those helpers
3. Configs that reference the scripts
4. Docs that describe the configs

## Parallel vs Sequential Wave Planning

### Parallel Waves

Use parallel delegation when subtasks are independent:

```
Wave 1 (parallel):
  - Agent A: Research registry keys for gaming tweak
  - Agent B: Research winget package IDs for new tools
  - Agent C: Draft README update

Wave 2 (sequential after Wave 1):
  - Agent D: Implement script using findings from A and B
  - Agent E: Validate README accuracy against C's draft
```

Rules for parallel waves:

- Each subagent receives a isolated prompt with exactly the context it needs
- Do not pass full parent conversation history; summarize relevant findings
- Collect results before starting the next wave

### Sequential Waves

Use sequential delegation when subtasks depend on prior output:

```
Wave 1: Research agent → returns registry paths and values
Wave 2: PowerShell expert → writes `Set-MyTweak.ps1` using Wave 1 output
Wave 3: Validation agent → runs ScriptAnalyzer and tests
```

Always validate the output of Wave N before starting Wave N+1.

## Context Passing Between Agents

### Summarize, Don't Forward

Never forward raw conversation logs. Extract the minimum viable context:

- **Decisions**: what approach was chosen and why
- **Findings**: specific values, paths, IDs, or code snippets
- **Files touched**: relative paths and line ranges
- **Blockers**: anything the next agent must know to avoid rework

### Structured Handoff Format

```markdown
## Handoff from <Agent-Name>

### Decisions
- Using `Set-RegistryValue` helper from Common.ps1
- Target: `HKCU:\Software\MyTweak`, value `Enable` = 1

### Findings
- GPU registry paths: `HKLM:\SYSTEM\...\0000` and `0001`
- Requires admin elevation

### Files Touched
- `Scripts/MyTweak.ps1` (new, lines 1-45)
- `Scripts/Common.ps1` (no changes)

### Next Steps
- Add `SupportsShouldProcess` to new script
- Run ScriptAnalyzer
```

### Session Persistence

When a subagent may need to resume later (multi-wave tasks), use persistent sessions:

- Pass the same `task_id` when continuing
- The subagent retains its previous context and file system state
- Budget `task_budget` in `opencode.json` to prevent infinite delegation loops

## Permission-Aware Delegation Matrix

Match the agent's permissions to the work:

| Agent Type | Tools | File Access | Safe For |
|---|---|---|---|
| Researcher | read-only (webfetch, MCP) | read-only | Docs lookup, API research |
| Coder | write, bash | full | Implementation, refactoring |
| Reviewer | read-only, git | read-only | PR review, lint, audit |
| Scribe | write (docs only) | limited | README, comments, guides |
| System | write, bash, registry | full | OS tweaks, service changes |

### Permission Block Example

```json
{
  "agent": {
    "reviewer": {
      "permissions": {
        "read": true,
        "write": false,
        "bash": false,
        "tools": {
          "github*": true,
          "webfetch": true
        }
      }
    }
  }
}
```

Never give an agent broader permissions than its task requires.

## Recovery When Subagents Fail

### Failure Modes

| Mode | Signal | Response |
|---|---|---|
| Timeout | No response within limit | Retry once with narrower scope; if still failing, split task smaller |
| Error | Subagent reports error | Capture error message, fix root cause, re-delegate only the failing slice |
| Wrong output | Result does not match spec | Send correction prompt with explicit delta; do not restart from scratch |
| Loop | Subagent delegates back infinitely | Check `task_budget` and `level_limit` in config; cap depth |

### Retry Strategy

1. **First failure**: retry the same subagent with the same prompt (transient issue)
2. **Second failure**: reduce scope by 50% and retry
3. **Third failure**: escalate to parent agent or user with a summary of blockers

### Fallback to Parent

If a specialist agent fails and no narrower scope is possible, the parent agent should:

1. Absorb the subagent's partial output
2. Attempt the task itself with the context already gathered
3. Document the gap in AGENTS.md or comments for future skill improvement

## Anti-Patterns

- **Ping-pong**: subagent A calls subagent B which calls subagent A. Use `task_budget` and `level_limit` to prevent.
- **Context sprawl**: passing entire parent conversation to every subagent. Summarize instead.
- **Premature delegation**: delegating a 5-line fix. Direct edit is faster.
- **Over-parallelization**: running 6 agents for a single-file change. Sequential is simpler.

## Related

- `mcp-server-management` — scoping MCP tools per agent
- `windows-dotfiles` — repo-specific agent types for this project
