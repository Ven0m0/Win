<!-- OMC:START -->
<!-- OMC:VERSION:5.8.6 -->

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

## Tools
- Prefer `fd`, `rg`, `jq`/`yq`, `uv` (python), `bun` (js/ts), `7z`, `markitdown`. Shell goes through `rtk`; `eza`/`bat` only when rtk has no rule.
- File search: fff MCP tools; if fff is not connected (it refuses a home-dir cwd), use `rtk rg` / `fd`. Structural (AST) search/rewrite: `ast-grep` / `sg`, not regex.
- Native Windows: PowerShell for registry, services, admin, .NET objects. Call the explicit `.exe` when an alias shadows it (`sort`, `ls`, `cat`). Never assume a POSIX shell or Unix paths.
- Browser operations (automation, browsing, scraping, screenshots, UI testing): always prefer Patchright, only Patchright (`mcp__patchright__*`, Python `patchright` via `uv run --with patchright`, Node `patchright`). Never install `playwright` / `@playwright/mcp` or re-enable the `playwright` plugin.
- GitHub: use `gh`, not a GitHub MCP server (the claude.ai connector is denied in settings).

## Docs Lookup
Before using or changing a library, framework, SDK, API or CLI tool, check docs via MCP, not memory.
- `ref_search_documentation` then `ref_read_url` first (returns only the relevant section); `context7` (`resolve-library-id`, `query-docs`) when ref-tools is down or lacks the library.
- Read the project's manifest first so the lookup targets the pinned version.
- Skip for refactoring, scripts from scratch, business-logic debugging, code review, general concepts.

## Code Standards
- Immutability: return new objects, never mutate.
- Files 200-400 lines typical, 800 max.
- Imports: stdlib, third-party, local; alphabetical within groups.
- Secrets: never log or commit them. `hooks/guard-secrets.ps1` runs gitleaks before `git commit` / `git push`; treat a block as real.
- Follow the project's existing test patterns before calling work complete.

## Communication
- No emojis or em dashes (use hyphens or restructure).
- When asked to review or analyze, report findings before changing anything.
- No "success" claim without verification; "successfully" only when tests prove it.
- Most important information last: the user reads the end first.
- State each fact once, in plain specific words. No analogies, decorative headings, flattery or filler. Challenge wrong assumptions and say why.
- Answer the question asked ("No. The only match is the file itself."). Stay in scope: no cleanup, refactoring, docs or adjacent features unless asked.
- Banned phrases: "load-bearing", "worth stating plainly", "here's the honest truth", "the real tension", "carry the argument".
- With 3+ findings, decisions, options, risks, questions or actions, label them `F1`, `D1`, `O1`, `R1`, `Q1`, `A1` and keep the codes for the rest of the conversation.
- Aliases (only when the whole message is the alias): `scr` = simplify, compress, repeat the last response. `eli` = explain for an 18-year-old, simpler and shorter. `foc` = boil down to the signal that matters most. `ref` = rewrite the last response with reference codes.

## Memory (Mandatory)
The Obsidian vault at `$env:USERPROFILE\Nextcloud\obsidian-vault` is the only durable memory, in every project. Do not use the OMC notepad (`.omc/notepad.md`, `<remember>` tags), `.omc/project-memory.json`, or any memory MCP/CLI; harness auto-memory is session scratch.
Write the moment a preference is stated, a decision is made (+ why), a bug is root-caused, feedback is given, a workflow is worked out, or a tool/credential/resource fact is learned. Before ending a task, write any durable learning before reporting completion.
1. Check first: `index.md` then the relevant `_about.md`. Search with the `obsidian-hybrid-search` MCP `search` tool (hybrid mode) before `rg`. Update, don't duplicate.
2. Write an atomic note in `Memory/` (fact/decision/preference), `Knowledge/` (topic) or `Projects/` (active work) via the vault's `new-note` skill. Protocol: the vault's `CLAUDE.md`.
3. Wikilink it and add a pointer under the folder's `_about.md`.

## Context
- Code mode: when a step counts, sums, filters or joins over about 20 lines of data, or needs 3+ dependent tool calls, run one `ctx_execute` script and print only the answer. Use `ctx_search` / `ctx_index` for large results. Single small reads, edits and one-off commands stay direct.
- Lookup or research questions use native `WebSearch` / `WebFetch`, not `ctx_fetch_and_index`.
- Set a read budget before exploring (spec-driven build 8, bug fix at a known spot 5, refactor 1 per changed file, open exploration 15); ask before exceeding it.
- Read large outputs selectively (offset/limit, `rtk rg`). `/clear` between subtasks; `/compact` near 50%.

## RTK
- Prefix shell commands with `rtk` when a rule exists (`git`, `gh`, `ls`, `read`, `diff`, `json`, `curl`, `bun`, `uv`, `wc`, `find`); the hook rewrites safe shapes. Always write it explicitly for `git commit`, `cargo build`, `uv run`, `ls -1`, `cat` (use `rtk read`), `du`, `shellcheck`, `bunx`.
- Search with `rtk rg`, not `rtk grep`. In PowerShell use `rtk ls` / `rtk read` / `rtk rg` / `rtk wc -l`, not `Get-ChildItem` / `Get-Content` / `Select-String`.
- A pipe disables rtk for the whole command, except Bash `cmd | head/tail -N` (auto-rewritten by `hooks/rtk-advisor.ps1`). No `$(...)`, backticks or `timeout` prefix: use native flags (`rtk read f --max-lines N`) and the tool's timeout param. Never add `2>&1 | tail`.
- Commit messages: `git commit -m "one line"` or `-F file`, never `$(cat <<EOF ...)` (the hook refuses it).
- `rtk proxy <cmd>` only for raw output when debugging. Run `rtk discover` / `rtk gain` periodically.
- User TOML filters in `~/AppData/Roaming/rtk/filters.toml` apply only while trusted (SHA-256 of the file): after ANY edit run `rtk trust -y` from that directory or every filter silently turns off. Use `"\\b"` escapes. Filters under a builtin prefix (`git ls-files`, `cargo tree`) are shadowed.

@RTK.md

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
Decision tree for when to use it; invocation syntax and tool name are in the CodeGraph section below (auto-managed).
<!-- CODEGRAPH_END -->
