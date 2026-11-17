---
name: lint-llm-files
description: Audit and improve the LLM/agent instruction files in a folder (CLAUDE.md, AGENTS.md, GEMINI.md, SKILL.md, .cursorrules, MCP configs, .claude/ agents and commands) with agnix, ctxlint, schliff and optionally Upkeep. Use whenever the user wants to lint, score, clean up, tighten, or "improve" CLAUDE.md / AGENTS.md / skill files / context files in the current folder or repo, mentions agnix, ctxlint, schliff or Upkeep, or asks why an agent config is bloated, stale, or ignored. Trigger even if they only say "improve the llm files here".
---

# lint-llm-files

Run four linters over the instruction files in a target folder, merge the findings, fix what is safe, and report what remains. Report first, edit second: the files are the user's behavior contract, so show the findings before changing anything beyond safe auto-fixes.

## Runner rules (why: user keeps pip/npm out of the system)

| Tool | Runs via | Notes |
|---|---|---|
| ctxlint | `bunx --bun @ctxlint/ctxlint ...` | npm package, never `npx` |
| schliff | `uvx schliff ...` | PyPI package, never `pip install` |
| agnix | `agnix ...` if on PATH, else `npx -y agnix ...` | the one exception: agnix is not run with bunx/uvx |
| Upkeep | clone + `bun install` + its script | opt-in, see below |

Use `rtk` prefixes per global rules. Target = the folder given by the user, default cwd. Call it `$T`.

## Steps

1. **Discover files.** List candidates in `$T` (CLAUDE.md, AGENTS.md, GEMINI.md, `**/SKILL.md`, .cursorrules, .mcp.json, `.claude/**`). Skip `node_modules`, vendored dirs. If none, stop and say so.

2. **Baseline (read-only, run in parallel).**
   - `agnix --target claude-code $T` (drop `--target` if the folder targets several tools). Validates schema, frontmatter, hooks, MCP, cross-file rules.
   - `bunx --bun @ctxlint/ctxlint check $T --format json` finds stale refs and content the agent could infer itself. Also `bunx --bun @ctxlint/ctxlint mcp $T` if an MCP config exists.
   - `uvx schliff score <file>` per instruction file (it takes one file; loop). Then `uvx schliff check-commands <file> --repo $T` for dangling build/test commands, and `uvx schliff suggest <file>` for ranked fixes.
   Save raw output to the scratchpad; summarize with a script or ctx_execute rather than pasting it.

3. **Report.** One merged table: file, tool, severity, finding, fix. Dedupe the same issue flagged by two tools. Label findings F1, F2, ... Put the highest-severity items last.

4. **Apply fixes after the user agrees** (or immediately for safe ones if they said to just do it):
   - `agnix --fix-safe $T` first; use `--dry-run --show-fixes` to preview. Never `--fix-unsafe` without asking.
   - Hand-edit ctxlint/schliff findings: delete inferable or stale lines, repair dead paths/commands, tighten vague rules. Keep rules that carry a real "why".
   - Do not invent commands or paths; verify each against the repo.

5. **Re-run** the same commands and show before/after (schliff score, agnix error count, ctxlint issue count). If a score got worse, revert that edit.

6. **Upkeep (opt-in).** It spawns Claude reviewers, so it burns subscription usage and takes minutes. Ask before running. It checks drift between docs and code, which the other three cannot. Run:
   ```
   git clone --depth 1 https://github.com/wei18/upkeep ~/.cache/upkeep   # skip if present, else git pull
   cd ~/.cache/upkeep && bun install
   ./scripts/local-audit.sh $T --out <scratchpad>/upkeep-report.html
   ```
   Needs a logged-in `claude` CLI, Node 20+, git. Upkeep's README documents `npm ci`; `bun install` is the substitution for the user's rule. If it fails under bun, fall back to `npm ci` and tell the user. On Windows the `.sh` script needs Git Bash.

## Output

End with: files changed, before/after numbers, anything skipped (e.g. Upkeep not run) and anything the tools disagree on.

## Gotchas

- schliff and ctxlint score structure, not truth. A high score does not mean the rules are correct.
- ctxlint's "inferable content" flag can be wrong for non-obvious conventions; keep a line if the code alone would not reveal it.
- Files synced by Nextcloud with `files_autorename` may be lowercased; leave CLAUDE.md/SKILL.md names untouched.
