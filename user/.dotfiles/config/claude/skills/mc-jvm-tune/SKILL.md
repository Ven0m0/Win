---
name: mc-jvm-tune
description: >
  Reads a PrismLauncher Minecraft instance's logs (latest.log, stderr_stream.log, crash-reports,
  hs_err, GC/safepoint/JIT logs, JFR) to find performance problems, separates JVM causes from
  mod/render causes, audits instance.cfg JvmArgs, and proposes an evidence-backed flag diff.
  Use for lag, stutter, frame spikes, bad 1% lows, slow startup, crashes or OOM, jvm-gc/.jfr logs,
  JvmArgs, G1, GraalVM flags, or "why is my modpack slow", even without naming a log. Edits
  instance.cfg only after explicit approval, with a backup.
disable-model-invocation: true
allowed-tools: Read Edit Grep Glob Bash PowerShell AskUserQuestion
metadata:
  version: "1.0.0"
  category: "workflow"
  tags: "minecraft, prismlauncher, jvm, gc, jfr, performance"
---

# mc-jvm-tune: find Minecraft performance problems in logs, then tune JvmArgs

`$ARGUMENTS` is the instance directory (the folder holding `instance.cfg`), for example
`C:\Users\<user>\AppData\Roaming\PrismLauncher\instances\1.21.11`. If it is empty, ask which
instance. Never scan for or guess one: a wrong instance means tuning flags against another pack's logs.
If the user names several instances, run the script once per instance and report each separately.

Keep raw logs out of the conversation. A `latest.log` runs to hundreds of KB and a JFR to tens of MB, and
every byte read stays in context for the rest of the session. The script below reduces them to about
80 lines; when you must look closer, filter at the source (`rg -n -m 20 "<pattern>" <file>`) instead of
reading the file.

Constraints from past sessions live in `references/flag-rules.md` (stay on G1, keep `-Djdk.graal.*`,
no mod removal, evidence-to-flag table, inert flag list, logging presets). Read it before step 4.

## Steps

1. **Context.** If the Obsidian vault exists (`$env:USERPROFILE\Nextcloud\obsidian-vault`), read
   `Projects/prismlauncher-1.21.11.md` and `Memory/*jvm*` / `Memory/*stutter*` notes for earlier decisions.
   Do not undo a past decision without new evidence.

2. **Analyze.** Run the bundled script (read-only):

   ```powershell
   & "$HOME\.claude\skills\mc-jvm-tune\scripts\Analyze-McJvm.ps1" -Instance "<instance dir>"
   ```

   It prints Config, latest.log, stderr_stream.log, Crashes, GC, Safepoints, JIT, and JFR sections,
   skipping any log that does not exist. Options: `-Session <name fragment|latest>` to pick a run (the JVM
   keeps the previous GC log as `jvm-gc.log.0`, so `-Session .0` selects it), `-SteadyStateSec 200` to change
   the startup cutoff, `-NoJfr` to skip `jfr.exe`. Running it beats hand-written regexes: the pause regex
   bug in the pitfalls below cost two earlier sessions a wrong answer.

