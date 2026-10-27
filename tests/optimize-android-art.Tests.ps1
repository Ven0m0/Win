#Requires -Version 5.1

BeforeAll {
  Import-Module Pester -MinimumVersion 5.0
  . "$PSScriptRoot/../Scripts/optimize-android-art.ps1"
}

Describe 'Get-ArtFilterStatus' {
  It 'returns the primary dex filter from pm art dump output' {
    $dump = @(
      '[com.google.android.gms]'
      '  path: /data/app/~~x==/com.google.android.gms-y==/base.apk'
      '    arm64: [status=speed-profile] [reason=cmdline] [primary-abi]'
      '  path: /data/user/0/com.google.android.gms/app_chimera/m/00000001/dl-Module.apk'
      '    arm64: [status=verify] [reason=cmdline] [primary-abi]'
    )
    Get-ArtFilterStatus -DumpText $dump | Should -Be 'speed-profile'
  }

  It 'keeps hyphenated filter names intact' {
    Get-ArtFilterStatus -DumpText '    arm64: [status=run-from-apk] [reason=unknown]' | Should -Be 'run-from-apk'
  }

  It 'returns none when the package has no dex status' {
    Get-ArtFilterStatus -DumpText '[com.nothing.wallpaper.overlay.config]' | Should -Be 'none'
  }
}

Describe 'Invoke-TunedCompile' {
  BeforeAll {
    Mock Write-Warn { }
  }

  It 'falls back to speed when everything-profile ends on verify' {
    Mock Invoke-Adb { 'package:dev.shiggy.cord' }
    Mock Invoke-PackageCompile {
      $status = if ($Filter -eq 'everything-profile') { 'verify' } else { $Filter }
      [pscustomobject]@{ Package = $Package; Result = 'Success'; Status = $status }
    }
    $results = @(Invoke-TunedCompile)
    $results.Count | Should -Be 1
    $results[0].Status | Should -Be 'speed'
    Should -Invoke Invoke-PackageCompile -Times 2 -Exactly
  }

  It 'keeps profile-only packages on speed-profile' {
    Mock Invoke-Adb { 'package:com.google.android.gms' }
    Mock Invoke-PackageCompile {
      [pscustomobject]@{ Package = $Package; Result = 'Success'; Status = $Filter }
    }
    $results = @(Invoke-TunedCompile)
    $results[0].Status | Should -Be 'speed-profile'
    Should -Invoke Invoke-PackageCompile -Times 1 -Exactly -ParameterFilter { $Filter -eq 'speed-profile' }
  }
}

# adb is never run: it is a stub function here, and every Describe below mocks Invoke-Adb or adb itself.
Describe 'Invoke-Adb' {
  BeforeAll {
    function adb { param([Parameter(ValueFromRemainingArguments)]$Rest) }
  }

  It 'passes arguments through to adb without a serial by default' {
    Mock adb { 'out' }
    $Serial = $null

    Invoke-Adb shell echo hi | Should -Be 'out'

    Should -Invoke adb -Times 1 -Exactly -ParameterFilter {
      $Rest -contains 'shell' -and $Rest -contains 'echo' -and $Rest -notcontains '-s'
    }
  }

  It 'prefixes -s <serial> when a serial is set' {
    Mock adb { }
    $Serial = 'ABC123'

    $null = Invoke-Adb get-state

    Should -Invoke adb -Times 1 -Exactly -ParameterFilter {
      $Rest[0] -eq '-s' -and $Rest[1] -eq 'ABC123' -and $Rest -contains 'get-state'
    }
  }

  It 'returns stderr lines as plain strings instead of error records' {
    Mock adb { Write-Error 'Failure [INSTALL_FAILED]' -ErrorAction Continue; 'line' }
    $Serial = $null

    $out = @(Invoke-Adb shell pm compile)

    $out | ForEach-Object { $_ | Should -BeOfType [string] }
    $out | Should -Contain 'line'
  }
}

