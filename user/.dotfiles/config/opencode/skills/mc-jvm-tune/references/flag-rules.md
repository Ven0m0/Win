# JVM flag rules for Minecraft clients (G1, GraalVM)

Rules the user has set across past sessions. Treat them as constraints, not suggestions.

## User constraints

- Stay on G1. ZGC lowered average FPS on this machine; Shenandoah was never tried. Tune G1 only.
- Keep every `-Djdk.graal.*` flag unless the user agrees to a change. Propose Graal changes only when
  deopt storms show up in the JIT log or JFR, and let the user decide.
- Never remove mods. This skill changes flags and config only.
- One change at a time when the user wants an A/B result; batch only when each change has its own evidence.
- Judge by per-pause length and percentiles, not total GC time. 0.09% GC overhead still hides a 100 ms pause.
- Diagnostic logging (JFR, jit/deopt debug, gc+phases=debug) is temporary. Remove it once the cause is found.

## Evidence to change

| Evidence in logs | Change | Why |
| --- | --- | --- |
| `Pause Full (System.gc())` | `-XX:+ExplicitGCInvokesConcurrent` | Mods and NIO call `System.gc()`; this turns a 175-220 ms full GC into a young pause. Do not use `DisableExplicitGC`: it breaks dynamic_fps/memguard and NIO direct-buffer cleanup. |
| IHOP `threshold: 0B` on many lines, many `Concurrent Start` pauses with old gen far under the heap | `-XX:-G1UseAdaptiveIHOP -XX:InitiatingHeapOccupancyPercent=30` | Adaptive IHOP predicted a huge old-gen allocation rate from the startup spike and marked constantly. Static IHOP only when live set is below the threshold (8G heap, IHOP 30 = 2.4G). Never IHOP=10. |
| `Pause Young (Metadata GC Threshold)` at launch | `-XX:MetaspaceSize=` above the observed peak (320M for peak 285M) | Value is a trigger threshold, commits no memory. |
| Steady-state young pauses well above frame time, or more than a few over 25 ms | Lower `-XX:MaxGCPauseMillis` (16 for a client at 60-144 fps) | G1 sizes young gen to meet the target; 37 ms lets pauses span 2-4 frames. |
| Mixed pauses 40-100 ms | Remove `-XX:G1MixedGCCountTarget=3` (default 8) | Fewer, larger mixed collections. |
| `PrintThreads`, `FindDeadlocks`, `ClassLoaderStatsOperation` safepoints about every 60 s | Remove `-XX:StartFlightRecording` | JFR periodic thread dumps and sampling cost frame time. |
| Large `jit+compilation=debug` / `deoptimization=debug` logs | Remove those `-Xlog` tags | Synchronous writes from compiler threads. |
| JIT compile or deopt bursts continuing past 20 min, compiler threads plus GC workers plus mod worker pools above logical cores | Cap `-XX:CICompilerCount` (8 on 16 logical cores) | Inference only: the logs show the bursts, not that they cost frames. Label it as such. |
| `Evacuation Failure`, `To-space exhausted`, Full GC | Raise `-XX:G1ReservePercent`, check live set vs heap | Heap pressure; check the mod list first. |
| Humongous regions growing | Check `-XX:G1HeapRegionSize` vs allocation sizes | 16M regions make objects under 8M non-humongous. |
| JFR hot-methods dominated by Sodium `OcclusionCuller`, chunk builders | Not a JVM problem | Report as "not a JVM issue": Sodium culling, render distance, Nvidium, C2ME threads. |
| Time-to-safepoint above 5-10 ms | Look at JNI, counted loops, `-XX:+UseCountedLoopSafepoints` only with evidence | Rare on this setup (max seen 9 ms). |

## Flags found inert, obsolete, or harmful

