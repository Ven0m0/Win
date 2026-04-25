---
name: session-complete
description: Mandatory end-of-session workflow — file issues, run quality gates, push to remote, verify clean state, hand off context.
disable-model-invocation: false
---

# Session Complete

Execute every step below in order. Do not skip steps. Work is NOT complete until `git push` succeeds and `git status` shows clean.

## Step 1 — File Issues for Remaining Work

Review what was worked on. For any unfinished work, bugs found, or follow-up needed:

```bash
bd ready   # check open issues first to avoid duplicates
# then create issues for anything not tracked
```

## Step 2 — Quality Gates (if any code changed)

If PowerShell scripts were modified:

```bash
# Lint changed .ps1 files
pwsh -NoProfile -Command "Get-ChildItem Scripts/*.ps1 | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName }"

# Run Pester tests
pwsh -NoProfile -Command "Invoke-Pester -Path Scripts/ -Output Minimal"
```

If no code changed, skip to Step 3.

## Step 3 — Update Issue Status

```bash
bd ready        # review open issues
# bd close <id> for completed work
# bd update <id> --status in_progress for work continuing next session
```

## Step 4 — Push to Remote (MANDATORY)

```bash
git pull --rebase
bd dolt push 2>/dev/null || true
git push
git status   # MUST show "Your branch is up to date with 'origin/main'"
```

If `git push` fails: resolve the conflict, then retry. Do NOT stop before this succeeds.

## Step 5 — Clean Up

```bash
git stash list          # clear any stashes that are no longer needed
git remote prune origin # prune stale remote-tracking branches
```

## Step 6 — Verify

Confirm all of the following are true before proceeding:
- `git status` shows nothing to commit, up to date with origin
- No uncommitted changes in `Scripts/`, `user/`, `.claude/`
- Quality gates passed (or no code changed)

## Step 7 — Hand Off

Summarize for the next session:
- What was completed this session
- What issues were filed for follow-up
- Any in-progress work and its current state
- Anything the next session should know (blockers, context, decisions made)
