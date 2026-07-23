<!-- OMC:START -->
<!-- OMC:VERSION:4.15.3 -->
# oh-my-claudecode - Intelligent Multi-Agent Orchestration
Running with oh-my-claudecode (OMC), a multi-agent orchestration layer for Claude Code. Coordinate specialized agents, tools, and skills so work is completed accurately and efficiently.
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
Tier-0 workflows: `autopilot`, `ultrawork`, `ralph`, `team`, `ralplan`.
Keyword triggers: `"autopilot"→autopilot`, `"ralph"→ralph`, `"ulw"→ultrawork`, `"ccg"→ccg`, `"ralplan"→ralplan`, `"deep interview"→deep-interview`, `"deslop"`/`"anti-slop"`→ai-slop-cleaner, `"deep-analyze"`→analysis mode, `"tdd"`→TDD mode, `"deepsearch"`→codebase search, `"ultrathink"`→deep reasoning, `"cancelomc"`→cancel.
Team orchestration is explicit via `/team`. Full agent catalog, tools, team pipeline, commit protocol, and skills registry live in the `omc-reference` skill when available; this file remains sufficient without it.
</skills>
<verification>
Verify before claiming completion. Size appropriately: small→haiku, standard→sonnet, large/security→opus. If verification fails, keep iterating.
</verification>
<failure_mode_guards>
User input: when clarification, preference, or approval is required and AskUserQuestion is available, use it instead of ending with a prose question; ask one focused question with 2-4 options. Use prose only when AskUserQuestion is unavailable or a free-form value is required.
Session/worktree continuity: before editing after resume/compaction or inside a linked worktree, re-check `git status --short --branch`, current cwd, and relevant `.omc/state/` or `.omc/handoffs/` artifacts so work doesn't continue on the wrong branch or stale context.
No fake completion: TODO-style placeholder notes, `test.skip`/`.only`, stub tests, and unimplemented branches are blockers, not evidence. Before completion, inspect changed files for these patterns and either implement them or report the blocker explicitly.
</failure_mode_guards>
<execution_protocols>
Broad requests: explore first, then plan. 2+ independent tasks in parallel. `run_in_background` for builds/tests.
Keep authoring and review as separate passes: writer pass creates/revises content, reviewer/verifier pass evaluates it later in a separate lane. Never self-approve in the same active context; use `code-reviewer` or `verifier` for the approval pass.
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
State root: `.omc/` by default, or `$OMC_STATE_DIR/{project-id}/` when set, or the parent `.omc/` when a `.omc-workspace` marker anchors a multi-repo workspace. Runtime state: `.omc/state/`, `.omc/state/sessions/{sessionId}/`, `.omc/notepad.md`, `.omc/project-memory.json`, `.omc/plans/`, `.omc/research/`, `.omc/logs/`, `.omc/artifacts/`, `.omc/handoffs/`, `.omc/ultragoal/` — ignored operational artifacts by default; `.omc/skills/**` is the intentional committable exception. In linked git worktrees, local `.omc/` state is removed with the worktree unless centralized via `OMC_STATE_DIR`.
</worktree_paths>
## Setup
Say "setup omc" or run `/oh-my-claudecode:omc-setup`.
<!-- OMC:END -->
<!-- User customizations -->
## Tool Preferences
- **File search (agent tool calls)**: fff MCP tools, not Glob/fd/find/ls
- **File search (shell/scripts/hooks)**: `fd`, never `find`
- **Text search**: `rg`, not `grep`
- **Code structure search**: `ast-grep`, not grep/rg, for structural patterns
- **Semantic code navigation**: LSP (goToDefinition, findReferences) for symbol nav/refactoring — see LSP Enforcement
- **Data processing**: `jq -c` for JSON, `yq` for YAML/XML
- **File listing**: `eza`, not `ls`
- **File viewing**: `bat`, not `cat`
- **Text processing**: `sed` for stream editing, `awk` for pattern scanning
- **Python packages**: `uv`, not `pip` (`uv add`, `uv run`, `uvx`)
- **JS packages**: `bun`, not `npm`
- **Zip operations**: Always 7-Zip (`C:\Program Files\7-Zip\7z.exe`) for creating/modifying/appending ZIP archives — never Python's `zipfile` or the `zip` CLI for writes (not on bash PATH, call via full path or PowerShell). `zipfile` is fine read-only.
## LSP Enforcement
**Three Iron Laws:**
1. No modifying unfamiliar code without goToDefinition first.
2. No refactoring without findReferences impact analysis first.
3. No claiming code works without LSP diagnostics verification.

