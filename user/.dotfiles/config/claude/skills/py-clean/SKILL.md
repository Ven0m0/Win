---
name: py-clean
description: >
  Clean up, fix and validate Python code in a repo with ruff, basedpyright, ty, vulture and
  deadcode: lint and format, fix type errors, remove dead code, and get the pre-commit/prek
  hooks green. Use whenever the user asks to clean up, lint, type-check, validate or "fix the
  hook errors" for Python, mentions basedpyright, ty, ruff, vulture, deadcode, dead or unused
  code, prek or pre-commit failing on Python checks, or wants a Python codebase tidied before
  a commit or PR, even if they name only one of these tools.
---

# py-clean

Run the Python quality tools in an order that keeps each step's output meaningful, fix what they
find, and prove the result with the repo's own hooks. Prefer the repo's configuration over
defaults: the hook entries are the ground truth for what "passing" means.

## 0. Discover the repo's setup

Read before running anything, because flags matter (for example ty needing extra search paths):

- `.pre-commit-config.yaml` (prek reads it too): copy the exact `entry:` of the ty and
  basedpyright hooks and use those commands, not bare `ty check`.
- `pyproject.toml`, `ruff.toml`, `pyrightconfig.json`, `ty.toml` for settings and excludes.
- Run Python tools through `uv run` / `uv tool run` if the repo uses uv; never bare `python`.
- Check `git status` first. If the tree has staged or unrelated edits, say so and keep changes
  scoped so the user can review the diff.

## 1. Order: ruff, then types, then dead code

**Always run every tool below on every invocation: ruff, `ty check --fix .`, basedpyright,
vulture, deadcode, and prek.** Do not skip one because the repo's hooks or docs name a
different type checker (for example pyrefly), because it is not configured, or because an
earlier tool was clean. If a tool is missing, install it (see Missing tools) and run it. Run
with the repo's flags/paths where configured, defaults otherwise.

1. **ruff** first, since it removes noise the later tools would otherwise report.
   `ruff check --fix <paths>` then `ruff format <paths>`.
   Do not blanket `# noqa` or widen `ignore`; fix the cause unless the rule is genuinely wrong
   for the repo, and then say so.
2. **Type checkers**, using the hook commands from step 0:
   - `basedpyright` (or `uv tool run basedpyright`)
   - `ty check --fix .` plus the hook's flags (`--python-platform`, `--extra-search-path` ...);
     rerun without `--fix` afterwards to see what is left
   Both usually flag the same root cause, so fix once and rerun both. Frequent causes:
   - `importlib.util.spec_from_file_location` returns `ModuleSpec | None`: assert spec and
     loader are not None, and annotate the loaded module as `Any` if the test monkeypatches it.
   - `unresolved-import` for sibling modules that scripts add via `sys.path.insert`: tell the
     checker the path (`--extra-search-path <dir>` for ty, `extraPaths` in pyrightconfig)
     rather than rewriting imports.
   - Optional narrowing: prefer an `assert x is not None` or early return over `cast`/`# type: ignore`.
   Use `# type: ignore[code]` / `# pyright: ignore[rule]` only with the specific code and a
   reason, and only when the code is right and the stub is wrong.
3. **Dead code**, last, because earlier fixes can orphan code and type errors can hide uses:
   - `vulture <paths> --min-confidence 60`
   - `deadcode <paths>` (`--dry --fix` previews removals; `--exclude`, `--ignore-names`,
     `--ignore-names-in-files` suppress false positives)
   Treat a finding as real only if both tools agree, or you verify it yourself.

## 2. Verify before deleting dead code

Both tools are static and miss dynamic use, so for every candidate:

- `rg -n '\bname\b'` across the whole repo, including docs, scripts, YAML/TOML/shell, tests,
  `__all__`, `getattr`/string dispatch, entry points and CLI command tables.
- Framework hooks and public API (decorated handlers, dunder methods, re-exports, config
  constants read by other languages) are not dead just because Python never calls them.
  Leave them, or whitelist them (`vulture --make-whitelist`, `--ignore-names`) if the user
  wants quiet output.
- A name mentioned only in prose (TODO.md, a planned snippet) is still unused code; delete it
  but mention the leftover reference.
- After deleting, rerun ruff: removed functions often orphan imports (`ruff check --fix`).
- If a deletion is large or the use is ambiguous, list the candidates and ask instead of cutting.

## 3. Validate

1. Rerun every tool from steps 1 and 2 until each is clean.
2. Run the repo's tests (look for `tools/tests`, `tests/`, a `pytest` config, or test scripts
   with a `__main__` runner) and `python -m py_compile` equivalents via `uv run`.
3. Always run the real gate: `prek run --all-files` (fall back to `pre-commit run --all-files`
   only if prek is unavailable). A hook can pass standalone and fail in the gate because of
   flags or file selection, so this is the proof. If the repo has no pre-commit config, run
   prek anyway and report that nothing was configured.
4. Check the line endings of files you edited on Windows: editing via Python text mode can
   rewrite LF as CRLF and produce git noise. Use `newline=''` or `sed -i 's/\r$//'`.

## 4. Report

State what each tool found, what you changed, and the final status per tool and per hook, using
the commands you actually ran. Name anything left unfixed or suppressed and why, anything not run
(tests absent, tool missing), and any removals that rest on grep rather than a test. Do not claim
the repo is clean beyond the checks run. Do not commit unless asked.

## Missing tools

If a tool is not installed: `uv tool install ruff basedpyright ty vulture deadcode` (one per
call) or use `uvx <tool>`. If the repo does not configure a tool, run it with defaults but do not
add config or hooks unless asked.
