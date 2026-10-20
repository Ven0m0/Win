---
name: merge-to-main
description: Commit local changes, sync with GitHub, and push to main. Use for "merge my changes", "push to remote", "commit and push", "merge into main", "sync local changes", or any request to integrate local or branch work into main and push.
---

# Merge to Main

"local" = this machine; "remote" / "GitHub" = `origin`.

## 1. Assess

```bash
rtk git status
rtk git branch -a
rtk git log --oneline -5
rtk git remote -v
```

Note the current branch, staged vs unstaged files, and whether an `upstream` remote exists (fork). No `upstream`: skip step 4.

## 2. Branch off main if needed

- On `main` with local changes: `rtk git checkout -b feature/<3-5-word-kebab-name>`, named from the content.
- Already on a feature branch: commit there.
- Feature branch already fully committed: skip to step 4 or 5.

## 3. Commit

One-line message: `rtk git commit -m "<imperative summary, under 72 chars>"`.
Multi-line message: write it to a temp file and use `rtk git commit -F <file>` (no `$(cat <<EOF ...)`).

Never use `--no-verify`. Fix the hook, re-stage, retry:

| Hook | Symptom | Fix |
|------|---------|-----|
| `check-shebang-scripts-are-executable` | shebang file not executable | `git add --chmod=+x <file>` |
| `trailing-whitespace` | hook auto-fixed files | re-stage modified files |
| `py-psscriptanalyzer Format` | formatter fixed PS files | re-stage modified files |
| `biome check` exits 1 "no files processed" | staged JSON is in biome's ignore list | add `--no-errors-on-unmatched` to the `entry:` in `.pre-commit-config.yaml`, re-stage |
| `ruff` | lint errors | `uv run ruff check --fix src/ tests/ scripts/`, re-stage |
| `ruff-format` | formatting | `uv run ruff format src/ tests/ scripts/`, re-stage |

## 4. Sync with upstream (forks only)

```bash
rtk git checkout main
rtk git fetch upstream
rtk git pull --autostash upstream main
```

`--autostash` re-applies uncommitted changes after the merge. If that fails: `git stash pop`, resolve by hand. Conflicts: upstream owns auto-generated files; keep local changes for code and config. Then `git add <files> && git merge --continue`.

## 5. Sync with origin

```bash
rtk git checkout main
rtk git pull --rebase --autostash origin main
```

## 6. Merge the feature branch

```bash
rtk git merge --ff-only feature/<branch>
```

If histories diverged: `rtk git merge feature/<branch>`, resolve conflicts, `git merge --continue`.

## 7. Push

```bash
rtk git push origin main
```

Rejected (GitHub has newer commits): repeat step 5, push again.

## 8. Clean up

```bash
rtk git branch -d feature/<branch>
rtk git push origin --delete feature/<branch>
```

## 9. Leftover workflow files

Files changed by the workflow itself (`AGENTS.md`, configs) are not on the feature branch. Commit them on main: `rtk git add <files>`, `rtk git commit -m "<message>"`, `rtk git push origin main`.