LSP over grep/glob for: symbol navigation (goToDefinition), find-all-usages (findReferences), type info/docs (hover), file structure (documentSymbol), call graphs (incomingCalls/outgoingCalls). Grep stays for literal text search (TODOs, strings, config); Glob for file patterns.

**Pre-edit:** goToDefinition → findReferences → hover → then edit.
**Post-edit:** LSP diagnostics → no new type errors → imports resolve → interface contracts valid.
Why: ~50ms vs 45s grep, exact semantic matches, no false positives, saves tokens on large codebases.
## Code Standards
- **KISS**: simple, maintainable over clever.
- **YAGNI**: don't build for hypothetical future needs.
- **DRY**: extract repeated logic into utilities.
- **Naming**: descriptive, self-documenting (getUserById, not getUsr).
- **Function size**: small, single-purpose; split if doing multiple things.
- **Fail fast**: validate inputs early, fail immediately with clear errors.
- **Security**: never log/commit secrets, validate all inputs, redact sensitive data in logs.
- **Imports**: group stdlib → third-party → local, alphabetical within groups.
- **Error handling**: meaningful, actionable messages.
- **Comments**: explain "why", not "what".
- **Testing**: follow existing project patterns before marking work complete.
- **Changes**: minimal, focused, one problem at a time.
- **Immutability**: new objects, never mutate existing ones.
- **File size**: 200-400 lines typical, 800 max; extract utilities from large files.
## Communication Style
- No emojis in code, comments, commits, or docs.
- No em dashes; use hyphens or restructure.
- Clear, direct language, no unnecessary embellishment.
- Review first: when asked to review/analyze, do that and report findings before changing anything.
- Humble language: don't claim "success" without verification. "Successfully" only when tests prove it.
  - Bad: "Successfully implemented feature X, ready for testing"
  - Good: "Implemented feature X, ready for testing" / "Ran tests for feature X, they all passed"
## Agent Orchestration
OMC agents load via the plugin; custom agents go in `.claude/agents/`. Delegate via `Task(subagent_type="agent-name", prompt="...")`.

| Agent | When to use |
|---|---|
| general-purpose | Default; complex multi-step tasks, delegation |
| code-simplifier | Simplify/refine code without changing behavior |
| janitor | Cleanup, tech debt, dead code removal (framework-safe) |
| merge-supervisor | Git merge conflict resolution |
| code-explorer | Trace execution, find patterns, map architecture |
| context-manager | Context engineering, token optimization, multi-agent orchestration |
| bash-pro, python-pro, javascript-pro, typescript-pro, rust-pro | Language-specific implementation |
| mcp-expert | MCP server config and integration |
| dx-optimizer | Dev experience, tooling, workflow setup |
| llm-boost | LLM optimization: CLAUDE.md audit, skill/agent improvement, markdown compression |
| prd | Product requirements document |
| reverse-engineer | Binary analysis, RE toolchains, security research |
| turbo | Maximum speed, parallelize everything |

Parallel: independent work (e.g. security + perf review + type check) in one turn.
Multi-perspective: for hard problems, split roles — factual reviewer, senior engineer, security expert, consistency reviewer.
## Session Management
For ~ and GitHub work, break sessions into focused tasks of 15-20 turns. `/clear` between subtasks. Fresh session per new feature/bug fix.
## Prompt Best Practices
Specify: (1) action verb, (2) target file/component, (3) expected behavior.
Example: not "fix the bug" — "fix the null pointer in the auth handler when user.email is missing".
## Progressive Disclosure
Keep this file short, high-frequency rules only. Detailed workflows go in SKILL.md files. Prefer pointers over long code blocks.
## Memory (Mandatory)
Obsidian vault at `$env:USERPROFILE\Nextcloud2\obsidian-vault` is the **canonical durable brain** - it outranks project-scoped memory, the OMC notepad, and harness auto-memory for anything that should survive this session. Those are scratch; the vault is where it actually lives. This applies in every project, not only when the vault itself is the working directory.
**Write the moment one of these happens, don't wait to be asked:** a preference stated, a decision made (+ why), a bug root-caused, a correction/feedback given, a workflow worked out, or a tool/credential/external-resource fact learned.
1. Check first: does `Index.md` -> the relevant `_about.md` already cover this? Update, don't duplicate.
2. Write an atomic note: `Memory/` (fact/decision/preference), `Knowledge/` (synthesized topic), or `Projects/` (active work) - use the vault's templates. Full protocol: `C:\Users\Ven0m0\Nextcloud2\obsidian-vault\CLAUDE.md`.
3. Wikilink it and add a pointer under the folder's `_about.md`.
**Before ending any task, check whether it produced a durable learning - if so, write it before you report completion.**

@RTK.md
