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
