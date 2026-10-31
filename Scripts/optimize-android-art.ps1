#Requires -Version 5.1

<#
.SYNOPSIS
  Clean up an Android phone over adb and recompile apps with tuned ART compiler filters.
.DESCRIPTION
  Rerun after app or system updates, because updates reset the compiler filter.

  Steps:
    1. Cleanup: fstrim, idle maintenance, ART artifact cleanup, cache trim, external app caches.
    2. Base: every installed package (user 0) except the tuned lists, with speed-profile. Uses a per-package
       loop because 'pm compile -a' aborts on the first package that is uninstalled for the user but still
       registered.
    3. Full AOT: $FullAotPackages with everything-profile. Apps without a profile fall back to verify
       (no AOT code), so those are recompiled with speed, which needs no profile.
    4. Profile-only: $ProfileOnlyPackages (GMS) stay on speed-profile.
    5. Report the resulting status of every package from steps 3 and 4.

  Optional display tuning (only when -SessionProps is passed) runs before the compile steps.

  Needs adb in PATH and USB/wireless debugging enabled. No root needed.
.PARAMETER Serial
  adb device serial. Optional when only one device is connected.
.PARAMETER SkipCleanup
  Skip step 1.
.PARAMETER SkipBase
  Skip step 2 (the slowest step).
.PARAMETER SessionProps
  Switch HWUI and RenderEngine to Vulkan (skiavk) with the same properties as the APO app's SkiaVK option.
  Some apps misrender with it.
.PARAMETER DisableAA
  Turn off forced SSAA/SMAA/TAA/MSAA/FXAA (APO "Disable AA").
.PARAMETER DisableVSync
  Set the swap-interval/vsync debug properties to 0 (APO "Disable V-Sync"). Can cause tearing.
.PARAMETER GpuAccel
  Enable hardware acceleration debug properties plus performance tuning (APO "GPU & Hardware Accel").
.PARAMETER Snapdragon
  With -GpuAccel, also enable UBWC framebuffers (Qualcomm SoCs only).
.PARAMETER TouchTuning
  Apply the APO touch optimization properties. -TouchTimerMs sets the SurfaceFlinger touch timer.
.PARAMETER RamGb
  Apply the APO HWUI cache sizes for a device with this much RAM (2, 3, 4, 6, 8, 12, 16 or 24).

  Any of the tuning switches above (and -SessionProps) sets properties that reset on reboot, then force-stops
  every app and restarts SystemUI so they take effect, like the APO app does.
.EXAMPLE
  .\optimize-android-art.ps1
.EXAMPLE
  .\optimize-android-art.ps1 -SkipCleanup -SkipBase
  Only recompile the tuned app lists, e.g. after a few app updates.
.EXAMPLE
  .\optimize-android-art.ps1 -SkipCleanup -SkipBase -SessionProps
  Enable Vulkan rendering (restarts SystemUI).
.EXAMPLE
  .\optimize-android-art.ps1 -SkipCleanup -SkipBase -SessionProps -DisableAA -DisableVSync -GpuAccel -RamGb 8
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$Serial,
  [switch]$SkipCleanup,
  [switch]$SkipBase,
  [switch]$SessionProps,
  [switch]$DisableAA,
  [switch]$DisableVSync,
  [switch]$GpuAccel,
  [switch]$Snapdragon,
  [switch]$TouchTuning,
  [ValidateRange(1, 5000)][int]$TouchTimerMs = 200,
  [ValidateSet(2, 3, 4, 6, 8, 12, 16, 24)][int]$RamGb
)

. "$PSScriptRoot\Common.ps1"