Describe 'Test-AdbDevice' {
  It 'throws a clear message when adb is not in PATH' {
    Mock Get-Command { $null } -ParameterFilter { $Name -eq 'adb' }

    { Test-AdbDevice } | Should -Throw '*adb not found in PATH*'
  }

  It 'throws when the device state is not "device"' {
    Mock Get-Command { [pscustomobject]@{ Name = 'adb' } } -ParameterFilter { $Name -eq 'adb' }
    Mock Invoke-Adb { 'unauthorized' }

    { Test-AdbDevice } | Should -Throw '*No usable adb device (state: unauthorized)*'
  }

  It 'passes when exactly one device is ready' {
    Mock Get-Command { [pscustomobject]@{ Name = 'adb' } } -ParameterFilter { $Name -eq 'adb' }
    Mock Invoke-Adb { 'device' }

    { Test-AdbDevice } | Should -Not -Throw
  }
}

Describe 'Invoke-PackageCompile' {
  It 'compiles with the requested filter and reports the resulting status' {
    Mock Invoke-Adb { 'Success' } -ParameterFilter { $args -contains 'compile' }
    Mock Invoke-Adb { '    arm64: [status=speed] [reason=cmdline]' } -ParameterFilter { $args -contains 'dump' }

    $entry = Invoke-PackageCompile -Package 'com.example.app' -Filter 'speed'

    $entry.Package | Should -Be 'com.example.app'
    $entry.Result | Should -Be 'Success'
    $entry.Status | Should -Be 'speed'
    Should -Invoke Invoke-Adb -Times 1 -Exactly -ParameterFilter {
      $args -contains '-m' -and $args -contains 'speed' -and $args -contains 'com.example.app'
    }
  }
}

Describe 'Invoke-DeviceCleanup' {
  BeforeAll {
    Mock Write-Info { }
  }

  It 'sends a single adb shell command that trims, cleans ART and external caches' {
    Mock Invoke-Adb { }

    Invoke-DeviceCleanup

    Should -Invoke Invoke-Adb -Times 1 -Exactly -ParameterFilter {
      $args[0] -eq 'shell' -and $args[1] -like '*sm fstrim*' -and $args[1] -like '*pm art cleanup*' -and
      $args[1] -like '*pm trim-caches*'
    }
  }

  It 'sends the undocumented CLEAR_MEMORY and ACTION_OPTIMIZE_DEVICE broadcasts' {
    Mock Invoke-Adb { }

    Invoke-DeviceCleanup

    Should -Invoke Invoke-Adb -Times 1 -Exactly -ParameterFilter {
      $args[1] -like '*am broadcast -a com.android.systemui.action.CLEAR_MEMORY*' -and
      $args[1] -like '*am broadcast -a android.intent.action.ACTION_OPTIMIZE_DEVICE*'
    }
  }

  It 'never deletes app data outside cache folders' {
    Mock Invoke-Adb { }

    Invoke-DeviceCleanup

    Should -Invoke Invoke-Adb -Times 0 -Exactly -ParameterFilter { $args[1] -like '*files/cache*' }
    Should -Invoke Invoke-Adb -Times 0 -Exactly -ParameterFilter { $args[1] -like '*/data/data*' }
  }

  It 'echoes non-empty device output only' {
    Mock Invoke-Adb { 'Success', '', 'done' }

    Invoke-DeviceCleanup

    Should -Invoke Write-Info -Times 2 -Exactly
  }
}

Describe 'Invoke-BaseCompile' {
  BeforeAll {
    Mock Write-Info { }
    Mock Write-Warn { }
  }

  It 'reports the success count and warns about each failed package' {
    Mock Invoke-Adb { 'com.a Success', 'com.b Failure', 'com.c Success' }

    Invoke-BaseCompile

    Should -Invoke Write-Info -Times 1 -Exactly -ParameterFilter { $Text -like '*2 of 3 packages succeeded*' }
    Should -Invoke Write-Warn -Times 1 -Exactly -ParameterFilter { $Text -eq 'com.b Failure' }
  }

  It 'runs one speed-profile loop on the device in a single adb call' {
    Mock Invoke-Adb { 'com.a Success' }

    Invoke-BaseCompile

    Should -Invoke Invoke-Adb -Times 1 -Exactly -ParameterFilter {
      $args[0] -eq 'shell' -and $args[1] -like '*pm list packages --user 0*-m speed-profile*'
    }
  }
}

