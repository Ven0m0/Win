---
name: rust-check-fix
description: >
  Format, check, lint, test and fix a Rust/cargo project across every cargo feature set, using
  rustfmt, clippy (--fix and -D warnings), cargo test, rustdoc and rust-analyzer diagnostics,
  then fix whatever the tools cannot fix themselves. Use whenever the user asks to clean up,
  lint, validate, check or "fix all warnings" in Rust code, mentions clippy, rustfmt, cargo fmt,
  cargo check, rust-analyzer or feature combinations, wants CI green before a push or PR, or asks
  to "make the Rust code pass", even if they name only one of these tools.
---

# rust-check-fix

Get a Rust project clean on every feature set: formatted, compiling, clippy-clean with
`-D warnings`, tests and doctests passing, rustdoc warning-free, and rust-analyzer's own lints
looked at. Auto-fix first, then fix the rest by hand at the root cause, then prove it with a
clean re-run.

Target: $ARGUMENTS (default: the crate or workspace containing the current directory).

## 0. Look before running

- `git status --short`. Auto-fix rewrites files; if the tree has unrelated edits, say so, so
  the user can tell your changes apart. Never stash or discard their work.
- The project's own definition of "passing" outranks this skill's defaults. Read
  `.github/workflows/*.yml` (or `justfile`, `Makefile`, `xtask`) for the exact cargo commands,
  feature matrix and flags CI uses, plus `rust-toolchain.toml`, `clippy.toml`, `rustfmt.toml`,
  and `[lints]` in `Cargo.toml`. If the project ships its own CI-matrix skill or script, run
  it at the end as well.
- The project's `CLAUDE.md`/`AGENTS.md` may list features that cannot build on this OS (a
  Linux-only system library, say). Pass those with `--skip-feature` instead of chasing them.

## 1. Run the gate

`scripts/rust_check.py` (Python 3, stdlib only) reads every workspace package's features from
`cargo metadata` and runs, in order:

| Stage | Command (per feature set where it applies) |
|-------|---------------------------------------------|
| fix (only with `--fix`) | `cargo fmt --all`, `cargo clippy --fix --allow-dirty --allow-staged --all-targets`, `cargo fmt --all` |
| `fmt` | `cargo fmt --all -- --check` |
| `clippy` | `cargo clippy --all-targets -- -D warnings` (this is also the compile check) |
| `test` | `cargo test` on default and all features (unit, integration and doctests) |
| `doc` | `cargo doc --no-deps` with `RUSTDOCFLAGS=-D warnings` |
| `ra` | `rust-analyzer diagnostics .`, filtered (see section 3) |
| `deps` | `cargo machete` (unused dependencies), if installed |

Feature sets (`--matrix each`, the default): default features, `--no-default-features`,
each feature on its own, and `--all-features`. Features are added on top of the defaults, as a
user enables them. `--locked` is passed when `Cargo.lock` exists, so a stale lockfile shows up
as a failure instead of being rewritten.

```bash
python -I ~/.claude/skills/rust-check-fix/scripts/rust_check.py <crate-or-workspace-dir> --fix
```

- Drop `--fix` when the user asked only to check or review.
- `--matrix all` for projects with many features (it skips the per-feature sets);
  `--stages clippy,test` to re-run part of it; `--skip-feature NAME` (repeatable);
  `--max-lines N` for longer failure excerpts.
- On a large workspace the run takes minutes: start it with `run_in_background`.

Output is one line per step (`PASS`, `FAIL`, `ENV`, `SKIP`, `HINT`) plus the first error lines
of each failure in `file:line:col: error[...]` form, and exit code 1 if anything failed.
`ENV` means the machine, not the code: a missing system library or linker (`LNK1181`,
`cannot find -l...`, a `*-sys` build script, `pkg-config`). Report it and don't edit code to work
around it. Its tests are skipped automatically.

A stage the project's CI does not run is **advisory**, not a gate. Rustdoc with `-D warnings` is
the usual case: a codebase that writes `[EXPERIMENTAL]` or `[0]` in doc comments produces dozens
of "unresolved link" errors. Report those grouped by cause. Fix them only where the fix is small
and clearly right (a broken path to a renamed item, a redundant link target). Rewriting a
project-wide doc convention needs the user's go-ahead. Identical messages are already collapsed
into `first location (+N more like this)`.

## 2. Fix what is left, by hand

Work in this order, because each step's output depends on the one before it: compile errors,
then clippy, then failing tests, then rustdoc, then rust-analyzer lints.

- Fix the cause and keep the diff minimal. One root fix often clears many lines of output.
- Don't silence lints to get to green: no new `#[allow]`, no `-A` flags, no loosening
  `clippy.toml` or `[lints]`. If a lint is wrong for a specific line, use
  `#[expect(clippy::name, reason = "...")]` with a real reason and mention it in the report.
- A clippy suggestion that changes behaviour or public API (signatures, `pub` items, trait
  impls) gets the user's say first. Report it instead of applying it.
- Failing test: find out whether the code or the test is wrong. Don't edit an expected value
  until you know why it differs.
- Leave dependency versions, `Cargo.lock`, the toolchain and the edition alone unless the user
  asked. Don't run `cargo fix --edition` or `--broken-code`.
- Feature-gated code compiles only in its own set, so re-run that set
  (`--stages clippy --matrix each`), not just the default one.

Then re-run the full gate. Repeat until it reports `# result: PASS`. If the same failure
survives two honest attempts, stop and report it with what you tried.

## 3. Reading rust-analyzer output

rust-analyzer adds lints rustc and clippy don't have (`remove-unnecessary-else`,
`unused_mut` in macro-heavy code, `needless_return` variants, unlinked files and so on).
The CLI has quirks, and the script handles them:

- It analyses **default features only** and has no `--features` flag, so it reports
  "unresolved import" errors for any target behind `required-features` or a cfg.
- Its `Rustc*`-kind errors (`E0282`, `E0277` and similar) mirror rustc but come from its own,
  weaker type inference (axum handlers, heavy generics, proc macros). Cargo already ruled on
  real compile errors. The script counts these and drops them, and you should ignore them
  unless cargo reports the same thing.
- `inactive_code` (cfg'd-out code) is dropped.
- It exits non-zero and may print a backtrace whenever it found any error; the script treats
  that as normal.

What remains (`HINT` lines, 1-based `file:line:col`) are style and simplification lints. Apply
them when they simplify the code and match the project's style; they are advice, not a gate.
When you're editing one file and an LSP diagnostics tool is available (for example
`lsp_diagnostics`), use it for quick feedback on that file between full runs.

## 4. Report

```
| Step | Result |
|------|--------|
| fmt / clippy (N feature sets) / test / doc / rust-analyzer / deps | PASS, FAIL or ENV |
```

Then:
- Auto-fixed: the `git diff --stat` summary.
- Fixed by hand: one line per fix.
- Not fixed: what's left and why (ENV, needs the user's say, `#[expect]` added).
- Not run: feature sets you skipped, plus other targets/OSes. `cfg(unix)` code was not compiled
  on Windows and vice versa. Cross-checking needs `rustup target add` and often fails on C
  dependencies, so do it only when asked.

## Extras, only when asked

`cargo hack check --feature-powerset --depth 2` (feature interactions), `cargo audit` or
`cargo deny check` (advisories and licences; needs network), `cargo +nightly udeps`,
`cargo miri test` (UB in `unsafe`), `cargo semver-checks` (library API breaks).
