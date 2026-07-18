---
name: merge-to-main
description: Use when the user wants to commit local changes, sync with GitHub, and push. Triggers on "merge my changes", "push to remote", "commit and push", "merge into main", "sync local changes", "get my changes onto main", or any request to integrate local/branch work into main and push to GitHub.
---

# Merge to Main

Commits local work, syncs with GitHub, pushes up.

**Terminology:** "local" = your machine. "remote" / "GitHub" = origin on GitHub.

## Step 1: Assess state

```bash
rtk git status
rtk git branch -a
rtk git log --oneline -5
rtk git remote -v
```

Note: which branch you're on, what's staged vs unstaged, and what remotes exist.

## Step 2: Check for upstream remote

If the repo is a fork and an `upstream` remote exists, sync it in Step 5.
If there's only `origin`, skip Step 5 and go straight to Step 6.

```bash
rtk git remote -v | grep upstream
```

## Step 3: Branch local changes off main (if needed)

**On `main` with local changes** → create a feature branch so the GitHub sync lands cleanly before the rebase:

```bash
rtk git checkout -b feature/<short-description>
```

Name from content (3-5 words, kebab-case).

**Already on a feature branch** → proceed to commit.

**Feature branch already fully committed** → skip to Step 5 or 6.

## Step 4: Commit

```bash
rtk git commit -m "$(cat <<'EOF'
<short imperative summary under 72 chars>

- <group of related changes>
- <group of related changes>
EOF
)"
```

Do NOT use `--no-verify`. Fix hook failures instead:

| Hook | Symptom | Fix |
|------|---------|-----|
| `check-shebang-scripts-are-executable` | file has shebang but isn't executable | `git add --chmod=+x <file>` then retry |
| `trailing-whitespace` | hook auto-fixed files | re-stage modified files then retry |
| `py-psscriptanalyzer Format` | formatter auto-fixed PS files | re-stage modified files then retry |
| `biome check` exits 1 "no files processed" | staged JSON is in biome's ignore list | add `--no-errors-on-unmatched` to the `entry:` in `.pre-commit-config.yaml`, re-stage |
| `ruff` lint errors | Python lint violations | `uv run ruff check --fix src/ tests/ scripts/` then re-stage |
| `ruff-format` | formatting violations | `uv run ruff format src/ tests/ scripts/` then re-stage |

After each hook auto-fix, re-stage the modified files and retry the commit.

## Step 5: Sync main with upstream (forks only)

Skip if no `upstream` remote — go to Step 6.

```bash
rtk git checkout main
rtk git fetch upstream
rtk git pull --autostash upstream main
```

`--autostash` saves local uncommitted changes, applies the upstream merge, re-applies them. If re-apply fails: `git stash pop` and resolve manually.

Conflict rule of thumb: upstream owns auto-generated files; keep local changes for code and config.

After resolving: `git add <resolved-files> && git merge --continue`

## Step 6: Sync main with GitHub (origin)

Picks up any commits on GitHub that aren't local yet:

```bash
rtk git checkout main
rtk git pull --rebase --autostash origin main
```

## Step 7: Merge feature branch

Prefer fast-forward for a linear history:

```bash
rtk git merge --ff-only feature/<branch-name>
```

If histories have diverged:

```bash
rtk git merge feature/<branch-name>
```

Resolve conflicts, then `git merge --continue`.

## Step 8: Push to GitHub

```bash
rtk git push origin main
```

If rejected (GitHub has commits local doesn't): go back to Step 6, then retry push.

## Step 9: Clean up feature branch

```bash
rtk git branch -d feature/<branch-name>
rtk git push origin --delete feature/<branch-name>
```

## Step 10: Commit any remaining workflow changes

Files modified during the workflow itself (e.g. `AGENTS.md`, config files) won't be on the feature branch. Commit them directly to main:

```bash
rtk git add <files>
rtk git commit -m "<short message>"
rtk git push origin main
```
