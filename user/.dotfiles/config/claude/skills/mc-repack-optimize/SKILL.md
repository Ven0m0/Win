---
name: mc-repack-optimize
description: >
  Shrinks a PrismLauncher instance's mods (optionally resourcepacks/shaderpacks) with the mc-repack CLI
  (https://github.com/szeweq/mc-repack): minifies JSON/TOML, re-optimizes PNG/JPEG/OGG, recompresses NBT,
  strips BOMs and junk files, recompresses jar entries, without touching mod behavior. Use to optimize,
  shrink, compress, or speed up loading of mods/modpacks, or when mc-repack is named. Also on "make my
  modpack smaller", "reduce mod jar sizes", "why is this instance so bloated". Backs up originals first.
disable-model-invocation: true
allowed-tools: Read Write Edit Grep Glob Bash PowerShell AskUserQuestion
metadata:
  version: "1.0.0"
  category: "workflow"
  tags: "minecraft, prismlauncher, mc-repack, optimization"
---

# mc-repack: optimize a PrismLauncher instance's mods

mc-repack re-packs `.jar`/`.zip` files: minifies JSON/TOML, re-optimizes PNG/JPEG/OGG, recompresses NBT, strips BOM/comments and editor junk (`.psd`, `.blend`), and picks stored-vs-deflated per entry. It never touches `.class` files or mod logic. Typical result: 5-15% smaller per jar.

## 1. Check the binary

```powershell
mc-repack --version
```

If missing, stop and tell the user to install it (`cargo install mc-repack`, or the release zip from https://github.com/szeweq/mc-repack/releases/latest placed on PATH). Do not auto-install.

## 2. Get the target path

The user supplies either the `mods` folder or the instance root (`%APPDATA%\PrismLauncher\instances\<name>`); the script resolves `.minecraft\mods`, `minecraft\mods` (old MultiMC), or `mods` under a root. Do not scan `instances\` to guess one.

## 3. Run the script

It resolves the mods folder, backs up originals to a timestamped `mods-backup-<stamp>` sibling, runs `mc-repack jars` into a temp dir with a CSV report, and only then copies the jars over `mods\`. It never deletes the backup.

```powershell
pwsh -NoProfile -File "$HOME\.claude\skills\mc-repack-optimize\scripts\repack-mods.ps1" -Path "<instance or mods folder>" -InformationAction Continue
```

`-InformationAction Continue` is required to print the size summary (written to the Information stream); add `-Verbose` for the step log. Pass these only when the user asks:

- `-Zopfli <1-255>`: smaller output, much slower (iteration count).
- `-KeepDirs`: keep jar directory entries (a few mods enumerate them at runtime).
- `-Blacklist`: also apply mc-repack's built-in junk-file blacklist.
- `-Config <path>`: use a specific `mc-repack.toml`.
- `-WhatIf`: dry run, resolves the folder and counts jars without backup or repack.

Report the before/after summary in plain terms (MB saved, % reduction), not just "done".

## 4. If something looks wrong

- mc-repack exits non-zero: the script throws before touching `mods\`; originals are intact.
- Instance will not launch or one mod misbehaves: restore that jar (or the folder) from `mods-backup-<stamp>`. Do not hand-debug mc-repack output.
- A mod that fails only after repacking, with no other error, probably self-verifies its jar hash (rare). Restore it and leave it unrepacked.

## Tuning (only on request)

mc-repack reads `mc-repack.toml` from the mods folder (or `-c <path>`). `mc-repack check --config <mods-folder>` writes defaults or validates the existing file. Defaults suit routine use.

```toml
[json]
remove_underscored = true   # drop "_comment"-style keys

[toml]
strip_strings = true        # strip whitespace inside string values

[jar]
keep_dirs = false           # persisted -KeepDirs
use_zopfli = false

[nbt]
use_zopfli = false

[png]
use_zopfli = true

blacklist = []              # extra filenames/globs to drop from repacked jars
```

## Scope

Targets `mods\` by default. `resourcepacks\` and `shaderpacks\` repack the same way (same script, different `-Path`) and gain proportionally more; offer it only on request. Never repack `versions\`, `libraries\`, or the game client jar: PrismLauncher manages and verifies them.
