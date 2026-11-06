#!/usr/bin/env python3
"""Rust quality gate: fmt, clippy (with --fix) on every cargo feature set, tests, rustdoc,
rust-analyzer diagnostics and unused-dependency check. Prints one line per step and the
first error lines of each failure, so the output stays small.

Usage: rust_check.py [PATH] [--fix] [--matrix each|all|default] [--stages ...]
Exit code 1 if any step FAILs; ENV (missing system library / toolchain part) does not fail.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

ALL_STAGES = ["fmt", "clippy", "test", "doc", "ra", "deps"]

# Failures caused by the machine, not the code: a missing system library, linker or toolchain part.
ENV_RE = re.compile(
    r"LNK1181|cannot find -l|could not find system library|pkg-config|unable to find library"
    r"|linker `[^`]+` not found|failed to run custom build command for `[\w-]+-sys"
    r"|is not installed for the toolchain|no such command: `(clippy|fmt)`",
    re.IGNORECASE,
)
# One-line diagnostics from --message-format=short, test failures, fmt diffs.
KEEP_RE = re.compile(
    r"^\S.*:\d+:\d+: (error|warning)|^error(\[\w+\])?: (?!could not (compile|document)|aborting)"
    r"|^test .* FAILED|panicked at|^---- .* stdout ----|^Diff in |^\s+unused|^failures:"
)
NOISE_RE = re.compile(
    r"^warning: (build failed|\d+ warnings? emitted)|generated \d+ warnings?"
)


def run(cmd, cwd, env=None):
    start = time.time()
    merged = {**os.environ, **(env or {})}
    try:
        proc = subprocess.run(
            cmd,
            cwd=cwd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            env=merged,
            check=False,
        )
    except FileNotFoundError as e:
        return 127, str(e), 0.0
    return proc.returncode, proc.stdout + "\n" + proc.stderr, time.time() - start


LOC_RE = re.compile(r"^(?P<loc>\S.*?:\d+:\d+): (?P<msg>(error|warning).*)$")


def excerpt(output, limit):
    """Kept lines in order; diagnostics with the same message collapse into the first location plus a count."""
    groups = {}  # key -> [first line, count]
    for line in output.splitlines():
        line = line.rstrip()
        if not KEEP_RE.search(line) or NOISE_RE.search(line):
            continue
        m = LOC_RE.match(line)
        key = m["msg"] if m else line
        if key in groups:
            groups[key][1] += 1
        else:
            groups[key] = [line, 1]
    lines = [
        f"    {first}" + (f"  (+{n - 1} more like this)" if n > 1 else "")
        for first, n in groups.values()
    ]
    if not lines:  # unknown failure shape: show the tail
        lines = ["    " + l for l in output.strip().splitlines()[-8:]]
    more = len(lines) - limit
    return lines[:limit] + ([f"    ... {more} more"] if more > 0 else [])


class Report:
    def __init__(self, limit):
        self.limit, self.failed, self.rows = limit, False, []

    def add(self, name, code, output, secs, ok_codes=(0,)):
        if code in ok_codes:
            status = "PASS"
        elif ENV_RE.search(output):
            status = "ENV"
        else:
            status = "FAIL"
            self.failed = True
        print(f"{status:4} {secs:6.1f}s  {name}", flush=True)
        if status != "PASS":
            detail = (
                excerpt(output, self.limit) if status == "FAIL" else excerpt_env(output)
            )
            print("\n".join(detail), flush=True)
        self.rows.append((name, status))
        return status

    def note(self, status, name, lines=()):
        print(f"{status:4}          {name}", flush=True)
        for line in lines:
            print("    " + line, flush=True)


def excerpt_env(output):
    hit = next((l for l in output.splitlines() if ENV_RE.search(l)), "")
    return [f"    environment, not code: {hit.strip()[:200]}"]


def feature_sets(root, matrix, skip, locked):
    """[(label, cargo args)]: default, no-default, each feature, all features, per workspace package."""
    sets = [("default features", ["--workspace"])]
    if matrix == "default":
        return sets
    code, out, _ = run(
        ["cargo", "metadata", "--no-deps", "--format-version", "1", *locked], root
    )
    if code != 0:
        print("WARN  cargo metadata failed; checking default features only", flush=True)
        return sets
    meta = json.loads(out[: out.rfind("}") + 1])
    members = set(meta["workspace_members"])
    pkgs = [p for p in meta["packages"] if p["id"] in members]
    for pkg in pkgs:
        feats = sorted(f for f in pkg["features"] if f != "default" and f not in skip)
        if not feats and not pkg["features"].get("default"):
            continue
        sel = ["-p", pkg["name"]]
        tag = f"{pkg['name']}: " if len(pkgs) > 1 else ""
        if pkg["features"].get("default"):
            sets.append(
                (f"{tag}--no-default-features", sel + ["--no-default-features"])
            )
        if matrix == "each":
            sets += [(f"{tag}--features {f}", sel + ["--features", f]) for f in feats]
        if feats:
            all_args = ["--features", ",".join(feats)] if skip else ["--all-features"]
            sets.append(
                (
                    f"{tag}all features" + (" (minus skipped)" if skip else ""),
                    sel + all_args,
                )
            )
    return sets


RA_LINE = re.compile(
    r"file (?P<file>.+?): (?P<sev>\w+) (?P<kind>\w+)\(\"(?P<code>[^\"]+)\".*?LineCol \{ line: (?P<line>\d+), "
    r"col: (?P<col>\d+) \} to LineCol \{[^}]*\}: (?P<msg>.*)$"
)


def rust_analyzer(root, report):
    ra = shutil.which("rust-analyzer")
    if not ra:
        report.note(
            "SKIP",
            "rust-analyzer diagnostics (rust-analyzer not on PATH; `rustup component add rust-analyzer`)",
        )
        return
    _, out, secs = run([ra, "diagnostics", "."], root)
    hints, rustc_dupes = [], 0
    for line in out.splitlines():
        m = RA_LINE.search(line)
        if not m or m["code"] == "inactive_code":
            continue
        # Rustc* kinds mirror rustc; rust-analyzer sees only default features and cannot infer through
        # some macros/traits, so these are mostly false positives that cargo already rules on.
        if m["kind"].startswith("Rustc"):
            rustc_dupes += 1
            continue
        path = os.path.relpath(m["file"], root)
        hints.append(
            f"{path}:{int(m['line']) + 1}:{int(m['col']) + 1}: {m['sev']} {m['code']}: {m['msg']}"
        )
    status = "HINT" if hints else "PASS"
    print(
        f"{status:4} {secs:6.1f}s  rust-analyzer diagnostics ({len(hints)} RA lints, "
        f"{rustc_dupes} rustc-mirror diagnostics ignored)",
        flush=True,
    )
    for h in hints[: report.limit * 2]:
        print("    " + h, flush=True)
    if len(hints) > report.limit * 2:
        print(f"    ... {len(hints) - report.limit * 2} more", flush=True)


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("path", nargs="?", default=".")
    ap.add_argument(
        "--fix",
        action="store_true",
        help="apply cargo fmt and clippy --fix before checking",
    )
    ap.add_argument(
        "--matrix",
        choices=["each", "all", "default"],
        default="each",
        help="each: default, no-default, every feature, all (default); all: skip per-feature sets",
    )
    ap.add_argument(
        "--stages", default=",".join(ALL_STAGES), help=f"comma list from {ALL_STAGES}"
    )
    ap.add_argument(
        "--skip-feature",
        action="append",
        default=[],
        help="feature to leave out (repeatable)",
    )
    ap.add_argument(
        "--no-locked",
        action="store_true",
        help="do not pass --locked even if Cargo.lock exists",
    )
    ap.add_argument(
        "--max-lines", type=int, default=20, help="error lines shown per failing step"
    )
    args = ap.parse_args()

    root = Path(args.path).resolve()
    if not (root / "Cargo.toml").exists():
        sys.exit(f"no Cargo.toml in {root}")
    stages = [s.strip() for s in args.stages.split(",") if s.strip()]
    unknown = set(stages) - set(ALL_STAGES)
    if unknown:
        sys.exit(f"unknown stage(s): {', '.join(sorted(unknown))}")
    locked = (
        [] if args.no_locked or not (root / "Cargo.lock").exists() else ["--locked"]
    )
    report = Report(args.max_lines)
    sets = feature_sets(root, args.matrix, set(args.skip_feature), locked)
    print(
        f"# {root.name}: {len(sets)} feature set(s): " + "; ".join(l for l, _ in sets),
        flush=True,
    )

    if args.fix:
        # cargo's built-in git library cannot open some repos (reftable ref storage, newer extensions) and
        # then reports "no VCS found"; trust the git CLI instead. --allow-dirty already skips the dirty check.
        in_git = run(["git", "rev-parse", "--is-inside-work-tree"], root)[0] == 0
        report.add("fix: cargo fmt --all", *run(["cargo", "fmt", "--all"], root))
        for label, sel in sets:
            cmd = [
                "cargo",
                "clippy",
                "--fix",
                "--allow-dirty",
                "--allow-staged",
                *(["--allow-no-vcs"] if in_git else []),
                "--all-targets",
                *locked,
                *sel,
            ]
            report.add(f"fix: clippy --fix [{label}]", *run(cmd, root))
        report.add(
            "fix: cargo fmt --all (after fixes)", *run(["cargo", "fmt", "--all"], root)
        )

    if "fmt" in stages:
        report.add(
            "cargo fmt --check", *run(["cargo", "fmt", "--all", "--", "--check"], root)
        )
    env_sets = set()
    if "clippy" in stages:
        for label, sel in sets:
            cmd = [
                "cargo",
                "clippy",
                "--all-targets",
                "--message-format=short",
                *locked,
                *sel,
                "--",
                "-D",
                "warnings",
            ]
            if report.add(f"clippy -D warnings [{label}]", *run(cmd, root)) == "ENV":
                env_sets.add(label)
    test_sets = [
        s for s in sets if s[0] == "default features" or s[0].endswith("all features")
    ]
    if "test" in stages:
        for label, sel in test_sets:
            if label in env_sets:
                report.note(
                    "ENV",
                    f"cargo test [{label}] (skipped: does not build on this machine)",
                )
                continue
            report.add(
                f"cargo test [{label}]", *run(["cargo", "test", *locked, *sel], root)
            )
    if "doc" in stages:
        doc_env = {"RUSTDOCFLAGS": "-D warnings"}
        for label, sel in test_sets:
            if label in env_sets:
                continue
            cmd = ["cargo", "doc", "--no-deps", "--message-format=short", *locked, *sel]
            report.add(f"cargo doc -D warnings [{label}]", *run(cmd, root, doc_env))
    if "ra" in stages:
        rust_analyzer(root, report)
    if "deps" in stages:
        if shutil.which("cargo-machete"):
            report.add(
                "cargo machete (unused dependencies)", *run(["cargo", "machete"], root)
            )
        else:
            report.note(
                "SKIP", "cargo machete (not installed: `cargo install cargo-machete`)"
            )

    fails = [n for n, s in report.rows if s == "FAIL"]
    print(
        f"# result: {'FAIL' if fails else 'PASS'} ({len(fails)} failing step(s))",
        flush=True,
    )
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
