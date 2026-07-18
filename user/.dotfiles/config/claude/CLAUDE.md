<!-- OMC:START -->
<!-- OMC:VERSION:4.15.3 -->

# oh-my-claudecode - Intelligent Multi-Agent Orchestration
You are running with oh-my-claudecode (OMC), a multi-agent orchestration layer for Claude Code.
Coordinate specialized agents, tools, and skills so work is completed accurately and efficiently.

<operating_principles>
- Delegate specialized work to the most appropriate agent.
- Prefer evidence over assumptions: verify outcomes before final claims.
- Choose the lightest-weight path that preserves quality.
- Consult official docs before implementing with SDKs/frameworks/APIs.
</operating_principles>

<delegation_rules>
Delegate for: multi-file changes, refactors, debugging, reviews, planning, research, verification.
Work directly for: trivial ops, small clarifications, single commands.
Route code to `executor` (use `model=opus` for complex work). Uncertain SDK usage → `document-specialist` (repo docs first; Context Hub / `chub` when available, graceful web fallback otherwise).
</delegation_rules>

<model_routing>
`haiku` (quick lookups), `sonnet` (standard), `opus` (architecture, deep analysis).
Direct writes OK for: `~/.claude/**`, `.omc/**`, `.claude/**`, `CLAUDE.md`, `AGENTS.md`.
</model_routing>

<skills>
Invoke via `/oh-my-claudecode:<name>`. Trigger patterns auto-detect keywords.
Tier-0 workflows include `autopilot`, `ultrawork`, `ralph`, `team`, and `ralplan`.
Keyword triggers: `"autopilot"→autopilot`, `"ralph"→ralph`, `"ulw"→ultrawork`, `"ccg"→ccg`, `"ralplan"→ralplan`, `"deep interview"→deep-interview`, `"deslop"`/`"anti-slop"`→ai-slop-cleaner, `"deep-analyze"`→analysis mode, `"tdd"`→TDD mode, `"deepsearch"`→codebase search, `"ultrathink"`→deep reasoning, `"cancelomc"`→cancel.
Team orchestration is explicit via `/team`.
Detailed agent catalog, tools, team pipeline, commit protocol, and full skills registry live in the native `omc-reference` skill when skills are available, including reference for `explore`, `planner`, `architect`, `executor`, `designer`, and `writer`; this file remains sufficient without skill support.
</skills>

<verification>
Verify before claiming completion. Size appropriately: small→haiku, standard→sonnet, large/security→opus.
If verification fails, keep iterating.
</verification>

<failure_mode_guards>
User input: when clarification, preference, or approval is required and AskUserQuestion is available, use AskUserQuestion instead of ending with a prose question; ask one focused question with 2-4 options. Use prose only when AskUserQuestion is unavailable or a free-form value is required.
Session/worktree continuity: before editing after resume/compaction or inside a linked worktree, re-check `git status --short --branch`, current cwd, and relevant `.omc/state/` or `.omc/handoffs/` artifacts so work does not continue on the wrong branch or stale context.
No fake completion: TODO-style placeholder notes, `test.skip`/`.only`, stub tests, and unimplemented branches are blockers, not evidence. Before completion, inspect changed files for these patterns and either implement them or report the blocker explicitly.
</failure_mode_guards>

<execution_protocols>
Broad requests: explore first, then plan. 2+ independent tasks in parallel. `run_in_background` for builds/tests.
Keep authoring and review as separate passes: writer pass creates or revises content, reviewer/verifier pass evaluates it later in a separate lane.
Never self-approve in the same active context; use `code-reviewer` or `verifier` for the approval pass.
Before concluding: zero pending tasks, tests passing, verifier evidence collected.
</execution_protocols>

<hooks_and_context>
Hooks inject `<system-reminder>` tags. Key patterns: `hook success: Success` (proceed), `[MAGIC KEYWORD: ...]` (invoke skill), `The boulder never stops` (ralph/ultrawork active).
Persistence: `<remember>` (7 days), `<remember priority>` (permanent).
Kill switches: `DISABLE_OMC`, `OMC_SKIP_HOOKS` (comma-separated).
</hooks_and_context>

