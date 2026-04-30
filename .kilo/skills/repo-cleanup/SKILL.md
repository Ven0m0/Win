---
name: repo-cleanup
description: "Systematic repository cleanup: dead code removal, doc pruning, legacy cleanup"
compatibility: opencode
---

# Repository Cleanup Skill

Use this skill when asked to clean up a repository, organize folders, remove legacy code, prune documentation, or perform a full repo janitor pass. Prioritizes safety and reversibility.

## Six-Step Cleanup Process

### Step 1: Separate Code from Documentation

Before deleting anything, identify what is executable/distributable code and what is guidance/docs.

| Category | Examples | Action |
|---|---|---|
| Code | `.ps1`, `.bat`, `.ahk`, `.py`, `.js` | Keep; refactor if needed |
| Config | `.json`, `.yaml`, `.reg`, `.xml` | Keep; validate format |
| Tests | `*.Tests.ps1`, `test/` | Keep; move to canonical location |
| Docs | `*.md`, `README`, `CHANGELOG` | Review for duplication/staleness |
| Scripts | one-off helpers, scratch files | Evaluate; archive or delete |
| Build artifacts | `dist/`, `node_modules/`, `.next/` | Delete; add to `.gitignore` |

Create a temporary inventory list before making changes.

### Step 2: Organize Folder Structure

Enforce the repo's canonical layout. For Ven0m0/Win:

- `Scripts/` — executable PowerShell automation
- `Scripts/Common.ps1` — shared helpers only
- `Scripts/auto/` — unattended install XML only (no flat scripts)
- `user/.dotfiles/config/` — tracked dotfiles
- `tests/` — Pester tests (not inside `Scripts/`)
- `.kilo/skills/` — agent skills as `<name>/SKILL.md`
- `.kilo/agents/` — agent definitions
- `.kilo/commands/` — command reference markdown
- `.github/` — CI, instructions, skills, copilot prompts

Move misplaced files to their canonical homes. Update any internal references.

### Step 3: Remove Legacy Code

Identify candidates for removal:

- Functions with no callers (use `grep` / `lspFindReferences`)
- Scripts superseded by newer versions
- Old registry tweaks that target unsupported OS builds
- Commented-out blocks older than two releases
- Dead branches in conditional logic (`if ($false) { ... }`)

Safety rule: if a script has no tests and no clear caller, mark it with a deprecation comment first. Delete only after confirming no external dependencies.

### Step 4: Remove Script Clutter

Clean up the automation surface:

- Merge one-off helper scripts into `Scripts/Common.ps1` if they are reusable
- Delete scratch/test scripts committed by accident
- Remove hardcoded paths, machine names, or personal tokens
- Standardize shebangs and `#Requires` statements
- Ensure every script in `Scripts/` has a clear purpose documented in comment-based help

### Step 5: Prune Documentation Sprawl

Docs should be authoritative, not duplicative:

- Consolidate overlapping README sections
- Remove outdated setup instructions (e.g., Windows 8 guides)
- Delete empty or placeholder markdown files
- Ensure `AGENTS.md` is the single source of truth for AI guidance
- Keep `.github/copilot-instructions.md` minimal; move broad rules to `AGENTS.md`
- Remove hyperbolic language (`comprehensive`, `ultimate`, `revolutionary`)

### Step 6: Clean Doc Content

Normalize markdown style:

- Remove emojis unless explicitly requested by user
- Remove decorative horizontal rules used as section separators
- Ensure consistent heading levels (no jumps from `#` to `###`)
- Fix broken internal links
- Add YAML frontmatter to skill files that lack it
- Run `ctxlint` on `.github/` guidance if available

## Safety Checks Before Deletion

1. **Git status**: ensure working tree is clean before starting
2. **References**: search for the file/symbol across the repo (`grep`, `localSearchCode`)
3. **Tests**: verify no tests import or invoke the target
4. **CI**: check `.github/workflows/` for references
5. **Rollback plan**: stage deletions in a single commit so revert is one command

```bash
# Create a checkpoint branch
git checkout -b cleanup/$(date +%Y%m%d)
```

## Git History Preservation

- Never rewrite history of the main branch (no `git filter-branch` on `main`)
- If removing large binaries or secrets from history, use `git-filter-repo` on a feature branch, then force-push only after team review
- Keep commit messages descriptive: `chore: remove legacy debloat script` rather than `cleanup`
- Tag the pre-cleanup state if the repo is stable:

```bash
git tag before-cleanup-$(date +%Y%m%d)
```

## Validation After Cleanup

### Structural Validation

- [ ] `git status` shows only intended changes
- [ ] No orphaned files referenced in `install.conf.yaml` or `AGENTS.md`
- [ ] All `Scripts/**/*.ps1` still pass `Invoke-ScriptAnalyzer`
- [ ] All markdown files render without broken links

### Functional Validation

- [ ] Bootstrap scripts (`bootstrap.ps1`, `Setup-Dotfiles.ps1`) still execute without error
- [ ] `install.conf.yaml` paths resolve
- [ ] `Scripts/auto/autounattend.xml` loads as valid XML
- [ ] Any moved tests still run with `Invoke-Pester`

### Diff Review

Before committing, review the full diff:

```bash
git diff --stat
git diff --name-only
```

Ensure no accidental deletions of tracked configs or active scripts.

## Invariants

- Do not delete code that has active callers unless you also refactor the callers
- Do not delete tests unless the tested code is also deleted
- Do not delete `AGENTS.md`, `README.md`, or `install.conf.yaml`
- Preserve native file formatting (JSON, YAML, REG) — do not re-serialize for cosmetics
- When in doubt, move to an `archive/` folder instead of deleting

## Related

- `windows-dotfiles` — repo-specific layout rules for Ven0m0/Win
- `validation.md` — running the correct checks after cleanup