# Apps used daily: full AOT plus app image for the fastest cold start.
$FullAotPackages = @(
  # System
  'com.android.systemui', 'com.nothing.launcher', 'com.android.settings', 'com.nothing.camera'
  # WebView and browsers
  'com.google.android.webview.beta', 'io.github.jqssun.helium', 'com.brave.browser'
  'io.github.forkmaintainers.iceraven'
  # Media
  'app.morphe.android.youtube', 'app.morphe.android.apps.youtube.music', 'com.vivi.vivimusic'
  'com.arn.scrobble'
  # Messaging and social
  'com.discord.venus', 'com.whatsapp', 'com.instafel.android', 'com.snapchat.android'
  'com.zhiliaoapp.musically', 'com.reddit.frontpage'
  # Tools
  'com.leanbitlab.leantype', 'af.shizuku.plus.api', 'com.google.android.apps.maps'
  'me.zhanghai.android.files', 'org.fossify.gallery', 'com.nextcloud.client'
  # Background and critical
  'org.breezyweather', 'app.revanced.android.gms', 'com.x8bit.bitwarden', 'com.freestylelibre3.app.de'
)

# Huge, updated weekly: full AOT would cost hundreds of MB and be reset by the next update.
$ProfileOnlyPackages = @('com.google.android.gms')

$CompileFlags = @('--full', '-r', 'cmdline', '-p', 'PRIORITY_INTERACTIVE_FAST')

function Invoke-Adb {
  $serialArgs = if ($Serial) { @('-s', $Serial) } else { @() }
  # pm writes Failure and warnings to stderr; under Stop, Windows PowerShell 5.1 would throw on them.
  $ErrorActionPreference = 'Continue'
  $output = & adb @serialArgs @args 2>&1
  $output | ForEach-Object -Process { "$_" }
}

function Get-ArtFilterStatus {
  <#
  .SYNOPSIS
    Returns the compiler filter of the primary dex from 'pm art dump' output, or 'none'.
  #>
  param([string[]]$DumpText)
  $match = [regex]::Match(($DumpText -join "`n"), 'status=([a-z-]+)')
  if ($match.Success) { $match.Groups[1].Value } else { 'none' }
}

function Invoke-PackageCompile {
  param([string]$Package, [string]$Filter)
  $result = Invoke-Adb shell pm compile @CompileFlags -m $Filter $Package | Select-Object -Last 1
  $status = Get-ArtFilterStatus -DumpText (Invoke-Adb shell pm art dump $Package)
  [pscustomobject]@{ Package = $Package; Result = $result; Status = $status }
}

function Test-AdbDevice {
  if (-not (Get-Command -Name adb -ErrorAction SilentlyContinue)) {
    throw 'adb not found in PATH. Install platform-tools (scoop install adb) and retry.'
  }
  $state = Invoke-Adb get-state
  if ("$state" -ne 'device') {
    throw "No usable adb device (state: $state). Connect the phone, enable debugging, accept the prompt."
  }
}

function Invoke-DeviceCleanup {
  # External app caches only; files/cache is skipped because some apps keep real data there.
  # /data/anr, /data/tombstones, /data/system/dropbox need root and are not touched.
  $remote = 'sm fstrim; sm idle-maint run; pm art cleanup; pm trim-caches 999G; ' +
    'rm -rf /sdcard/Android/data/*/cache/* /sdcard/Android/data/*/code_cache/* ' +
    '/sdcard/Android/data/*/files/tombstones/* /data/local/tmp/*; ' +
    'am broadcast -a com.android.systemui.action.CLEAR_MEMORY >/dev/null; ' +
    'am broadcast -a android.intent.action.ACTION_OPTIMIZE_DEVICE >/dev/null'
  Invoke-Adb shell $remote | Where-Object -FilterScript { $_ } | ForEach-Object -Process { Write-Info $_ }
}

# HWUI cache sizes per device RAM (GB), copied from the APO app:
# text small W/H, text large W/H, layer, path, texture, r-buffer, drop shadow, texture flush rate.
$RamProfiles = @{
  2  = 512, 512, 1024, 512, 24, 16, 32, 4, 2, 0.3
  3  = 512, 512, 1024, 512, 32, 16, 48, 4, 3, 0.35
  4  = 1024, 512, 1024, 1024, 48, 24, 64, 6, 4, 0.4
  6  = 1024, 512, 2048, 1024, 64, 32, 72, 6, 5, 0.4
  8  = 1024, 1024, 2048, 1024, 96, 48, 96, 8, 6, 0.45
  12 = 1024, 1024, 2048, 1024, 128, 64, 128, 8, 8, 0.5
  16 = 2048, 1024, 2048, 2048, 160, 96, 160, 8, 10, 0.5
  24 = 2048, 1024, 2048, 2048, 192, 128, 192, 8, 12, 0.5
}

