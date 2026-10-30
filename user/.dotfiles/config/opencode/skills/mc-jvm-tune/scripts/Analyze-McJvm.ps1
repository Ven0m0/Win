#Requires -Version 7
<#
.SYNOPSIS
Read-only analysis of a PrismLauncher Minecraft instance's JVM logs and JvmArgs.

.DESCRIPTION
Prints compact sections: Config, latest.log, GC, Safepoints, JIT, JFR. A section is skipped when
its log does not exist. With -ValidateArgs, only runs a strict JVM flag check and exits.
Never writes to the instance.

.PARAMETER Instance
Instance directory (the folder that holds instance.cfg).

.PARAMETER LogsDir
Override for the logs folder. Default: <Instance>\minecraft\logs (or .minecraft\logs).

.PARAMETER Session
'latest' (default) or a timestamp fragment such as 2026-10-12_15-16-33 to pick an older GC log.

.PARAMETER SteadyStateSec
Uptime in seconds after which a pause counts as steady state (startup and world load excluded).

.PARAMETER ValidateArgs
A JvmArgs string to check against the instance's java.exe without IgnoreUnrecognizedVMOptions.

.PARAMETER JfrPath
Explicit .jfr file; use when the recording's timestamp does not match the GC log's session.

.PARAMETER NoJfr
Skip jfr.exe views.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Instance,
  [string]$LogsDir,
  [string]$Session = 'latest',
  [int]$SteadyStateSec = 200,
  [string]$ValidateArgs,
  [string]$JfrPath,
  [switch]$NoJfr
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$inv = [Globalization.CultureInfo]::InvariantCulture

function Write-Section([string]$Title) { "`n=== $Title ===" }
function ConvertTo-Double([string]$s) { [double]::Parse($s, $inv) }

