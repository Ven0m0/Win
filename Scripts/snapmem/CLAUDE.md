# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single-file Python script (`snap-mem.py`) that downloads a user's Snapchat "Memories" from the `memories_history.json` export Snapchat provides on request. No `pyproject.toml`, no build system — dependencies are declared inline via PEP 723 script metadata (the `# /// script` block at the top of `snap-mem.py`) and resolved automatically by `uv run`.

## Commands

Run the script:
```bash
uv run snap-mem.py --json /path/memories_history.json --out /path/out
uv run snap-mem.py   # interactive curses TUI if run from a TTY with no args
```

Run tests (unittest, no test runner dependency):
```bash
uv run test_snap_mem.py
uv run python -m unittest test_snap_mem.TestSnapMem.test_build_base_name_valid   # single test
```

Lint / type-check (no project config needed beyond `ruff.toml` and `pyrightconfig.json`):
```bash
uvx ruff check snap-mem.py test_snap_mem.py
uvx basedpyright
uvx ty check
```

`uv run --script` resolves the inline dependencies into a cached environment, not a local `.venv`, so basedpyright/ty can't see `exif`/`windows-curses` out of the box. One-time setup for editor tooling:
```bash
uv venv
uv pip install --python .venv windows-curses exif
```

`test_snap_mem.py` loads `snap-mem.py` via `importlib` (module name `snap_mem`) because the filename contains a hyphen and can't be imported normally — keep this pattern in mind if adding new test files.

**Windows caveat:** `snap-mem.py` does a top-level `import curses`, which is not part of stdlib on Windows (no `_curses` module). The inline script metadata declares `windows-curses; sys_platform == 'win32'` as a dependency, so `uv run snap-mem.py` installs it automatically on Windows — don't invoke the script with a bare `python`/`py` on Windows, `uv run` is what resolves this dependency.

## Architecture

Everything lives in `snap-mem.py`. The flow through `main()`:

1. **Input resolution** — `--json`/`--out` flags, or if omitted and running in a TTY, `tui_select_path()` drives a small curses file/dir picker (`mode="file"|"dir"`).
2. **Parsing** — `load_items()` reads the `"Saved Media"` array from the JSON export into a list of `Item` (frozen dataclass: `date_str`, `url`, `is_video`, `latitude`, `longitude` parsed from the `"Location"` field when present), filtered by `--type`.
3. **Naming** — `build_base_name()` turns each item's `Date` string (format `%Y-%m-%d %H:%M:%S UTC`) into a sortable filename base; duplicate timestamps get a `-dup-N` suffix, and `make_unique_name()` (thread-lock guarded) resolves filename collisions against the `existing` set of files already in the output directory.
4. **Download** — each item is downloaded via `download_with_retries()` (exponential backoff, stdlib `urllib`) to a `.part` file, then atomically renamed into place (`download_to_path()`). Snapchat memory downloads are always fetched as a zip. `format_progress_line()` prints an `index/total` line per download.
5. **Extraction** — `extract_zip_atomically()` unzips captioned memories, splitting the zip's flat member list into `caption.png` / `image.jpg` / `video.mp4`, renamed via the same `make_unique_name()` collision scheme, then deletes the source zip. If the downloaded file isn't actually a zip (`zipfile.is_zipfile()` check), it's treated as a plain image/video and renamed directly. Every extracted/renamed file gets its mtime set to the capture timestamp via `os.utime()` (`parse_capture_epoch()`).
6. **EXIF geotagging** (`--exif`) — `write_exif_geotag()` embeds the capture timestamp and, when Snapchat recorded a location, GPS coordinates (converted to DMS via `_decimal_to_dms()`) into downloaded JPEG files. No-op for video/caption files.
7. **Concurrency** — downloads run in parallel via `ThreadPoolExecutor` (`--workers`, default 4); the `existing` filename set and `seen_bases` dedup dict are shared across the pool and protected by `threading.Lock`.

Key invariant: all writes to the output directory go through the atomic `.part`-then-`os.replace` pattern, and all filename collision resolution goes through `make_unique_name()` — don't bypass either when touching the download/extract paths.

`--dry-run` short-circuits before any network activity, printing the resolved `(base_name, url)` pairs. `--skip-existing` filters `download_tasks` against filename prefixes already present in `--out` before downloads start.
