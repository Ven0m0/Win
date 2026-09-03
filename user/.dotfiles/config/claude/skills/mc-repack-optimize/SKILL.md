---
name: mc-repack-optimize
description: >
  Shrinks a PrismLauncher instance's mods (and optionally resourcepacks/shaderpacks) using
  the mc-repack CLI (https://github.com/szeweq/mc-repack) - minifies JSON/TOML, re-optimizes
  PNG/JPEG/OGG, recompresses NBT, strips BOMs and junk files, and recompresses jar entries more
  efficiently, all without touching mod behavior. Use whenever the user wants to optimize,
  shrink, compress, deduplicate, or speed up loading of mods/modpacks in a PrismLauncher
  instance, or mentions mc-repack directly. Also trigger on "make my modpack smaller",
  "reduce mod jar sizes", "clean up unoptimized mod assets", or "why is this instance so
  bloated" - even without the tool name. Always backs up originals before touching anything.
disable-model-invocation: true
allowed-tools: Read Write Edit Grep Glob Bash PowerShell AskUserQuestion
metadata:
  version: "1.0.0"
  category: "workflow"
  tags: "minecraft, prismlauncher, mc-repack, optimization"
---

# mc-repack: optimize a PrismLauncher instance's mods

mc-repack re-packs `.jar`/`.zip` files: it minifies JSON/TOML, re-optimizes PNG/JPEG/OGG,
recompresses NBT, strips BOM/comments, drops stray editor junk files (`.psd`, `.blend`, etc.),
and picks the smaller of stored-vs-deflated per entry. It does **not** touch `.class` files or
mod logic - only how the surrounding assets are packed. Real-world results run 5-15% smaller
per jar (see the comparison table in the upstream README).

## 0. Check the binary is installed

```powershell
mc-repack --version
```

If that fails, stop and tell the user to install it - don't auto-install:

```powershell
cargo install mc-repack
# or grab the prebuilt release zip (Windows x86_64):
# https://github.com/szeweq/mc-repack/releases/latest -> mc-repack-x86_64-pc-windows-msvc.zip
# unzip it somewhere on PATH.
```

## 1. Get the target path from the user

Ask for (or use, if already given) a path to either:
- the instance's `mods` folder directly, or
- the instance root (e.g. `%APPDATA%\PrismLauncher\instances\<name>`) - the script below
  resolves `.minecraft\mods`, `minecraft\mods` (old MultiMC layout), or `mods` under it.

Don't scan `%APPDATA%\PrismLauncher\instances` yourself to guess the instance - the user names
the path or instance explicitly.

## 2. Run the bundled script

`scripts/repack-mods.ps1` does the whole safe workflow in one shot: resolve the mods folder,
back up originals to a timestamped `mods-backup-<stamp>` sibling folder, run `mc-repack jars`
into a temp output dir with a CSV report, then copy the optimized jars back over the originals
in `mods\`. It never deletes the backup and never overwrites `mods\` until mc-repack has
already succeeded.

```powershell
pwsh -File scripts/repack-mods.ps1 -Path "C:\path\to\instance-or-mods-folder" -InformationAction Continue
```

`-InformationAction Continue` is what makes the size-savings summary print - the script writes
it to the Information stream, not the console directly. Add `-Verbose` too if you want the
step-by-step resolution/backup log.

Optional flags, pass through only if the user asks for them:
- `-Zopfli <1-255>` - much better compression, much slower (Zopfli iteration count). Fine for a
  one-off "squeeze every byte" pass, overkill for routine use.
- `-KeepDirs` - keep directory entries in the jar (mc-repack drops them by default; some rare
  mods that enumerate jar directory entries at runtime may want this - most don't).
- `-Blacklist` - apply mc-repack's built-in junk-file blacklist in addition to the config file.
- `-Config <path>` - use a specific `mc-repack.toml` instead of the default lookup. See
  "Tuning behavior" below for what goes in it.
- `-WhatIf` - preview (resolves the mods folder, counts jars) without backing up or repacking
  anything. Good for a dry run before the real thing.

The script prints a before/after size summary from the CSV report when it's done. Report that
summary back to the user in plain terms (total MB saved, % reduction) - don't just say "done".

## 3. If something looks wrong

- mc-repack itself failed (non-zero exit): the script throws before touching `mods\` - originals
  are untouched, and a backup still exists from the copy step. Nothing to restore.
- The optimized instance won't launch, or a specific mod misbehaves after repacking: restore
  that mod's jar (or the whole folder) from the `mods-backup-<stamp>` folder the script created,
  then move on - don't try to hand-debug mc-repack's output.
- A vanishingly small number of mods self-verify their own jar hash/signature at runtime (mod
  auth/anti-piracy checks). Repacking changes the jar's exact bytes, so a repacked jar can fail
  that self-check even though nothing meaningful changed. This is rare, but if a specific mod
  refuses to load only after repacking with no other error, that's the likely cause - restore it
  from backup and leave it un-repacked.

## Tuning behavior (optional, only if the user wants to customize)

mc-repack reads `mc-repack.toml` (or `-c <path>`) from the mods folder. Generate a starter one
with `mc-repack check --config <mods-folder>` (writes defaults if none exists, validates if one
does). Defaults are sane for routine use; only hand-edit if asked:

```toml
[json]
remove_underscored = true   # drop "_comment"-style keys some mods use for JSON comments

[toml]
strip_strings = true        # strip whitespace inside TOML string values

[jar]
keep_dirs = false            # same as -KeepDirs above, but persisted
use_zopfli = false

[nbt]
use_zopfli = false

[png]
use_zopfli = true

blacklist = []                # extra filenames/globs to drop entirely from repacked jars
```

## Scope note

This skill targets `mods\` by default because that's what "optimize my instance's mods" means.
`resourcepacks\` and `shaderpacks\` inside the instance are also jar/zip archives mc-repack can
repack the same way (same script, different `-Path`) - offer that only if the user asks, since
resource/shader packs are far more asset-heavy and the win is proportionally larger there too.
Don't repack `versions\`, `libraries\`, or the game client jar itself - those aren't mod content
and PrismLauncher manages/verifies them separately.