# FileShare.ReadWrite: the running game keeps latest.log and the active GC/JIT logs open for writing.
function Read-SharedLine([string]$Path) {
 $fs = [IO.FileStream]::new($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
 $sr = [IO.StreamReader]::new($fs)
 try { $sr.ReadToEnd() -split '\r?\n' } finally { $sr.Dispose() }
}

function Get-Percentile([double[]]$Sorted, [double]$P) {
  if ($Sorted.Count -eq 0) { return 0 }
  $i = [math]::Min($Sorted.Count - 1, [math]::Ceiling($P / 100 * $Sorted.Count) - 1)
  $Sorted[[math]::Max(0, $i)]
}

function Get-Stat([double[]]$Values) {
  $s = @($Values | Sort-Object)
  [pscustomobject]@{
    n   = $s.Count
    avg = if ($s.Count) { [math]::Round(($s | Measure-Object -Average).Average, 1) } else { 0 }
    p50 = [math]::Round((Get-Percentile $s 50), 1)
    p95 = [math]::Round((Get-Percentile $s 95), 1)
    p99 = [math]::Round((Get-Percentile $s 99), 1)
    max = [math]::Round((Get-Percentile $s 100), 1)
  }
}

# --- locate instance files -------------------------------------------------
$cfgPath = Join-Path $Instance 'instance.cfg'
if (-not (Test-Path -LiteralPath $cfgPath)) { throw "instance.cfg not found in '$Instance'" }
$cfg = Get-Content -LiteralPath $cfgPath
function Get-CfgValue([string]$Key) {
  $line = $cfg | Where-Object { $_ -match "^$Key=" } | Select-Object -First 1
  if ($line) { $line.Substring($Key.Length + 1) } else { '' }
}
$jvmArgsRaw = (Get-CfgValue 'JvmArgs').Trim('"')
$javaPath = Get-CfgValue 'JavaPath'
$javaExe = if ($javaPath) { Join-Path (Split-Path $javaPath) 'java.exe' } else { 'java.exe' }
$jfrExe = if ($javaPath) { Join-Path (Split-Path $javaPath) 'jfr.exe' } else { 'jfr.exe' }

if (-not $LogsDir) {
  $LogsDir = @('minecraft\logs', '.minecraft\logs') |
    ForEach-Object { Join-Path $Instance $_ } |
    Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

# --- strict flag validation (separate mode) ---------------------------------
if ($ValidateArgs) {
  Write-Section 'ValidateArgs (strict, no IgnoreUnrecognizedVMOptions)'
  # Dropped: hides errors (Ignore*, -Xlog:disable) or writes files / pretouches 8 GB (JFR, -Xlog file, PreTouch).
  $drop = '^-XX:\+IgnoreUnrecognizedVMOptions$|^-Xlog:disable$|^-XX:StartFlightRecording|^-Xlog:.*file=|^-XX:\+AlwaysPreTouch$'
  $tokens = [System.Collections.Generic.List[string]]::new()
  ($ValidateArgs.Trim('"') -split '\s+' | Where-Object { $_ -and $_ -notmatch $drop }) | ForEach-Object { $tokens.Add($_) }
  $removed = @()
  for ($try = 0; $try -lt 25; $try++) {
    $out = & $javaExe @tokens -version 2>&1 | ForEach-Object { "$_" }
    $bad = $out | Select-String -Pattern "Unrecognized VM option '([^']+)'" | Select-Object -First 1
    if (-not $bad) { break }
    $name = $bad.Matches[0].Groups[1].Value
    $hit = $tokens | Where-Object { $_ -like "*$name*" } | Select-Object -First 1
    $removed += $name
    if ($hit) { [void]$tokens.Remove($hit) } else { break }
  }
  if ($removed) { "Unrecognized (removed to continue): $($removed -join ', ')" }
  # The incubator-module warning is expected with --add-modules=jdk.incubator.vector.
  $warn = $out | Where-Object { $_ -match 'obsolete|deprecated|ignoring|Could not|Error|Invalid|warning' -and $_ -notmatch 'incubator modules' }
  if ($warn) { $warn } elseif (-not $removed) { 'No complaints from the JVM.' }
  return
}

# --- Config ------------------------------------------------------------------
Write-Section 'Config'
$tokens = @($jvmArgsRaw -split '\s+' | Where-Object { $_ })
"Instance      : $Instance"
"JavaPath      : $javaPath"
"Heap          : Min $(Get-CfgValue 'MinMemAlloc') MB / Max $(Get-CfgValue 'MaxMemAlloc') MB (OverrideMemory=$(Get-CfgValue 'OverrideMemory'))"
"OverrideJavaArgs=$(Get-CfgValue 'OverrideJavaArgs'); JvmArgs tokens: $($tokens.Count)"
$dups = $tokens | Group-Object | Where-Object { $_.Count -gt 1 }
if ($dups) { "Duplicate tokens: $(($dups | ForEach-Object { $_.Name }) -join ' ')" }

# shortcut: static table, extend it when a new flag is proven inert (see references/flag-rules.md)
$knownBad = @(
  @{ Pattern = 'UseGraalJIT';                   Note = 'inert on GraalVM 25' }
  @{ Pattern = 'UseNUMA';                       Note = 'inert on a single NUMA node' }
  @{ Pattern = '^-Dfml\.';                      Note = 'Forge-only, no effect on Fabric' }
  @{ Pattern = 'DisableExplicitGC';             Note = 'breaks mods and NIO that call System.gc(); prefer ExplicitGCInvokesConcurrent' }
  @{ Pattern = 'InitiatingHeapOccupancyPercent=10$'; Note = 'near-continuous marking' }
  @{ Pattern = 'G1NewSizePercent';              Note = 'fights MaxGCPauseMillis' }
  @{ Pattern = 'IgnoreUnrecognizedVMOptions';   Note = 'hides typos and removed flags; audit with -ValidateArgs' }
)
$diag = @(
  @{ Pattern = 'StartFlightRecording';          Note = 'JFR costs frame time and adds periodic safepoints; remove after diagnosing' }
  @{ Pattern = 'jit\+compilation=debug|deoptimization=debug'; Note = 'debug JIT logging; remove after diagnosing' }
  @{ Pattern = 'gc\+phases=debug';              Note = 'debug GC phases; remove after diagnosing' }
)
foreach ($entry in $knownBad) {
  $hit = $tokens | Where-Object { $_ -match $entry.Pattern }
  if ($hit) { "Known-bad       : $($hit -join ' ') - $($entry.Note)" }
}
foreach ($entry in $diag) {
  $hit = $tokens | Where-Object { $_ -match $entry.Pattern }
  if ($hit) { "Diagnostic flag : $($hit -join ' ') - $($entry.Note)" }
}
$maxPauseToken = $tokens | Where-Object { $_ -match '^-XX:MaxGCPauseMillis=(\d+)$' } | Select-Object -First 1
$pauseTarget = if ($maxPauseToken) { [int]($maxPauseToken -replace '\D') } else { 200 }
"MaxGCPauseMillis target: $pauseTarget ms$(if (-not $maxPauseToken) { ' (default)' })"
$graal = @($tokens | Where-Object { $_ -match '^-Djdk\.graal\.' }).Count
if ($graal) { "jdk.graal.* flags: $graal (user wants them kept)" }

# --- latest.log --------------------------------------------------------------
$latest = if ($LogsDir) { Join-Path $LogsDir 'latest.log' }
if ($latest -and (Test-Path -LiteralPath $latest)) {
  Write-Section 'latest.log'
  $facts = [ordered]@{}
  $level = @{ WARN = 0; ERROR = 0 }
  $keep = @{ "Can't keep up" = 0; 'OutOfMemory' = 0; 'Exception' = 0 }
  $msgs = @{}
  $workers = 0
  $behindMax = 0.0
  $slow = [System.Collections.Generic.List[object]]::new()
  foreach ($line in (Read-SharedLine $latest)) {
    if ($line -match 'Loading Minecraft (\S+) with Fabric Loader (\S+)') { $facts['Minecraft/Fabric'] = "$($Matches[1]) / $($Matches[2])" }
    elseif ($line -match 'Loading (\d+) mods') { $facts['Mods'] = $Matches[1] }
    elseif ($line -match 'CPU name: (.+)$') { $facts['CPU'] = $Matches[1] }
    elseif ($line -match 'OpenGL Renderer: (.+)$') { $facts['GPU'] = $Matches[1] }
    elseif ($line -match 'with OpenGL (.+)$') { $facts['OpenGL'] = $Matches[1] }
    elseif ($line -match 'Sodium has applied.*\[(.+)\]') { $facts['Sodium workarounds'] = $Matches[1] }
    elseif ($line -match 'Java: (.+?) \(') { $facts['JVM'] = $Matches[1] }
    if ($line -match 'Started (\d+) worker threads') { $workers = [int]$Matches[1] }
    if ($line -match '^\[[\d:]+\] \[[^\]]*/(WARN|ERROR)\]: (.*)$') {
      $level[$Matches[1]]++
      $key = ($Matches[1] + ' ' + ($Matches[2] -replace '\d+', '#'))
      if ($key.Length -gt 100) { $key = $key.Substring(0, 100) }
      $msgs[$key] = 1 + [int]$msgs[$key]
    }
    foreach ($k in @($keep.Keys)) { if ($line.Contains($k)) { $keep[$k]++ } }
    if ($line -match 'Running (\d+)ms or \d+ ticks behind') { $behindMax = [math]::Max($behindMax, [double]$Matches[1]) }
    # Generic "took 2.4s" / "in 1500ms" lines: mods log their own load and reload times this way.
    if ($line -match '\b(?:took|in)\s+(\d+(?:\.\d+)?)\s?(ms|s)\b') {
      $ms = (ConvertTo-Double $Matches[1]) * $(if ($Matches[2] -eq 's') { 1000 } else { 1 })
      if ($ms -ge 1000) { $slow.Add([pscustomobject]@{ ms = $ms; line = $line.Trim().Substring(0, [math]::Min(110, $line.Trim().Length)) }) }
    }
  }
  $facts.GetEnumerator() | ForEach-Object { '{0,-18}: {1}' -f $_.Key, $_.Value }
  if ($workers) { '{0,-18}: {1}' -f 'Chunk workers', $workers }
  "WARN $($level.WARN), ERROR $($level.ERROR); Can't keep up $($keep["Can't keep up"])$(if ($behindMax) { " (worst $behindMax ms behind)" }), OutOfMemory $($keep.OutOfMemory), 'Exception' lines $($keep.Exception)"
  if ($slow.Count) {
    "Slow operations (>= 1 s, $($slow.Count) lines, top 5):"
    $slow | Sort-Object ms -Descending | Select-Object -First 5 | ForEach-Object { "  $($_.line)" }
  }
  'Top repeated WARN/ERROR (digits normalized):'
  $msgs.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 6 |
    ForEach-Object { '  {0,5}x {1}' -f $_.Value, $_.Key }
} else {
  Write-Section 'latest.log'
  'not found'
}

# --- stderr_stream.log (Prism's capture of the game's stderr; JVM and native warnings land here) -----
$stderrLog = if ($LogsDir) { Join-Path $LogsDir 'stderr_stream.log' }
if ($stderrLog -and (Test-Path -LiteralPath $stderrLog)) {
  Write-Section 'stderr_stream.log'
  $errs = @{}
  foreach ($line in (Read-SharedLine $stderrLog)) {
    if ($line -match '^\[[\d:]+\] \[STDERR\]: (.*)$') {
      $key = $Matches[1] -replace '\d+', '#'
      if ($key.Length -gt 140) { $key = $key.Substring(0, 140) }
      $errs[$key] = 1 + [int]$errs[$key]
    }
  }
  if ($errs.Count -eq 0) { 'empty' } else {
    $errs.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 6 |
      ForEach-Object { '  {0,5}x {1}' -f $_.Value, $_.Key }
  }
}

# --- Crashes (newest game crash reports and JVM hs_err logs) -------------------------------------------
if ($LogsDir) {
  $gameDir = Split-Path $LogsDir
  $reports = @(Get-ChildItem -LiteralPath (Join-Path $gameDir 'crash-reports') -Filter 'crash-*.txt' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 3)
  $hsErr = @(Get-ChildItem -LiteralPath $gameDir -Filter 'hs_err_pid*.log' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 2)
  if ($reports.Count + $hsErr.Count) {
    Write-Section 'Crashes (newest first)'
    foreach ($f in $reports) {
      $lines = @(Read-SharedLine $f.FullName | Select-Object -First 12)
      $i = [array]::FindIndex($lines, [Predicate[string]] { param($l) $l -like 'Description:*' })
      $what = if ($i -ge 0) { ($lines[$i..([math]::Min($i + 3, $lines.Count - 1))] | Where-Object { $_.Trim() }) -join ' | ' } else { '(no Description line)' }
      "$($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))  $($f.Name): $what"
    }
    foreach ($f in $hsErr) {
      $why = Read-SharedLine $f.FullName | Where-Object { $_ -match '^# (EXCEPTION|SIGSEGV|Out of Memory|Internal Error|C  \[|V  \[|J  )' } | Select-Object -First 2
      "$($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))  $($f.Name): $($why -join ' | ')"
    }
  }
}

# --- GC log + safepoints -----------------------------------------------------
$stamp = $null
$gcFiles = @()
if ($LogsDir -and (Test-Path -LiteralPath $LogsDir)) {
  $gcFiles = @(Get-ChildItem -LiteralPath $LogsDir -File |
    Where-Object { $_.Name -match '^(jvm-gc(-.*)?\.log(\.\d+)?|gc\.log(\.\d+)?)$' } |
    Sort-Object LastWriteTime -Descending)
}
$gcFile = if ($Session -eq 'latest') { $gcFiles | Select-Object -First 1 } else { $gcFiles | Where-Object { $_.Name -like "*$Session*" } | Select-Object -First 1 }

Write-Section 'GC'
if (-not $gcFile) {
  'No GC log found. Add the Normal or Diagnose logging preset from references/flag-rules.md and play a session first.'
} else {
  if ($gcFile.Name -match '^jvm-gc-(.+)\.log$') { $stamp = $Matches[1] }
  "File: $($gcFile.Name) ($([math]::Round($gcFile.Length / 1MB, 1)) MB)"
  # Decorators vary with the -Xlog preset (level/tags may be absent), so [..] groups between uptime and GC( are optional.
  $rxPause = '^\[[^\]]*\]\[(\d+\.\d+)s\](?:\[[^\]]*\])*\s*GC\((\d+)\) (Pause .*?) (\d+)M->(\d+)M\((\d+)M\) (\d+\.\d+)ms\s*$'
  $rxSafe = '\[(\d+\.\d+)s\].*Safepoint "(\w+)".*Reaching safepoint: (\d+) ns.*Total: (\d+) ns'
  $pauses = [System.Collections.Generic.List[object]]::new()
  $safe = [System.Collections.Generic.List[object]]::new()
  $ihopZero = 0; $ihopTotal = 0; $evacFail = 0
  foreach ($line in (Read-SharedLine $gcFile.FullName)) {
    if ($line.Contains('Pause ') -and $line -match $rxPause) {
      $raw = $Matches[3]
      $kind = ($raw -replace '^Pause ', '' -replace '\s*\(G1 [^)]*\)', '' -replace '[()]', '' -replace '\s+', ' ').Trim()
      $pauses.Add([pscustomobject]@{
        t = ConvertTo-Double $Matches[1]; kind = $kind; raw = $raw
        pre = [int]$Matches[4]; post = [int]$Matches[5]; cap = [int]$Matches[6]; ms = ConvertTo-Double $Matches[7]
      })
    } elseif ($line.Contains('Safepoint "') -and $line -match $rxSafe) {
      $safe.Add([pscustomobject]@{
        t = ConvertTo-Double $Matches[1]; op = $Matches[2]
        reach = [double]$Matches[3] / 1e6; total = [double]$Matches[4] / 1e6
      })
    } elseif ($line.Contains('threshold: ') -and $line -match 'threshold: (\d+)B') {
      $ihopTotal++
      if ($Matches[1] -eq '0') { $ihopZero++ }
    } elseif ($line -match 'Evacuation Failure|To-space exhausted') { $evacFail++ }
  }

  if ($pauses.Count -eq 0) {
    'No pause records parsed. Is gc logging on (-Xlog:gc)?'
  } else {
    $steady = @($pauses | Where-Object { $_.t -ge $SteadyStateSec })
    $startup = @($pauses | Where-Object { $_.t -lt $SteadyStateSec })
    $span = ($pauses | Measure-Object t -Maximum).Maximum
    $gcMs = ($pauses | Measure-Object ms -Sum).Sum
    "Pauses: $($pauses.Count) over $([math]::Round($span / 60, 1)) min; total $([math]::Round($gcMs / 1000, 2)) s ($([math]::Round(100 * $gcMs / 1000 / [math]::Max(1, $span), 3))% of uptime)"
    "Steady state = uptime >= ${SteadyStateSec}s: $($steady.Count) pauses; startup/world-load: $($startup.Count)"
    if ($steady.Count) {
      'Steady-state pauses by kind (ms):'
      $steady | Group-Object kind | Sort-Object Count -Descending | ForEach-Object {
        $st = Get-Stat @($_.Group | ForEach-Object { $_.ms })
        [pscustomobject]@{ Kind = $_.Name; n = $st.n; avg = $st.avg; p95 = $st.p95; p99 = $st.p99; max = $st.max }
      } | Format-Table -AutoSize | Out-String -Width 160 | ForEach-Object { $_.TrimEnd() }
      foreach ($set in @(@('steady', $steady), @('all', $pauses))) {
        $v = $set[1]
        $over = foreach ($th in 10, 16.6, 25, $pauseTarget) { "> $th ms: $(@($v | Where-Object { $_.ms -gt $th }).Count)" }
        "Over threshold ($($set[0])): $($over -join ', ')"
      }
      $ordered = @($steady | Sort-Object t)
      $young = @($ordered | Where-Object { $_.kind -like 'Young*' })
      if ($young.Count -gt 1) {
        $gaps = for (($i = 1), ($youngCount = $young.Count); $i -lt $youngCount; $i++) { $young[$i].t - $young[$i - 1].t }
        $alloc = 0
        for (($i = 1), ($orderedCount = $ordered.Count); $i -lt $orderedCount; $i++) { $alloc += [math]::Max(0, $ordered[$i].pre - $ordered[$i - 1].post) }
        $dur = $ordered[-1].t - $ordered[0].t
        "Young GC every ~$([math]::Round((Get-Percentile ($gaps | Sort-Object) 50), 1)) s; allocation ~$([math]::Round($alloc / [math]::Max(1, $dur))) MB/s"
      }
      $liveSet = @($steady | Where-Object { $_.kind -eq 'Young Normal' } | ForEach-Object { $_.post } | Sort-Object)
      if ($liveSet.Count) { "Heap after young GC: median $(Get-Percentile $liveSet 50) M, max $(Get-Percentile $liveSet 100) M of $($pauses[-1].cap) M" }
    }
    'Worst 8 pauses (uptime s | kind | ms):'
    $pauses | Sort-Object ms -Descending | Select-Object -First 8 | ForEach-Object {
      '  {0,8:N0}s  {1,-34} {2,7:N1}{3}' -f $_.t, $_.kind, $_.ms, $(if ($_.t -lt $SteadyStateSec) { '  (startup)' } else { '' })
    }
    $cycles = @($pauses | Where-Object { $_.kind -like '*Concurrent Start*' }).Count
    $sysgc = @($pauses | Where-Object { $_.raw -match 'System\.gc' }).Count
    $meta = @($pauses | Where-Object { $_.raw -match 'Metadata GC Threshold' }).Count
    $humo = @($pauses | Where-Object { $_.raw -match 'Humongous' }).Count
    $full = @($pauses | Where-Object { $_.kind -like 'Full*' }).Count
    "Causes: concurrent cycles $cycles, System.gc() $sysgc, Metadata threshold $meta, Humongous alloc $humo, Full GC $full, evacuation failures $evacFail"
    if ($ihopTotal) { "IHOP: threshold 0B on $ihopZero of $ihopTotal lines$(if ($ihopZero / $ihopTotal -gt 0.2) { '  <- adaptive IHOP collapse, see flag-rules.md' })" }
  }

  Write-Section 'Safepoints'
  if ($safe.Count -eq 0) {
    'No safepoint records (needs safepoint=info in -Xlog). Skipped.'
  } else {
    $sp = @($safe | Where-Object { $_.t -ge $SteadyStateSec })
    if ($sp.Count -eq 0) {
      "No safepoints at uptime >= ${SteadyStateSec}s (session too short); using all $($safe.Count) for the table."
      $sp = @($safe)
    }
    "Safepoints: $($sp.Count); max time-to-safepoint $([math]::Round(($sp | Measure-Object reach -Maximum).Maximum, 2)) ms"
    $sp | Group-Object op | ForEach-Object {
      [pscustomobject]@{
        Op = $_.Name; n = $_.Count
        maxMs = [math]::Round(($_.Group | Measure-Object total -Maximum).Maximum, 1)
        note = if ($_.Name -match 'PrintThreads|FindDeadlocks|JFR|ClassLoaderStats') { 'JFR/periodic' } else { '' }
      }
    } | Sort-Object maxMs -Descending | Select-Object -First 8 | Format-Table -AutoSize | Out-String -Width 160 | ForEach-Object { $_.TrimEnd() }
  }
}

# --- JIT log -----------------------------------------------------------------
function Find-SessionFile([string]$Prefix, [string]$Ext, [string]$Stamp) {
  if (-not ($LogsDir -and (Test-Path -LiteralPath $LogsDir))) { return $null }
  if ($Stamp) {
    $p = Join-Path $LogsDir "$Prefix$Stamp$Ext"
    if ((Test-Path -LiteralPath $p) -and (Get-Item -LiteralPath $p).Length -gt 0) { return Get-Item -LiteralPath $p }
    return $null
  }
  Get-ChildItem -LiteralPath $LogsDir -File -Filter "$Prefix*$Ext" |
    Where-Object { $_.Length -gt 0 } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

Write-Section 'JIT'
$jitFile = Find-SessionFile -Prefix 'jvm-jit-' -Ext '.log' -Stamp $stamp
if (-not $jitFile) {
  'No JIT log for this session (only present with the Diagnose preset). Skipped.'
} else {
  "File: $($jitFile.Name) ($([math]::Round($jitFile.Length / 1MB, 1)) MB)"
  $rxJit = '^\[[^\]]*\]\[(\d+\.\d+)s\](?:\[[^\]]*\])*\s*(\d+)\s+[%sb!n ]*?(\d)\s+(\S+)\s+\((\d+) bytes\)(.*)$'
  $tier4 = @{}; $traps = @{}
  $reasons = @{}; $methods = @{}; $pkgs = @{}
  $compiles = 0; $notEntrant = 0; $trapCount = 0
  foreach ($line in (Read-SharedLine $jitFile.FullName)) {
    if ($line -notmatch $rxJit) { continue }
    $bucket = [int]([math]::Floor((ConvertTo-Double $Matches[1]) / 300)) * 5
    $tier = $Matches[3]; $method = $Matches[4]; $tail = $Matches[6]
    if ($tail -match 'made not entrant') {
      $notEntrant++
      $r = if ($tail -match 'made not entrant: (.+)$') { $Matches[1].Trim() } else { '(no reason)' }
      $reasons[$r] = 1 + [int]$reasons[$r]
      if ($r -match 'uncommon trap') {
        $trapCount++
        $traps[$bucket] = 1 + [int]$traps[$bucket]
        $methods[$method] = 1 + [int]$methods[$method]
        $parts = ($method -replace '::.*$', '') -split '\.'
        $pkg = $parts[0..([math]::Min(1, $parts.Count - 1))] -join '.'
        $pkgs[$pkg] = 1 + [int]$pkgs[$pkg]
      }
    } else {
      $compiles++
      if ($tier -eq '4') { $tier4[$bucket] = 1 + [int]$tier4[$bucket] }
    }
  }
  "Compiles $compiles, made not entrant $notEntrant, of which uncommon-trap deopts $trapCount"
  $fmt = { param($h) ($h.GetEnumerator() | Sort-Object Name | Select-Object -First 24 | ForEach-Object { "$($_.Name)m:$($_.Value)" }) -join ' ' }
  "Tier-4 (C2/Graal) compiles per 5 min: $(& $fmt $tier4)"
  "Uncommon-trap deopts per 5 min:        $(& $fmt $traps)"
  'Top not-entrant reasons:'
  $reasons.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5 | ForEach-Object { '  {0,6}x {1}' -f $_.Value, $_.Name }
  'Most deoptimized methods:'
  $methods.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 8 | ForEach-Object { '  {0,4}x {1}' -f $_.Value, $_.Name }
  'Deopts by package:'
  $pkgs.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 6 | ForEach-Object { '  {0,5}x {1}' -f $_.Value, $_.Name }
}

# --- JFR ---------------------------------------------------------------------
Write-Section 'JFR'
$jfrStamp = if ($stamp) { $stamp -replace '-', '_' } else { $null }
$jfrFile = if ($JfrPath) { Get-Item -LiteralPath $JfrPath } else { Find-SessionFile -Prefix 'stutter-' -Ext '.jfr' -Stamp $jfrStamp }
if ($NoJfr) {
  'Skipped (-NoJfr).'
} elseif (-not $jfrFile) {
  'No .jfr for this session (zero-byte means the JVM never wrote it; quit the game normally for dumponexit). Skipped.'
} elseif (-not (Test-Path -LiteralPath $jfrExe)) {
  "jfr.exe not found next to JavaPath ($jfrExe). Skipped."
} else {
  "File: $($jfrFile.Name) ($([math]::Round($jfrFile.Length / 1MB, 1)) MB; maxage=30m keeps only the last 30 min)"
  # name, lines to keep (title + header + rows)
  foreach ($view in @(@('gc-pauses', 18), @('hot-methods', 20), @('longest-compilations', 14), @('deoptimizations-by-reason', 12), @('thread-cpu-load', 16))) {
    "--- $($view[0])"
    & $jfrExe view --width 190 --truncate end $view[0] $jfrFile.FullName 2>&1 |
      ForEach-Object { "$_" } | Where-Object { $_.Trim() } | Select-Object -First $view[1]
  }
}
