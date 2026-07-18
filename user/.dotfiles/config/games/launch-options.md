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

Minecraft [graalvm](https://www.graalvm.org/downloads/):
```text
-XX:+UnlockExperimentalVMOptions -XX:+UnlockDiagnosticVMOptions -XX:+AlwaysActAsServerClassMachine -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:AllocatePrefetchStyle=3 -XX:ReservedCodeCacheSize=400M -XX:NonNMethodCodeHeapSize=12M -XX:ProfiledCodeHeapSize=194M -XX:NonProfiledCodeHeapSize=194M -XX:+PerfDisableSharedMem -XX:+UseFastUnorderedTimeStamps -XX:+UseCriticalJavaThreadPriority -XX:+EagerJVMCI -XX:+UseG1GC -XX:MaxGCPauseMillis=37 -XX:G1HeapRegionSize=16M -XX:G1NewSizePercent=23 -XX:G1ReservePercent=20 -XX:SurvivorRatio=6 -XX:G1MixedGCCountTarget=3 -XX:G1HeapWastePercent=20 -XX:InitiatingHeapOccupancyPercent=10 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:MaxTenuringThreshold=6 -XX:G1SATBBufferEnqueueingThresholdPercent=30 -XX:G1ConcMarkStepDurationMillis=5 -XX:ConcGCThreads=3 -XX:+UseLargePages -XX:LargePageSizeInBytes=2M -XX:+ParallelRefProcEnabled -Dfml.ignoreInvalidMinecraftCertificates=true -Dfml.ignorePatchDiscrepancies=true -XX:ThreadPriorityPolicy=1 -XX:+UseStringDeduplication -XX:+UseCompressedOops -XX:+OptimizeStringConcat -XX:+DisableAttachMechanism -Djdk.graal.OptimizeLongJumps=true -XX:G1MaxNewSizePercent=40 -XX:+UseFMA -XX:+LoopMultiversioning --add-modules=jdk.incubator.vector -Dfile.encoding=UTF-8 -XX:+UseGraalJIT -Xlog:disable -XX:+G1PeriodicGCInvokesConcurrent -XX:+UseCompactObjectHeaders -XX:+CompactStrings -XX:+TieredCompilation -XX:+OptimizeFill -XX:+UseNUMA -XX:+UseInlineCaches -XX:+SegmentedCodeCache -XX:+UseThreadPriorities -XX:+OmitStackTraceInFastThrow -XX:+RewriteBytecodes -XX:+RewriteFrequentPairs -XX:UseAVX=2 -XX:UseSSE=4 -XX:+UseAESIntrinsics -XX:+UseCodeCacheFlushing -Djdk.graal.CompilerConfiguration=enterprise -Djdk.graal.TuneInlinerExploration=1 -Dgraal.LoopRotation=true -Dsodium.checks.issue2561=false
```

Minecraft non-graalvm/eclipse
```text
-XX:+UnlockExperimentalVMOptions -XX:+UnlockDiagnosticVMOptions -XX:+AlwaysActAsServerClassMachine -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:AllocatePrefetchStyle=3 -XX:ReservedCodeCacheSize=400M -XX:NonNMethodCodeHeapSize=12M -XX:ProfiledCodeHeapSize=194M -XX:NonProfiledCodeHeapSize=194M -XX:-DontCompileHugeMethods -XX:MaxNodeLimit=240000 -XX:NodeLimitFudgeFactor=8000 -XX:+PerfDisableSharedMem -XX:+UseFastUnorderedTimeStamps -XX:+UseCriticalJavaThreadPriority -XX:+UseG1GC -XX:MaxGCPauseMillis=37 -XX:G1HeapRegionSize=16M -XX:G1NewSizePercent=23 -XX:G1ReservePercent=20 -XX:SurvivorRatio=6 -XX:G1MixedGCCountTarget=3 -XX:G1HeapWastePercent=20 -XX:InitiatingHeapOccupancyPercent=10 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:MaxTenuringThreshold=6 -XX:G1SATBBufferEnqueueingThresholdPercent=30 -XX:G1ConcMarkStepDurationMillis=5 -XX:+UseVectorCmov -XX:ConcGCThreads=3 -XX:+UseLargePages -XX:LargePageSizeInBytes=2M -XX:+ParallelRefProcEnabled -Dfml.ignoreInvalidMinecraftCertificates=true -Dfml.ignorePatchDiscrepancies=true -XX:ThreadPriorityPolicy=1 -XX:+UseStringDeduplication -XX:+UseCompressedOops -XX:+OptimizeStringConcat -XX:+DisableAttachMechanism -XX:G1MaxNewSizePercent=40 -XX:+UseFMA -XX:+LoopMultiversioning --add-modules=jdk.incubator.vector -Dfile.encoding=UTF-8 -Xlog:disable -XX:+G1PeriodicGCInvokesConcurrent -XX:+UseCompactObjectHeaders -XX:+CompactStrings -XX:+TieredCompilation -XX:+OptimizeFill -XX:+UseNUMA -XX:+UseCharacterCompareIntrinsics -XX:+UseCopySignIntrinsic -XX:+UseInlineCaches -XX:+SegmentedCodeCache -XX:+UseNewLongLShift -XX:+UseXMMForArrayCopy -XX:+UseThreadPriorities -XX:+OmitStackTraceInFastThrow -XX:+EliminateLocks -XX:+AlignVector -XX:+UseVectorStubs -XX:+UseXmmI2D -XX:+UseXmmI2F -XX:+UseXmmLoadAndClearUpper -XX:+UseFPUForSpilling -XX:+UseFastStosb -XX:+UseXmmRegToRegMoveAll -XX:+UseLoopPredicate -XX:+RangeCheckElimination -XX:+RewriteBytecodes -XX:+RewriteFrequentPairs -XX:+DoEscapeAnalysis -XX:UseAVX=2 -XX:UseSSE=4 -XX:+TrustFinalNonStaticFields -XX:+UseAESIntrinsics -XX:+UseCodeCacheFlushing -Dsodium.checks.issue2561=false
```

- [meowice flags](https://github.com/MeowIce/meowice-flags)
- [Obydux graavm flags](https://github.com/Obydux/Minecraft-GraalVM-Flags)
- [Graalvm docs](https://www.graalvm.org/latest/reference-manual/java/options/)