function Get-DisplayTuningCommand {
  <#
  .SYNOPSIS
    Returns the device shell commands for the selected tuning switches (same sets as the APO app).
  #>
  [OutputType([string[]])]
  param()
  $commands = [System.Collections.Generic.List[string]]::new()
  if ($SessionProps) {
    $commands.AddRange([string[]]@(
        'device_config put systemui enable_hw_accelerated_canvas true'
        'settings put global render_shadows_in_compositor 1'
        'setprop debug.hwui.renderer skiavk'
        'setprop debug.hwui.default_renderer skiavk'
        'setprop debug.renderengine.backend skiavkthreaded'
        'setprop debug.hwui.renderengine.backend skiavkthreaded'
        'setprop debug.hwui.use_vulkan true'
        'setprop debug.hwui.force_vulkan true'
        'setprop debug.hwui.disable_opengl true'
        'setprop debug.skia.vulkan_as_default true'
        'setprop debug.sf.enable_hwc_vulkan true'
        'setprop debug.renderthread.skia.reduceopstasksplitting true'
        'setprop debug.renderengine.capture_skia_ms 0'
        'setprop debug.renderengine.skia_atrace_enabled false'
        'setprop debug.hwui.skia_use_perfetto_track_events false'
        'setprop debug.hwui.skia_tracing_enabled false'
      ))
  }
  if ($DisableAA) {
    foreach ($mode in 'ssaa', 'smaa', 'taa', 'msaa', 'fxaa') {
      $commands.Add("setprop debug.egl.force_$mode false")
    }
  }
  if ($DisableVSync) {
    $commands.AddRange([string[]]@(
        'setprop debug.egl.swapinterval 0'
        'setprop debug.gr.swapinterval 0'
        'setprop debug.gpurend.vsync false'
        'setprop debug.hwui.disable_vsync true'
      ))
  }
  if ($GpuAccel) {
    if ($Snapdragon) { $commands.Add('setprop debug.gralloc.enable_fb_ubwc 1') }
    $commands.AddRange([string[]]@(
        'setprop debug.performance.tuning 1'
        'setprop debug.sf.hw 1'
        'setprop debug.video.accelerate.hw 1'
      ))
  }
  if ($TouchTuning) {
    $commands.AddRange([string[]]@(
        'setprop debug.sf.touch_latency_opt 1'
        "setprop debug.sf.set_touch_timer_ms $TouchTimerMs"
        'setprop touch.deviceType touchScreen'
        'setprop touch.gestureMode spots'
        'setprop touch.orientation.calibration none'
        'setprop touch.pressure.calibration amplitude'
        'setprop touch.pressure.scale 0.001'
        'setprop touch.size.calibration diameter'
        'setprop touch.size.scale 1'
        'setprop touch.size.bias 0'
        'setprop touch.size.isSummed 0'
        'setprop MultitouchSettleInterval 1ms'
        'setprop MultitouchMinDistance 1px'
        'setprop TapInterval 1ms'
        'setprop TapSlop 1px'
      ))
  }
  if ($RamGb) {
    $r = $RamProfiles[[int]$RamGb]
    $names = 'text_small_cache_width', 'text_small_cache_height', 'text_large_cache_width',
    'text_large_cache_height', 'layer_cache_size', 'path_cache_size', 'texture_cache_size',
    'r_buffer_cache_size', 'gradient_cache_size', 'drop_shadow_cache_size', 'texture_cache_flushrate'
    $values = $r[0..7] + 1 + $r[8..9]
    for ($i = 0; $i -lt $names.Count; $i++) {
      $commands.Add("setprop debug.hwui.$($names[$i]) $($values[$i])")
    }
  }
  $commands.ToArray()
}

