# Agent Orchestration Rules

Governs how agents delegate work, split tasks, and coordinate execution in the Win dotfiles repository.

## When to Delegate vs Execute Directly

**Use a subagent when:**
- The work crosses agent specialization boundaries (PowerShell scripting → system optimization → config deployment)
- The task is self-contained enough to hand off and await a result
- Read-only exploration without polluting the current session context is needed
- Parallel execution of independent subtasks is desired

**Execute directly when:**
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
- Never exceed 3-5 parallel tasks in a single wave to avoid context exhaustion

## Context Passing Between Agents

When delegating, pass the minimum necessary context:

1. **File paths** — absolute or repo-relative paths to the files being modified
2. **Constraints** — what must stay unchanged, style rules to follow, CI checks to pass
3. **Prior results** — summaries from previous waves (not raw tool output dumps)

## Handoff Conventions

- Subagents return a **single concise message** summarizing what was done, what changed, and what remains
- Do not return raw tool output lists unless specifically requested
- If a subagent cannot complete its task, state what was blocked and what assumptions were made

## Anti-Patterns

- Launching a subagent for a one-line edit
- Dumping entire file contents into a task prompt instead of referencing paths
- Running dependent tasks in parallel without clear data dependencies
- Letting a subagent silently swallow failures — always request explicit status