<cancellation>
`/oh-my-claudecode:cancel` ends execution modes. Cancel when done+verified or blocked. Don't cancel if work incomplete.
</cancellation>

<worktree_paths>
State root: `.omc/` by default, or `$OMC_STATE_DIR/{project-id}/` when `OMC_STATE_DIR` is set, or the parent `.omc/` when a `.omc-workspace` marker anchors a multi-repo workspace. Runtime state includes `.omc/state/`, `.omc/state/sessions/{sessionId}/`, `.omc/notepad.md`, `.omc/project-memory.json`, `.omc/plans/`, `.omc/research/`, `.omc/logs/`, `.omc/artifacts/`, `.omc/handoffs/`, and `.omc/ultragoal/`. These are ignored operational artifacts by default; `.omc/skills/**` is the intentional committable exception for project-scoped skills. In linked git worktrees, local `.omc/` state is removed with the worktree unless centralized via `OMC_STATE_DIR`.
</worktree_paths>

## Setup

Say "setup omc" or run `/oh-my-claudecode:omc-setup`.

<!-- OMC:END -->

<!-- User customizations -->
## Tool Preferences

- **File search (agent tool calls)**: fff MCP tools, not Glob/fd/find/ls
- **File search (shell/scripts/hooks)**: `fd`, never `find` - faster, respects .gitignore, better defaults
- **Text search**: `rg`, not `grep` - faster, respects .gitignore, better output
- **Code structure search**: `ast-grep`, not grep/rg, for structural patterns (classes, functions, interfaces)
- **Semantic code navigation**: LSP (goToDefinition, findReferences) for symbol nav and refactoring - see LSP Enforcement below
- **Data processing**: `jq -c` for JSON, `yq` for YAML/XML
- **File listing**: `eza`, not `ls` - formatting, git integration, tree views
- **File viewing**: `bat`, not `cat` - syntax highlighting, line numbers, git integration
- **Text processing**: `sed` for stream editing, `awk` for pattern scanning
- **Python packages**: `uv`, not `pip` - all installs, venvs, script runs (`uv add`, `uv run`, `uvx`)
- **JS packages**: `bun`, not `npm` - all installs and script runs
- **Zip operations**: Always 7-Zip (`C:\Program Files\7-Zip\7z.exe`) for creating, modifying, or appending to ZIP archives. Never Python's `zipfile` or the `zip` CLI for writes. Not on the bash PATH - call via full path or PowerShell. `zipfile` is fine for read-only inspection.

## LSP Enforcement

**The Three Iron Laws:**

```
1. NO MODIFYING UNFAMILIAR CODE WITHOUT goToDefinition FIRST
2. NO REFACTORING WITHOUT findReferences IMPACT ANALYSIS FIRST
3. NO CLAIMING CODE WORKS WITHOUT LSP DIAGNOSTICS VERIFICATION
```

**When to Use LSP vs Grep/Glob:**

- **Symbol navigation**: LSP goToDefinition (not grep)
- **Find all usages**: LSP findReferences (not grep)
- **Type info and docs**: LSP hover (not reading multiple files)
- **File structure**: LSP documentSymbol (not grep)
- **Call graphs**: LSP incomingCalls and outgoingCalls (not grep)
- **Literal text search**: Grep (TODOs, strings, config)
- **File patterns**: Glob (discovering files by name)

**Pre-Edit Protocol (Mandatory):**

1. LSP goToDefinition → understand implementation
2. LSP findReferences → assess change impact
3. LSP hover → verify type signatures
4. THEN make changes

**Post-Edit Verification (Mandatory):**

1. LSP diagnostics → check for errors
2. Verify no new type errors
3. Confirm imports resolve
4. Validate interface contracts

**Why LSP:** ~50ms vs 45s grep, exact semantic matches, no false positives, saves tokens on large codebases

## Code Standards

