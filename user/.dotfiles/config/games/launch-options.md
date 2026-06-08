Steam:
```text
"C:\Program Files (x86)\Steam\Steam.exe" -nofriendsui -nochatui -nointro -nobigpicture -cef-disable-js-logging -noconsole -no-browser +open steam://open/minigameslist
```

Steam games:
```text
-dx12 -high -novid -nocrashdialog -noforcemaccel -noforcemspd -useforcedmparms -nomousegrab -nod3d9ex -threads 16 -fullscreen -nomansky -NOTEXTURESTREAMING -noipx -nojoy
```

Arc-Raiders:
```text
"C:\Program Files (x86)\Steam\steamapps\common\Arc Raiders\PioneerGame\Binaries\Win64\PioneerGame-d.exe" %command% -dx12 -nojoy -high
```

Epicgames:
```text
-limitclientticks -lanplay -NOSPLASH -NOFORCEFEEDBACK -NOTEXTURESTREAMING -USEALLAVAILABLECORES -FrameQueueLimit 1 -NoVSync -nomoviestartup
```

Minecraft graalvm:
```text
-XX:+UnlockExperimentalVMOptions -XX:+UnlockDiagnosticVMOptions -XX:+AlwaysActAsServerClassMachine -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+UseNUMA -XX:AllocatePrefetchStyle=3 -XX:NmethodSweepActivity=1 -XX:ReservedCodeCacheSize=400M -XX:NonNMethodCodeHeapSize=12M -XX:ProfiledCodeHeapSize=194M -XX:NonProfiledCodeHeapSize=194M -XX:-DontCompileHugeMethods -XX:+PerfDisableSharedMem -XX:+UseFastUnorderedTimeStamps -XX:+UseCriticalJavaThreadPriority -XX:+EagerJVMCI -Dgraal.TuneInlinerExploration=1 -Dgraal.CompilerConfiguration=enterprise -XX:+UseG1GC -XX:MaxGCPauseMillis=37 -XX:+PerfDisableSharedMem -XX:G1HeapRegionSize=16M -XX:G1NewSizePercent=23 -XX:G1ReservePercent=20 -XX:SurvivorRatio=32 -XX:G1MixedGCCountTarget=3 -XX:G1HeapWastePercent=20 -XX:InitiatingHeapOccupancyPercent=10 -XX:G1RSetUpdatingPauseTimePercent=0 -XX:MaxTenuringThreshold=1 -XX:G1SATBBufferEnqueueingThresholdPercent=30 -XX:G1ConcMarkStepDurationMillis=5.0 -XX:G1ConcRSHotCardLimit=16 -XX:G1ConcRefinementServiceIntervalMillis=150 -XX:GCTimeRatio=99 -XX:+UseVectorCmov -XX:ConcGCThreads=6 -XX:+UseLargePages -XX:LargePageSizeInBytes=2m -Dgraal.LoopRotation=true -Dgraal.PartialUnroll=true -Dgraal.VectorizeSIMD=true -XX:+ParallelRefProcEnabled -XX:+PerfDisableSharedMem -Dgraal.BaseTargetSpending=160 -Dfml.ignoreInvalidMinecraftCertificates=true -Dfml.ignorePatchDiscrepancies=true -XX:ThreadPriorityPolicy=1 -XX:+UseStringDeduplication -XX:+UseCompressedOops -XX:+OptimizeStringConcat -XX:+DisableAttachMechanism -Djdk.graal.OptimizeLongJumps=true -Dgraal.OptimizeVectorAPI=true -Dgraal.Vectorization=true -Dgraal.UsePriorityInlining=true
```