function Set-DisplayTuning {
  $commands = @(Get-DisplayTuningCommand)
  if ($commands.Count -eq 0) { return }
  Write-Warn 'Tuning resets on reboot; all apps are force-stopped and SystemUI restarts to apply it'
  # Reload like the APO app: apps and SystemUI only read these properties at start.
  $reload = 'for p in $(pm list packages | cut -d: -f2); do am force-stop $p; done; am crash com.android.systemui'
  $remote = ($commands -join '; ') + '; ' + $reload
  Invoke-Adb shell $remote | Where-Object -FilterScript { $_ } | ForEach-Object -Process { Write-Info $_ }
}

function Invoke-BaseCompile {
  # Runs on the device in one adb call; no double quotes so Windows argument quoting stays out of the way.
  # The tuned lists are left out because Invoke-TunedCompile recompiles them and would discard this work.
  $flags = $CompileFlags -join ' '
  $exclude = (($FullAotPackages + $ProfileOnlyPackages) | ForEach-Object -Process { "-e $_" }) -join ' '
  $remote = "for p in `$(pm list packages --user 0 | cut -d: -f2 | grep -vxF $exclude); do " +
    "r=`$(pm compile $flags -m speed-profile `$p 2>&1 | tail -n 1); echo `$p `$r; done"
  $lines = Invoke-Adb shell $remote
  $failed = @($lines | Where-Object -FilterScript { $_ -notmatch ' Success$' })
  Write-Info "Base compile: $($lines.Count - $failed.Count) of $($lines.Count) packages succeeded"
  $failed | ForEach-Object -Process { Write-Warn $_ }
}

function Invoke-TunedCompile {
  $installed = Invoke-Adb shell pm list packages --user 0 | ForEach-Object -Process { $_ -replace '^package:', '' }
  $results = foreach ($package in $FullAotPackages + $ProfileOnlyPackages) {
    if ($package -notin $installed) {
      Write-Warn "$package is not installed, skipped"
      continue
    }
    if ($package -in $ProfileOnlyPackages) {
      Invoke-PackageCompile -Package $package -Filter 'speed-profile'
      continue
    }
    $entry = Invoke-PackageCompile -Package $package -Filter 'everything-profile'
    if ($entry.Status -ne 'everything-profile') {
      # No profile yet: speed gives full AOT without one.
      $entry = Invoke-PackageCompile -Package $package -Filter 'speed'
    }
    $entry
  }
  $results
}

function Start-AndroidArtOptimization {
  [CmdletBinding(SupportsShouldProcess)]
  param()

  Test-AdbDevice
  $tuning = $SessionProps -or $DisableAA -or $DisableVSync -or $GpuAccel -or $TouchTuning -or $RamGb
  if ($tuning -and $PSCmdlet.ShouldProcess('device', 'Apply display tuning')) {
    Write-Phase 'Display tuning'
    Set-DisplayTuning
  }
  if (-not $SkipCleanup -and $PSCmdlet.ShouldProcess('device', 'Clean up caches and storage')) {
    Write-Phase 'Cleanup'
    Invoke-DeviceCleanup
  }
  if (-not $SkipBase -and $PSCmdlet.ShouldProcess('all packages', 'Compile with speed-profile')) {
    Write-Phase 'Base compile (speed-profile, all packages, takes several minutes)'
    Invoke-BaseCompile
  }
  if (-not $PSCmdlet.ShouldProcess('tuned package lists', 'Compile with everything-profile/speed')) {
    return
  }
  Write-Phase 'Tuned compile'
  $results = Invoke-TunedCompile
  $results | Format-Table -AutoSize | Out-String | Write-Host
  $bad = @($results | Where-Object -FilterScript { $_.Status -notin 'everything-profile', 'speed', 'speed-profile' })
  if ($bad.Count -gt 0) {
    Write-Fail "Unexpected status: $($bad.Package -join ', ')"
    return 1
  }
  Write-Success "All $(@($results).Count) tuned packages compiled"
  return 0
}

if ($MyInvocation.InvocationName -ne '.') {
  exit (Start-AndroidArtOptimization)
}
