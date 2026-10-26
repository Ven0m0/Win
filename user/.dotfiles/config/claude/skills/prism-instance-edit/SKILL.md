---
name: prism-instance-edit
description: Safely edit PrismLauncher config (instance.cfg, prismlauncher.cfg) - checks the launcher is closed, backs up, edits, and re-reads to confirm the change survived. Use whenever editing a PrismLauncher instance's JVM args, memory, Java path, or other launcher settings. Complements mc-jvm-tune, which decides what to change.
---

# PrismLauncher config edit

PrismLauncher keeps its configs in memory and rewrites `instance.cfg` and `prismlauncher.cfg` on game exit or launcher close. Edits made while it runs are silently lost.

Config locations:
- Global: `%APPDATA%\PrismLauncher\prismlauncher.cfg`
- Instance: `%APPDATA%\PrismLauncher\instances\<name>\instance.cfg`

## Steps, in order

1. Check the launcher is closed:
   ```powershell
   Get-Process -Name prismlauncher -ErrorAction SilentlyContinue
   ```
   A process is running: stop and ask the user to close it. Do not kill it yourself.
2. Back up the file next to itself as `<file>.bak-<yyyy-MM-dd-HHmm>`.
3. Make the edit. Keep the INI layout and line endings; change only the keys requested. A per-instance override needs `OverrideJavaArgs=true` (or the matching `Override*` key) alongside the value.
4. Re-read the file and confirm the keys hold the new values.
5. Tell the user to start the launcher only after this. If the change disappears later, the launcher was open during the edit.

## Gotchas

- Do not edit while a game is running either; exit rewrites the file.
- Tuning decisions (GC, heap sizes) belong to the `mc-jvm-tune` skill; this skill only covers the safe write.
- Instance notes live in the Obsidian vault under `Projects/` (for example `prismlauncher-1.21.11.md`).
