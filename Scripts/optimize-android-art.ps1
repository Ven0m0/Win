#Requires -Version 5.1

<#
.SYNOPSIS
  Clean up an Android phone over adb and recompile apps with tuned ART compiler filters.
.DESCRIPTION
  Rerun after app or system updates, because updates reset the compiler filter.

  Steps:
    1. Cleanup: fstrim, idle maintenance, ART artifact cleanup, cache trim, external app caches.
    2. Base: every installed package (user 0) with speed-profile. Uses a per-package loop because
       'pm compile -a' aborts on the first package that is uninstalled for the user but still registered.
    3. Full AOT: $FullAotPackages with everything-profile. Apps without a profile fall back to verify
       (no AOT code), so those are recompiled with speed, which needs no profile.
    4. Profile-only: $ProfileOnlyPackages (GMS) stay on speed-profile.
    5. Report the resulting status of every package from steps 3 and 4.

  Needs adb in PATH and USB/wireless debugging enabled. No root needed.
.PARAMETER Serial
  adb device serial. Optional when only one device is connected.
.PARAMETER SkipCleanup
  Skip step 1.
.PARAMETER SkipBase
  Skip step 2 (the slowest step).
.EXAMPLE
  .\optimize-android-art.ps1
.EXAMPLE
  .\optimize-android-art.ps1 -SkipCleanup -SkipBase
  Only recompile the tuned app lists, e.g. after a few app updates.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$Serial,
  [switch]$SkipCleanup,
  [switch]$SkipBase
)

. "$PSScriptRoot\Common.ps1"

# Apps used daily: full AOT plus app image for the fastest cold start.
$FullAotPackages = @(
  # System
  'com.android.systemui', 'com.nothing.launcher', 'com.android.settings', 'com.nothing.camera'
  # WebView and browsers
  'com.google.android.webview.beta', 'io.github.jqssun.helium', 'com.brave.browser_beta'
  'io.github.forkmaintainers.iceraven'
  # Media
  'app.morphe.android.youtube', 'app.morphe.android.apps.youtube.music', 'com.vivi.vivimusic'
  'com.arn.scrobble'
  # Messaging and social
  'dev.shiggy.cord', 'com.whatsapp', 'com.instafel.android', 'com.snapchat.android'
  'com.zhiliaoapp.musically', 'com.reddit.frontpage'
  # Tools
  'com.leanbitlab.leantype', 'com.hamondev.shevery', 'com.google.android.apps.maps'
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

function Invoke-BaseCompile {
  # Runs on the device in one adb call; no double quotes so Windows argument quoting stays out of the way.
  $flags = $CompileFlags -join ' '
  $remote = "for p in `$(pm list packages --user 0 | cut -d: -f2); do " +
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
  Test-AdbDevice
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
