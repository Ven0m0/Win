# Agent Orchestration Rules

These rules govern how agents delegate work, split tasks, and coordinate execution in the Ven0m0/Win repository. They apply to all multi-agent workflows involving the primary agent and subagents.

## Task Tool vs Direct Execution

Use the **`task` tool** when:

- The work crosses agent specialization boundaries (PowerShell scripting → system optimization → config deployment)
- The task is self-contained enough to hand off and await a result
- You need read-only exploration without polluting the current session context
- Parallel execution of independent subtasks is desired
- The target work benefits from a fresh context window

Execute **directly** when:

- The change is localized to a single file or small set of files within your specialization
- Context from prior turns is required to make the correct edit
- The operation is a quick, single-step read or write
- Invoking a subagent would add more overhead than value

## Parallel Wave Execution

Organize multi-step work into waves:

| Wave | Contents | Example |
|------|----------|---------|
| 1 | Independent discovery / research tasks | Explore `Scripts/` structure, find all registry tweaks, list test files |
| 2 | Dependent implementation tasks | Refactor discovered functions, update callers, add tests |
| 3 | Integration & validation | Run ScriptAnalyzer, verify deployment paths, lint guidance |

Rules:

- Place **independent** subtasks in the same wave so they execute in parallel
- Place **dependent** subtasks in later waves; pass file paths and prior results as constraints
- Never exceed 3–5 parallel tasks in a single wave to avoid context exhaustion
- Recombine results from parallel tasks before launching the next wave

## Agent Specialization Matching

Match work to the correct subagent based on scope:

| Agent | Specialization | Delegate When |
|-------|----------------|---------------|
| `powershell-expert` | PowerShell script authoring, refactoring, CI compliance | New or modified `.ps1` files, function extraction, script review |
| `windows-system-agent` | Registry tweaks, debloating, gaming optimizations, GPU handling | System modifications, service/task management, registry changes |
| `config-deployer-agent` | Dotbot YAML, tracked config management, deployment path mapping | `install.conf.yaml` edits, new tracked configs, deployment logic |
| `explore` (built-in) | Read-only codebase discovery | Mapping directories, finding patterns, answering "where is X?" |
| `general` (built-in) | Multi-step execution with full tool access | Parallel research tasks that need both read and write |

Always load the relevant skill first before delegating:

- PowerShell tasks → `windows-dotfiles` skill
- Bootstrap changes → `bootstrap-deployment` skill
- Validation → `validation` skill

## Permission-Aware Delegation

Respect the permission boundary of each agent:

- **Read-only agents** (`explore`) — use for research, mapping, and locating code. Never delegate file modifications to them.
- **Build agents** (`general`, `powershell-expert`, `windows-system-agent`) — use for code changes, but scope the task narrowly.
- **Primary agent** — retains coordination responsibility; avoid doing implementation work that should be delegated.

When defining custom agents, enforce least privilege:

```yaml
---
description: Read-only reviewer
mode: subagent
permission:
  edit: deny
  bash: ask
---
```

## Context Passing Between Agents

When delegating via `task`, pass the minimal necessary context:

1. **File paths** — absolute or repo-relative paths to the files being modified
2. **Constraints** — what must stay unchanged, style rules to follow, CI checks to pass
3. **Prior results** — summaries from previous waves (not raw tool output dumps)

Example task prompt:

```
Refactor the registry helper functions in Scripts/Common.ps1.

Constraints:
- Preserve Windows PowerShell 5.1 compatibility
- Use Set-RegistryValue helper; do not call Set-ItemProperty directly
- Must pass Invoke-ScriptAnalyzer with PSScriptAnalyzerSettings.psd1
- Do not change function signatures used by Scripts/debloat-windows.ps1

Prior results from exploration:
- 4 functions duplicated across 3 files
- Common.ps1 already has Set-RegistryValue and Remove-RegistryValue
```

## Handoff Conventions

- Subagents return a **single concise message** summarizing what was done, what changed, and what remains
- Do not return raw tool output lists unless specifically requested
- If a subagent cannot complete its task, it should state what was blocked and what assumptions it made
- Resume a prior subagent session by passing the same `task_id` when available

## Subagent-to-Subagent Delegation

By default, subagents should not delegate to other subagents. If needed:

- Set a `task_budget` > 0 in the agent configuration
- Grant explicit `permission.task` patterns for the target agent
- Limit depth to avoid infinite recursion; prefer returning to the primary agent for re-orchestration

## Anti-Patterns

- ❌ Launching a subagent for a one-line edit
- ❌ Dumping entire file contents into a task prompt instead of referencing paths
- ❌ Running dependent tasks in parallel without clear data dependencies
- ❌ Letting a subagent silently swallow failures — always request explicit status
