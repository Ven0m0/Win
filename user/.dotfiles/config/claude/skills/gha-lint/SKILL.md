---
name: gha-lint
description: >
  Lint, validate, and fix GitHub Actions workflows and composite actions with actionlint, ghalint, and
  action-validator, installed through mise. Use whenever the user wants to lint, validate, audit, harden, or
  fix files under .github/workflows or .github/actions, mentions actionlint, ghalint, action-validator,
  "workflow warnings", "persist-credentials", "job permissions", "timeout-minutes", or "stale path filters",
  or asks to clean up CI workflow errors, even if they do not name a tool.
metadata:
  category: "ci"
  version: "1.0.0"
---

# gha-lint

Runs three complementary linters over every workflow and composite action, then fixes what they report.
Each catches things the others miss: actionlint checks syntax, expressions and embedded shell; ghalint
enforces hardening policy; action-validator checks the JSON schema and path-filter globs.

## 1. Install through mise

Add to the global mise config (or the tracked dotfiles copy) so the tools persist:

```toml
actionlint = "latest"
ghalint = "latest"
# the aqua build of action-validator has no Windows binary; the cargo backend compiles it (~80 s once)
"cargo:action-validator" = "latest"
```

Check the target file first (`mise config ls`); a repo's tracked mise config and the global one can differ,
so edit each rather than copying one over the other. `mise exec <tool>@latest -- ...` also works without
touching any config, which is what the bundled script uses.

## 2. Run all three

```powershell
pwsh -NoProfile -File <skill-dir>/scripts/check-workflows.ps1 -Root <repo-root>
```

It prints one PASS/FAIL line per check and exits 1 on any finding. Equivalent manual commands, run from
the repo root (ghalint reads `.ghalint.yaml` from there):

- `mise exec actionlint@latest -- actionlint -oneline` (the default output is long multi-line snippets)
- `mise exec ghalint@latest -- ghalint run`
- `mise exec cargo:action-validator@latest -- action-validator <file>` once per file, including
  `.github/actions/*/action.yml`; it accepts only one path per call

actionlint only works inside a git repository (it fails with "no project was found in any parent
directories" otherwise), so run it against a real checkout or `git init` a scratch dir first.
Treat only exit codes as evidence. actionlint prints nothing when clean, so empty output alone is not proof.

## 3. Fix findings

| Finding | Fix |
| --- | --- |
| ghalint 013 `checkout_persist_credentials_should_be_false` | Add `persist-credentials: false` under `with:` of every `actions/checkout` step; if a `with:` exists, add the key inside it. Public repos can still `git fetch` without credentials; a private repo that pushes needs them kept. |
| ghalint 001 `job_permissions` | Give every job its own `permissions:`. Start from `contents: read`; add only what the steps need (`checks: write` plus `actions: read` for `dorny/test-reporter`, `security-events: write` for SARIF upload). A job that touches no API takes `permissions: {}`. Keep the workflow-level block at `contents: read`. |
| ghalint 012 `job_timeout_minutes_is_required` | Add `timeout-minutes` to the job (5 for a summary job, 10-20 for build/test). |
| ghalint 008 `action_ref_should_be_full_length_commit_sha` | Follow the user's policy. This user never pins to SHAs and always floats to the latest version, so do not run pinact. Suppress the policy in `.ghalint.yaml` (below) and move any patch pins such as `@v5.0.1` to the major tag `@v5`. |
| actionlint shellcheck SC2086 / SC2129 | Quote `"$GITHUB_STEP_SUMMARY"`, group repeated `>> file` redirects into one `{ ...; } >> "$GITHUB_STEP_SUMMARY"`, and pass `${{ needs.x.result }}` and any other context value through `env:` instead of interpolating it into the script (also removes script injection risk). |
| action-validator `glob_not_matched` | A `paths:` filter entry matches no file (for example `**.psm1` in a repo with none, or a deleted workflow). Remove the entry; say so in the summary because it narrows when the workflow triggers. |

Resolve "latest" by asking the source, not memory: `gh api repos/<owner>/<repo>/releases/latest --jq .tag_name`,
then use the floating major tag (`@v7`). Composite actions list their own `uses:` too.

### `.ghalint.yaml` for the no-SHA policy

ghalint requires one exclusion per action name; a bare `policy_name` is rejected with
"action_name is required to exclude ...". Generate one entry per distinct `uses:` owner/repo:

```yaml
# SHA pinning is intentionally not used; actions float on their latest major tag.
excludes:
  - policy_name: action_ref_should_be_full_length_commit_sha
    action_name: actions/checkout
```

A newly added action needs its own entry or ghalint 008 returns.

## 4. Editing safely

- Preserve each file's existing line endings (check for `\r\n` before rewriting) and write UTF-8 without a
  BOM; a blanket rewrite creates whole-file diffs.
- Edit with exact-match replacements or regexes anchored on the step's `uses:` line; checkout steps differ
  in whether they already have a `with:` block (`fetch-depth`, etc.).
- Re-run the script after every batch. Fixing one policy can expose another (a new job needs permissions
  and a timeout too), so loop until all three exit 0.
- Report what changed in terms of behavior: removed path filters and tightened permissions alter when and
  how workflows run.