3. **No GC log?** Then GC and flag tuning have nothing to stand on. Report whatever the other sections
   found (crashes, can't-keep-up, slow loads). For flags, propose the "Normal" logging preset from
   `references/flag-rules.md` (or "Diagnose" if the user wants JIT/JFR detail) as the only change and
   explain its cost. Tuning without measurements is guessing.

4. **Interpret.** Decide the layer first, because the fix differs:
   - Crash or OOM in Crashes: heap, a mod, or a driver; flags rarely help, so report it before anything else.
   - `Can't keep up` or slow-operation lines: integrated server or mod load, not the JVM.
   - GC steady-state pauses over frame time, Full GC, evacuation failures: JVM, use the evidence table.
   - Everything clean but the user still sees stutter: render side (Sodium, shaders, render distance).
   Compare steady state (after the startup cutoff) with startup/world-load: long pauses during world load are
   normal and rarely the cause of in-game stutter. Match each JVM finding to a row of the evidence table.
   If hot methods point at Sodium/Nvidium/C2ME, say "not a JVM issue" and name the mod-side lever. Mark
   anything not proven by the logs as an inference.

5. **Report.** Use this layout, short and with numbers:
   - Environment (CPU, GPU, JDK, heap, mod count)
   - Findings ranked by expected frame-time impact, each with its evidence line
   - Not a JVM issue (if any): crashes, mod/render causes, with the lever to try
   - Proposed JvmArgs diff, only if a JVM finding exists: exact tokens removed, replaced, added, one reason each
   - Unverified / inferences, and what was not tested

6. **Validate** the candidate args before offering them:

   ```powershell
   $candidate = '<candidate JvmArgs string>'
   & "$HOME\.claude\skills\mc-jvm-tune\scripts\Analyze-McJvm.ps1" -Instance "<dir>" -ValidateArgs $candidate
   ```

   Pass the string through a variable and call with `&`: `pwsh -File ... -ValidateArgs "-XX:..."` fails
   because the value starts with `-` and is parsed as a parameter. The check runs the instance's own `java`
   strictly (no `IgnoreUnrecognizedVMOptions`, no `-Xlog:disable`, and JFR/log-file/PreTouch flags dropped so
   it writes nothing) and lists unrecognized, obsolete, or ignored options.

7. **Apply only after the user says yes.** Then:
   1. Check that PrismLauncher and the instance's `javaw` are closed (Prism rewrites `instance.cfg` when
      the game exits and would undo the edit): `Get-Process | ? ProcessName -match 'prismlauncher|javaw'`.
      `SteelSeriesPrism` is unrelated. If `javaw` runs, ask the user to quit the game normally, which also
      lets JFR write `dumponexit`.
   2. Back up: copy `instance.cfg` to `instance.cfg.bak-<yyyy-MM-dd>`.
   3. Edit only the `JvmArgs="..."` line, keeping it one line with its quotes.
   4. Re-read the line and confirm the removed tokens are gone, the new ones present, and the file still
      has exactly one `JvmArgs=` line.
   If `OverrideJavaArgs=false`, the instance uses the global `prismlauncher.cfg` args; say so and ask which to edit.

8. **Close the loop.** Give the user concrete checks for the next run (for example "no `threshold: 0B`
   lines", "steady-state p99 under 12 ms", "no new `.jfr`"), and the baseline numbers to compare against.
   Write the decision and its reason to the vault as a `Memory/` note.

## Pitfalls seen in earlier sessions

- A pause regex of `Pause [^0-9]*?` silently drops `G1 Evacuation Pause` (the `1` is a digit) and
  under-reports total pause 4x. Use `Pause .*?`. The script already does.
- `rg`/`grep` exit 1 means "no match", not failure. Flags placed after `--` are treated as file names.
- `rtk` truncates long output; read the tee log it names, or use `rtk proxy <cmd>` for raw output.
  `rtk read` has no line-range flags (use `-m` / `--tail-lines`).
- PowerShell: `Measure-Object -Average`, not `-avg`; wrap regexes containing `"` in single quotes;
  take `Substring` lengths from the same string you cut.
- `jfr view` has no `safepoint-latency`; use `safepoints`, `gc-pauses`, `hot-methods`,
  `longest-compilations`, `deoptimizations-by-reason`, `thread-cpu-load`.
- A running JVM keeps its old flags until restart. Live flags: `Get-CimInstance Win32_Process -Filter "Name='javaw.exe'"`.
- Prism keeps the username off the `javaw` command line, so map a process to an instance by its `-Djava.library.path` or `--gameDir`.

## Scope

Reads logs, crash reports and `instance.cfg`; changes only the `JvmArgs` line, and only after approval. It does not
touch mods, mod configs, `options.txt`, or the global `prismlauncher.cfg` unless the user asks for that file by name.
The skill keeps its original name `mc-jvm-tune` so existing references and evals still resolve.
