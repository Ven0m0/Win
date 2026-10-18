#Requires -Version 5.1

BeforeDiscovery {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $script:notAdmin = -not ([Security.Principal.WindowsPrincipal]$identity).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
}

BeforeAll {
  Import-Module Pester -MinimumVersion 5.0
  function ipconfig {}
  . "$PSScriptRoot/../Scripts/arc-raiders/cleanup-arc-raiders.ps1"
}

Describe "Cleanup-ArcRaiders Script Initialization" {
  It "Should safely source the script" {
    $true | Should -Be $true
  }

  It "Should export the Remove-Glob function" {
    $func = Get-Command -Name "Remove-Glob" -ErrorAction SilentlyContinue
    $func | Should -Not -BeNullOrEmpty
    $func.CommandType | Should -Be "Function"
  }
}

Describe "Cleanup-ArcRaiders Functions" {
  BeforeAll {
    function Write-Host {}
    function ipconfig {}
    # Storage-module CDXML cmdlets cannot be Pester-mocked: their generated
    # proxies reference dynamic types (e.g. Get-PhysicalDisk.PhysicalDiskUsage)
    # that fail to parse. Plain stub functions shadow them instead.
    function Get-Volume { return @() }
    function Get-PhysicalDisk {}
    function Optimize-Volume {}
    Mock Write-Host {}
    Mock Get-Item { return @() }
    Mock Get-Process {}
    Mock ipconfig {}
    Mock DISM {}
    Mock Start-Process {}
    Mock Set-ItemProperty {}
    Mock New-Item {}
  }

  It "Should run Remove-Glob without errors when no items match" {
    Mock Get-Item { return @() }
    { Remove-Glob -Pattern "$env:TEMP\nonexistent\*" } | Should -Not -Throw
  }
}

# The script body deletes caches, runs DISM and trims memory on the live system, so it is only invoked here
# with every one of those commands mocked (Invoke-GlobClean, Remove-Glob and Remove-Item are all neutralised
# as defence in depth). '#Requires -RunAsAdministrator' means it can only run from an elevated session.
Describe "Cleanup-ArcRaiders main flow" -Skip:$notAdmin {
  BeforeAll {
    $script:scriptPath = (Resolve-Path -Path "$PSScriptRoot/../Scripts/arc-raiders/cleanup-arc-raiders.ps1").Path
  }

  BeforeEach {
    # Mock bodies run in the invoked script's scope; share state through a reference object found by
    # dynamic scoping.
    $arc = @{
      Globs     = [System.Collections.Generic.List[string]]::new()
      Dism      = [System.Collections.Generic.List[string]]::new()
      Ipconfig  = [System.Collections.Generic.List[string]]::new()
      Steam     = $null
      SteamPath = 'D:/Games/Steam'
    }

    Mock Invoke-GlobClean { $arc.Globs.Add($Pattern) }
    Mock Remove-Glob { }
    Mock Remove-Item { }
    Mock Get-Process { $arc.Steam } -ParameterFilter { $Name -eq 'steam' }
    Mock Stop-Process { }
    Mock Start-Sleep { }
    Mock Get-ItemProperty {
      if ($arc.SteamPath) { [pscustomobject]@{ SteamPath = $arc.SteamPath } } else { throw 'no key' }
    }
    Mock ipconfig.exe { $arc.Ipconfig.Add((@($args | ForEach-Object { $_ }) -join ' ')) }
    Mock DISM.exe {
      $arc.Dism.Add((@($args | ForEach-Object { $_ }) -join ' '))
      'The operation completed successfully.'
    }
    Mock rundll32.exe { }
    Mock Test-Path { $false } -ParameterFilter {
      $Path -like '*directxdatabaseupdater.exe' -or $Path -like '*dxgiadaptercache.exe'
    }
    Mock Start-Process { }
    Mock Invoke-MemoryTrim { }
    Mock Optimize-FixedVolume { }
    Mock Write-ArcSummary { }
    Mock Write-Host { }
  }

  It "Cleans the Arc Raiders, Windows, NVIDIA and AMD/Intel cache locations" {
    & $scriptPath

    $arc.Globs | Should -Contain "$env:LOCALAPPDATA\PioneerGame\Saved\Logs\*"
    $arc.Globs | Should -Contain "$env:windir\Prefetch\*"
    $arc.Globs | Should -Contain "$env:LOCALAPPDATA\NVIDIA\DXCache\*"
    $arc.Globs | Should -Contain "$env:LOCALAPPDATA\AMD\VkCache\*"
    $arc.Globs | Should -Contain "$env:LOCALAPPDATA\Intel\ShaderCache\*"
  }

  It "Cleans the Windows and user temp folders twice (before and after the DirectX rebuild)" {
    & $scriptPath

    @($arc.Globs | Where-Object { $_ -eq "$env:TEMP\*" }).Count | Should -Be 2
    @($arc.Globs | Where-Object { $_ -eq "$env:windir\Temp\*" }).Count | Should -Be 2
  }

  It "Never deletes anything itself, only through Invoke-GlobClean" {
    & $scriptPath

    Should -Invoke Remove-Item -Times 0 -Exactly
    Should -Invoke Remove-Glob -Times 0 -Exactly
  }

  It "Cleans the Steam caches under the registry SteamPath with slashes normalised" {
    & $scriptPath

    $arc.Globs | Should -Contain 'D:\Games\Steam\appcache\httpcache\*'
    $arc.Globs | Should -Contain 'D:\Games\Steam\steamapps\shadercache\*'
  }

  It "Skips the Steam caches when no Steam path can be found" {
    $arc.SteamPath = $null

    & $scriptPath

    ($arc.Globs -join ';') | Should -Not -BeLike '*appcache*'
    Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*Steam path not found*' }
  }

  It "Leaves Steam alone when it is not running" {
    & $scriptPath

    Should -Invoke Stop-Process -Times 0 -Exactly
  }

  It "Stops a running Steam before cleaning its caches" {
    $arc.Steam = [pscustomobject]@{ Name = 'steam'; Id = 4242 }

    & $scriptPath

    Should -Invoke Stop-Process -Times 1 -Exactly -ParameterFilter { $Force }
  }

  It "Flushes DNS, runs the DISM component cleanup, trims memory and optimizes volumes" {
    & $scriptPath

    $arc.Ipconfig | Should -Contain '/flushdns'
    $arc.Dism.Count | Should -Be 1
    $arc.Dism[0] | Should -BeLike '*/Online /Cleanup-Image /StartComponentCleanup /ResetBase*'
    Should -Invoke Invoke-MemoryTrim -Times 1 -Exactly -ParameterFilter { $TypeName -eq 'ArcCleanupMemTrim' }
    Should -Invoke Optimize-FixedVolume -Times 1 -Exactly
    Should -Invoke Write-ArcSummary -Times 1 -Exactly
  }

  It "Starts the DirectX cache rebuild tools only when they exist" {
    & $scriptPath
    Should -Invoke Start-Process -Times 0 -Exactly

    Mock Test-Path { $true } -ParameterFilter { $Path -like '*directxdatabaseupdater.exe' }
    & $scriptPath
    Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
      $FilePath -like '*directxdatabaseupdater.exe'
    }
  }
}