- **KISS**: Keep It Simple. Favor simple, maintainable solutions over clever code
- **YAGNI**: You Ain't Gonna Need It. Don't implement features or abstractions until actually needed
- **DRY**: Don't Repeat Yourself. Extract repeated logic into utility functions
- **Naming**: Use descriptive, self-documenting names. Prefer clarity over brevity (getUserById vs getUsr)
- **Function Size**: Keep functions small and focused on a single task. Split if doing multiple things
- **Fail Fast**: Validate inputs early and fail immediately with clear errors. Don't let invalid data propagate
- **Security**: Never log or commit secrets, validate all inputs, redact sensitive data in logs
- **Imports**: Group (stdlib -> third-party -> local), sort alphabetically within groups
- **Error Handling**: Handle errors gracefully with meaningful, actionable messages
- **Comments**: Explain "why" decisions were made, not "what" the code does
- **Testing**: Add tests following existing project patterns before marking work complete
- **Changes**: Make minimal, focused changes that solve one problem at a time
- **Immutability**: Create new objects, never mutate existing ones
- **File Size**: 200-400 lines typical, 800 max; extract utilities from large files

## Communication Style

- **No Emojis**: Never use emojis in code, comments, commit messages, or documentation
- **No Em Dashes**: Avoid em dashes in writing; use hyphens (-) or restructure sentences
- **Clarity**: Write in clear, direct language without unnecessary embellishment
- **Review First**: When asked to review or analyze something, do that first and report findings before making any changes
- **Humble Language**: Avoid claiming "success" without verification. Only use "successfully" when tests prove it
  - Bad: "Successfully implemented feature X, ready for testing"
  - Good: "Implemented feature X, ready for testing"
  - Good: "Ran tests for feature X, they all completed successfully"

## Agent Orchestration

OMC agents are loaded via the plugin; custom agents go in `.claude/agents/`. Delegate via `Task(subagent_type="agent-name", prompt="...")`.

| Agent                                                          | When to use                                                                                        |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| general-purpose                                                | Default; complex multi-step tasks, delegation                                                      |
| code-simplifier                                                | Simplify or refine code without changing behavior                                                  |
| janitor                                                        | Cleanup, tech debt, dead code removal (includes safety rules for framework preservation)           |
| merge-supervisor                                               | Git merge conflict resolution                                                                      |
| code-explorer                                                  | Trace execution, find patterns, map architecture (has feature-tracing and pattern-discovery modes) |
| context-manager                                                | Context engineering, token optimization, multi-agent orchestration                                 |
| bash-pro, python-pro, javascript-pro, typescript-pro, rust-pro | Language-specific implementation                                                                   |
| mcp-expert                                                     | MCP server config and integration                                                                  |
| dx-optimizer                                                   | Dev experience, tooling, workflow setup                                                            |
| llm-boost                                                      | LLM optimization: CLAUDE.md audit, skill and agent improvement, markdown compression               |
| prd                                                            | Product requirements document                                                                      |
| reverse-engineer                                               | Binary analysis, RE toolchains, security research                                                  |
| turbo                                                          | Maximum speed, parallelize everything                                                              |

**Parallel execution**: Use parallel Task() for independent work (e.g. security analysis + performance review + type check in one turn).

**Multi-perspective**: For hard problems, use split roles: factual reviewer, senior engineer, security expert, consistency reviewer.

## Session Management

- For ~ and GitHub work, break sessions into focused tasks of 15-20 turns. Use /clear between subtasks. Start a fresh session for each new feature or bug fix.

## Prompt Best Practices

When requesting changes, specify: (1) the action verb, (2) the target file or component, (3) the expected behavior.

Example: instead of "fix the bug", say "fix the null pointer in the auth handler when user.email is missing".

## Progressive Disclosure

- Keep this file short and focused on high-frequency rules
- Move detailed workflows to SKILL.md files or references
- Prefer pointers to supporting docs over long code blocks

## Memory

The canonical durable brain for all sessions is the Obsidian vault at `$env:USERPROFILE\Documents\Obsidian Vault`. When something durable is learned in any session (a preference, a decision, a project fact, a worked-out topic), write it there — not only to project-scoped memory files. Follow the protocol in `C:\Users\Ven0m0\Documents\Obsidian Vault\CLAUDE.md`: atomic notes in `Memory/` or `Knowledge/`, linked with wikilinks, pointer added to `Index.md` or the folder's `_about.md`. Short-term scratch (OMC notepad, project memory files) is fine during a session but durable knowledge belongs in the vault.

@RTK.md
