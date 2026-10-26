<!-- OMC:START -->
<!-- OMC:VERSION:5.7.0 -->

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
`haiku` (quick lookups), `sonnet` (standard), `opus` (architecture, deep analysis), `fable` (Claude Fable 5, above Opus).
The session model set via `/model` governs the main loop only; delegated agents run on their pinned tier unless you pass `model` explicitly or set a per-agent `agents.<name>.model` override.
Direct writes OK for: `~/.claude/**`, `.omc/**`, `.claude/**`, `CLAUDE.md`, `AGENTS.md`.
</model_routing>

<skills>
Invoke via `/oh-my-claudecode:<name>`. Trigger patterns auto-detect keywords.
**Canonical workflows (Tier-0):** `plan` → `execute` → `review` → `verify`. Roles: `planner` → `executor` → `reviewer` → `verifier`. `deep-interview` and `ralplan` are independent Tier-0 planning workflows. `research` and `team` are internal lanes; `autopilot`, `autoresearch`, `ralph`, and `ultragoal` remain directly invocable.
**Retired in 5.0.0 (removed, not aliased):** `ultrawork`, `ultraqa`, `ultrapilot`, `swarm`, `pipeline`, `merge-readiness`, `deep-dive`, `sciomc`, `ccg`, `omc-teams`, `setup`, `mcp-setup`, `omc-reference`, `learner`, `writer-memory`, `local-build-reminder`. Use `execute`, `verify`, `review`, `research`, `omc-setup`, `wiki`, `remember`, or `team` instead.
Keyword triggers: `"autopilot"→autopilot`, `"ralplan"→ralplan`, `"deep interview"→deep-interview`, `"deslop"`/`"anti-slop"`→ai-slop-cleaner (→`review`, opt-in), `"deep-analyze"`→analysis mode, `"tdd"`→TDD mode, `"deepsearch"`→codebase search, `"ultrathink"`→deep reasoning, `"cancelomc"`→cancel. Team orchestration is explicit via `/team`.
Release is maintainer-only `omc release` (see Migration Guide); `/release` remains a compatibility alias and never bypasses the release boundary.
Detailed agent catalog, tools, team pipeline, commit protocol, and full skill registry live in the `wiki` skill when skills are available, including reference for `explore`, `planner`, `architect`, `executor`, `designer`, and `writer`; this file remains sufficient without skill support. Specialists remain internal/routable modules (document-specialist, test-engineer, designer, etc.) — not Tier-0 workflows.
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
Hooks inject `<system-reminder>` tags. Key patterns: `hook success: Success` (proceed), `[MAGIC KEYWORD: ...]` (invoke skill), `The boulder never stops` (continuation mode active).
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
Prefer `fd`, `rg`, `jq`/`yq`, `uv` (python), `bun` (js/ts), `7z`, `markitdown` (doc conversion). Shell commands go through `rtk` (see RTK Usage); `eza`/`bat` only when rtk has no rule.
For structural (AST) code search/rewrite, use `@ast-grep/cli` (`ast-grep` / `sg`) instead of regex `rg`.

## Code Standards
- Immutability: new objects, never mutate existing ones.
- Files 200-400 lines typical, 800 max; extract utilities from large files.
- Imports: stdlib, third-party, local; alphabetical within groups.
- Never log or commit secrets; redact sensitive data in logs.
- Comments explain "why", not "what".
- Follow existing project test patterns before marking work complete.
- Minimal, focused changes; one problem at a time.

## Communication Style
- No emojis in code, comments, commits, or docs.
- No em dashes; use hyphens or restructure.
- Clear, direct language, no unnecessary embellishment.
- Review first: when asked to review/analyze, do that and report findings before changing anything.
- Humble language: don't claim "success" without verification. "Successfully" only when tests prove it.

## Memory (Mandatory)
Obsidian vault at `$env:USERPROFILE\Nextcloud\obsidian-vault` is the **canonical durable brain** - it outranks project-scoped memory, the OMC notepad, and harness auto-memory for anything that should survive this session. Those are scratch; the vault is where it actually lives. This applies in every project, not only when the vault itself is the working directory.
**Write the moment one of these happens, don't wait to be asked:** a preference stated, a decision made (+ why), a bug root-caused, a correction/feedback given, a workflow worked out, or a tool/credential/external-resource fact learned.
1. Check first: does `index.md` -> the relevant `_about.md` already cover this? Update, don't duplicate. Search the vault with the `obsidian-hybrid-search` MCP `search` tool (hybrid mode) before `rg`.
2. Write an atomic note in `Memory/` (fact/decision/preference), `Knowledge/` (synthesized topic), or `Projects/` (active work) via the vault's `new-note` skill. Full protocol: `$env:USERPROFILE\Nextcloud\obsidian-vault\CLAUDE.md`.
3. Wikilink it and add a pointer under the folder's `_about.md`.
**Before ending any task, check whether it produced a durable learning - if so, write it before you report completion.**

## Context Tools (context-mode)
Use ctx_execute, ctx_execute_file, ctx_batch_execute, ctx_index, ctx_search, ctx_fetch_and_index to keep raw bytes out of context; derive answers in-sandbox.
**Exception**: use native `WebSearch`/`WebFetch` directly, not `ctx_fetch_and_index`, when the task is a lookup/research question, not raw-byte processing.

## RTK Usage (Max)
- Prefix every shell command with `rtk` when a rule exists (`rtk git`, `rtk gh`, `rtk ls`, `rtk read`, `rtk diff`, `rtk json`, `rtk curl`, `rtk bun`, `rtk uv`, `rtk wc`, `rtk find`). Hook auto-rewrites safe shapes; write `rtk ...` explicitly when unsure.
- Search: use `rtk rg` over `rtk grep`. `grep` only when `rg` cannot do it.
- Pipes disable rtk for the whole command (top leak in `rtk discover`). Exception: in Bash, `cmd | head/tail -N` is auto-rewritten to `rtk cmd | head/tail -N` by `hooks/rtk-advisor.ps1`; any other tail stage (`wc`, `grep`, `sort`, `;` after head) is not. No `$(...)`/backticks, no `timeout` prefix: use native flags (`rtk read f --max-lines N`) and the tool's timeout param.
- PowerShell: use `rtk ls`/`rtk read`/`rtk rg`/`rtk wc -l`, never `Get-ChildItem`/`Get-Content`/`Select-String`.
- Never add `2>&1 | tail`; rtk already truncates and filters output.
- Use `rtk proxy <cmd>` only when raw unfiltered output is needed for debugging.
- Periodically run `rtk discover` and `rtk gain` to find missed rewrites; fix habits it reports.
- Always write `rtk` explicitly for: `git commit`, `cargo build`, `uv run`, `ls -1`, `cat` (use `rtk read`), `du`, `shellcheck`, `bunx`.
- User TOML filters (`~/AppData/Roaming/rtk/filters.toml`: ssh, adb, tasklist, wsl, unzip, sqlite3, yt-dlp, javap, tombi, uv lock, fd, dust) are auto-rewritten by the hook, but only while trusted: trust is a SHA-256 of the file, so after ANY edit run `rtk trust -y` from that directory or every filter silently turns off. Use `"\\b"` escapes (TOML basic strings). Filters under a builtin prefix (`git ls-files`, `cargo tree`) are shadowed and never apply.
- Commit messages: `git commit -m "one line"` or `-F file`. Never `$(cat <<EOF ...)`; hook refuses it and the whole command loses rtk.

@RTK.md

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
Decision tree for when to use it; invocation syntax and tool name are in the CodeGraph section below (auto-managed).
<!-- CODEGRAPH_END -->
