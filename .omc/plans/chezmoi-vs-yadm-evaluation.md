# Evaluation: chezmoi vs yadm for Win Dotfiles

**Date:** 2026-03-30
**Verdict: Stay with yadm** (low gain, high migration cost given current usage)

---

## Current yadm Usage Profile

The setup is **minimalist** — yadm functions purely as a git wrapper:

- **Used:** bootstrap script, `yadm add/status/push/pull`
- **NOT used:** alternates (`##hostname`), templates, encryption, yadm hooks
- **205 tracked files** under `user/.dotfiles/config/`
- Bootstrap does `Copy-Item` to destinations (no symlinks — Windows compatibility choice)
- Zero machine-specific yadm features despite supporting multiple machines

---

## Feature Comparison (relevant to this repo)

| Feature | yadm (current) | chezmoi |
|---------|---------------|---------|
| Core model | git wrapper, files live at `$HOME` | Source state → target state (separate dirs) |
| Machine-specific | `##hostname`/`##os` alternates (unused) | Go templates (more powerful) |
| Apply/diff | n/a (files already in place) | `chezmoi diff`, `chezmoi apply --dry-run` |
| Scripts | Manual bootstrap `.yadm/bootstrap` | `run_once_*` / `run_onchange_*` scripts |
| Encryption | `yadm encrypt` (unused) | age, gpg, 1Password, Bitwarden (unused) |
| Windows support | Works (bootstrap uses Copy-Item) | First-class, no symlink issues |
| File naming | Natural paths | `dot_`, `private_`, `executable_` prefixes |
| Active development | Low (maintenance mode) | High (v2.x, frequent releases) |
| Learning curve | git = yadm | Moderate (new mental model) |

---

## Where chezmoi Would Win

1. **`chezmoi apply` replaces the bootstrap** — instead of manually running a copy script, `chezmoi apply` handles all file placement. Run-once scripts replace the winget install phase.
2. **`chezmoi diff`** — see exactly what would change before applying. Currently there's no way to preview drift.
3. **Templates** — if `local.ps1` or `.gitconfig` ever need per-machine values, Go templates handle this cleanly without extra files.
4. **Drift detection** — `chezmoi status` shows files that diverged from source truth. yadm doesn't track this.
5. **Long-term momentum** — chezmoi is actively maintained; yadm is in low-activity maintenance mode.

## Where yadm Wins (for this repo)

1. **Zero migration cost** — it already works; all 205 files are tracked
2. **No mental model shift** — `yadm` = `git`, no new concepts
3. **Scripts/ isn't dotfiles** — chezmoi manages `$HOME` targets; the Scripts/ directory is a regular tools repo that doesn't fit the chezmoi model
4. **Bootstrap is already working** — run_once scripts would replicate existing behavior with more complexity
5. **No pain points** — no alternates needed, no encryption needed, no templating needed

---

## Migration Cost (if you ever switch)

1. Rename all 205 files with chezmoi prefixes (`dot_`, etc.) or use `chezmoi add` one-by-one
2. Convert bootstrap phases → `run_once_*.ps1` scripts
3. Update AGENTS.md, README, and workflow docs
4. Re-learn workflow (`chezmoi cd`, `chezmoi apply`, `chezmoi re-add`)
5. Estimated effort: **2–4 hours** for mechanical migration, plus validation

---

## Acceptance Criteria (if migration were planned)

- [ ] All 205 files reachable via `chezmoi apply` with correct destinations
- [ ] `chezmoi diff` shows zero diff after initial apply on a clean machine
- [ ] Bootstrap phases replaced by `run_once_setup.ps1` scripts
- [ ] `chezmoi apply --dry-run` used in CI to detect drift
- [ ] `local.ps1` and `.gitconfig.local` handled via `.chezmoiignore` or templates
- [ ] Existing beads/git hooks unaffected

---

## Recommendation

**Stay with yadm unless you hit one of these triggers:**

| Trigger | Action |
|---------|--------|
| Need machine-specific config (e.g., work vs home) | Switch to chezmoi (templates are far superior to alternates) |
| Bootstrap drift becomes a maintenance problem | Switch (chezmoi's run_once/run_onchange is cleaner) |
| Secrets management needed | Switch (chezmoi has native 1Password/Bitwarden support) |
| Fresh machine setup — yadm feels painful | Switch opportunistically |
| Just want better `diff`/`status` tooling | Switch (worthwhile alone if starting fresh) |

**Current state:** None of these triggers apply. The setup is simple, working, and the only yadm "feature" in use is `git`. Switching now would be churn with marginal benefit.

---

## ADR

**Decision:** Retain yadm
**Drivers:** No active pain points; migration cost exceeds benefit at current usage level
**Alternatives considered:** chezmoi (evaluated above)
**Why retained:** yadm is already installed, all files tracked, bootstrap works. Zero yadm-specific features in use means zero unique value to migrate away from — but also zero unique value to migrate toward.
**Consequences:** Drift detection and dry-run apply remain unavailable. If machine-specific configs become necessary, yadm alternates are clunkier than chezmoi templates.
**Follow-ups:** Re-evaluate if a second Windows machine is added to the sync pool, or if `local.ps1` overrides grow complex enough to warrant templating.