Describe 'Invoke-BaseCompile (exclusions)' {
  It 'leaves the tuned lists to Invoke-TunedCompile' {
    Mock Write-Info { }
    Mock Write-Warn { }
    Mock Invoke-Adb { 'com.a Success' }

    Invoke-BaseCompile

    Should -Invoke Invoke-Adb -Times 1 -Exactly -ParameterFilter {
      $args[1] -like '*grep -vxF*-e com.whatsapp*' -and $args[1] -like '* -e com.google.android.gms*'
    }
  }
}

Describe 'Invoke-TunedCompile (not installed)' {
  It 'skips and warns about packages that are not installed' {
    Mock Write-Warn { }
    Mock Invoke-Adb { 'package:com.something.else' }
    Mock Invoke-PackageCompile { }

    $results = @(Invoke-TunedCompile)

    $results.Count | Should -Be 0
    Should -Invoke Invoke-PackageCompile -Times 0 -Exactly
    Should -Invoke Write-Warn -ParameterFilter { $Text -like '*is not installed, skipped' }
  }

  It 'keeps everything-profile when the first attempt reaches it' {
    Mock Write-Warn { }
    Mock Invoke-Adb { 'package:com.whatsapp' }
    Mock Invoke-PackageCompile {
      [pscustomobject]@{ Package = $Package; Result = 'Success'; Status = $Filter }
    }

    $results = @(Invoke-TunedCompile)

    $results[0].Status | Should -Be 'everything-profile'
    Should -Invoke Invoke-PackageCompile -Times 1 -Exactly
  }
}

Describe 'Start-AndroidArtOptimization' {
  BeforeAll {
    Mock Test-AdbDevice { }
    Mock Invoke-DeviceCleanup { }
    Mock Invoke-BaseCompile { }
    Mock Write-Phase { }
    Mock Write-Success { }
    Mock Write-Fail { }
    Mock Write-Host { }
  }

  BeforeEach {
    $SkipCleanup = [switch]$false
    $SkipBase = [switch]$false
    Mock Invoke-TunedCompile {
      [pscustomobject]@{ Package = 'com.a'; Result = 'Success'; Status = 'speed' }
    }
  }

  It 'runs cleanup, base and tuned compile, then returns 0' {
    Start-AndroidArtOptimization | Should -Be 0

    Should -Invoke Test-AdbDevice -Times 1 -Exactly
    Should -Invoke Invoke-DeviceCleanup -Times 1 -Exactly
    Should -Invoke Invoke-BaseCompile -Times 1 -Exactly
    Should -Invoke Invoke-TunedCompile -Times 1 -Exactly
  }

  It 'skips cleanup and base with -SkipCleanup / -SkipBase' {
    $SkipCleanup = [switch]$true
    $SkipBase = [switch]$true

    Start-AndroidArtOptimization | Should -Be 0

    Should -Invoke Invoke-DeviceCleanup -Times 0 -Exactly
    Should -Invoke Invoke-BaseCompile -Times 0 -Exactly
    Should -Invoke Invoke-TunedCompile -Times 1 -Exactly
  }

  It 'does nothing destructive under -WhatIf' {
    Start-AndroidArtOptimization -WhatIf

    Should -Invoke Invoke-DeviceCleanup -Times 0 -Exactly
    Should -Invoke Invoke-BaseCompile -Times 0 -Exactly
    Should -Invoke Invoke-TunedCompile -Times 0 -Exactly
  }

  It 'returns 1 and names packages whose final status is unexpected' {
    Mock Invoke-TunedCompile {
      [pscustomobject]@{ Package = 'com.bad'; Result = 'Success'; Status = 'verify' }
    }

    Start-AndroidArtOptimization | Should -Be 1

    Should -Invoke Write-Fail -Times 1 -Exactly -ParameterFilter { $Text -like '*com.bad*' }
    Should -Invoke Write-Success -Times 0 -Exactly
  }

  It 'propagates a missing-device error before doing any work' {
    Mock Test-AdbDevice { throw 'No usable adb device' }

    { Start-AndroidArtOptimization } | Should -Throw '*No usable adb device*'
    Should -Invoke Invoke-DeviceCleanup -Times 0 -Exactly
  }
}