- `-XX:+UseGraalJIT`: inert on GraalVM 25 (JVMCI is enabled by `EnableJVMCI`, the flag does nothing).
- `-XX:+UseNUMA`: inert on a single NUMA node.
- `-Dfml.*`: Forge-only; this pack is Fabric. Removed from both Prism instances on 2026-10-16.
- `-XX:+DisableExplicitGC`: broke mods that call `System.gc()` (see above).
- `-XX:InitiatingHeapOccupancyPercent=10`: near-continuous marking.
- `-XX:G1NewSizePercent=23`: fought `MaxGCPauseMillis`.
- `-XX:G1RSetUpdatingPauseTimePercent=5`: a 2026-10-06 audit found all 98 tokens recognized on JDK 25.0.4, so do
  not call it obsolete. It was removed on 2026-10-12 as low-value tuning, not because the JVM rejects it.
- `-XX:ThreadPriorityPolicy=1`: documented for Linux (needs root); effect on Windows unverified. Leave it unless
  `-ValidateArgs` complains.
- `-XX:+UseCriticalJavaThreadPriority`: raises all Java threads on Windows; removed in the 2026-10-12 pass as an inference.
- `-XX:+IgnoreUnrecognizedVMOptions`: hides typos and removed flags. Audit without it (see `-ValidateArgs`). Removed on 2026-10-16 after a strict pass reported no complaints for the remaining 94 tokens.
- `-Xlog:disable` hides large-page fallback warnings. Audit with `-Xlog:pagesize=info,gc+init=info`.
- Many flags restate defaults (`UseG1GC`, `UseAVX=2`, `TieredCompilation`, `SegmentedCodeCache`,
  `ParallelRefProcEnabled`, `ConcGCThreads=3`): harmless; only remove them for tidiness.
- `OverrideJavaArgs=true` in `instance.cfg` means the instance ignores the global `prismlauncher.cfg` args.

## Logging presets

Order matters: a later `-Xlog` re-enables output after `-Xlog:disable`. Files land in `minecraft/logs/`;
`-Xlog` does not create the folder, and a missing folder fails launch with "Invalid -Xlog option". Create
`minecraft/logs/` first when copying these args into a new instance.

Normal (GC pauses and safepoints only, cheap; the user's chosen setup since 2026-10-16):

```
-Xlog:disable -Xlog:async -Xlog:gc,safepoint:file=logs/jvm-gc.log:time,uptime:filecount=3,filesize=10M
```

The fixed file name is deliberate: `filecount=3` then bounds disk use (the JVM keeps `jvm-gc.log` plus
`jvm-gc.log.0` to `.2`). A `%t` name makes a new file per launch and nothing prunes them. JVM warnings stay
hidden by `-Xlog:disable`; the user declined an `-Xlog:all=warning:stderr` line for them.

Diagnose (temporary; costs about 2% plus a 50 MB .jfr per session):

```
-Xlog:disable -Xlog:all=warning,gc*=info,gc+phases=debug,gc+cpu=info,safepoint=info,pagesize=info:file=logs/jvm-gc-%t.log:time,uptime,level,tags:filecount=3,filesize=50M -Xlog:deoptimization=debug,jit+compilation=debug,codecache=info:file=logs/jvm-jit-%t.log:time,uptime,level,tags:filecount=3,filesize=50M -XX:StartFlightRecording=name=stutter,settings=profile,maxage=30m,maxsize=600M,dumponexit=true,filename=logs/stutter-%t.jfr
```

`dumponexit` needs a normal game quit. `jcmd <pid> JFR.dump name=stutter` dumps mid-session.

## Reference machine

i9-9900K (8c/16t), RTX 2080 SUPER, GraalVM Oracle JDK 25.0.4 EA (JVMCI), 8 GB fixed heap, large pages,
Fabric 1.21.11 with about 254 mods (Sodium, Nvidium, C2ME, Lithium, ModernFix, EntityCulling).
2026-10-12 baseline before tuning: 370 GC pauses, 23 over 25 ms, max 103 ms at world load, JFR P99 12 ms.
