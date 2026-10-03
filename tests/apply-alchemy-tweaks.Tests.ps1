#Requires -Version 5.1

BeforeDiscovery {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $script:notAdmin = -not ([Security.Principal.WindowsPrincipal]$identity).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
  # Shared prefixes for the -ForEach rows below (evaluated at discovery time).
  $ctl = 'HKLM\SYSTEM\CurrentControlSet\Control'
  $profileKey = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
}

BeforeAll {
  Import-Module Pester -MinimumVersion 5.0
}

# The script has '#Requires -RunAsAdministrator', so it can only be invoked from an elevated session.
# Top-level script (no dispatcher guard); invoked with '&' after every registry, restore-point, bcdedit,
# and process command is mocked, so nothing here touches the machine. Pester mocks are aliases, so they
# still win after the script re-dot-sources Common.ps1.
Describe 'apply-alchemy-tweaks.ps1' -Skip:$notAdmin {
  BeforeAll {
    . "$PSScriptRoot/../Scripts/Common.ps1"
    $script:scriptPath = Join-Path -Path $PSScriptRoot -ChildPath '../Scripts/reg/apply-alchemy-tweaks.ps1'
    function bcdedit { }
  }

  BeforeEach {
    # Mock bodies run inside the invoked script's scope; share state through a reference object.
    $alch = @{
      Reg     = [System.Collections.Generic.List[object]]::new()
      Removed = [System.Collections.Generic.List[object]]::new()
      Nvidia  = [System.Collections.Generic.List[string]]::new()
      Events  = [System.Collections.Generic.List[string]]::new()
      Host    = [System.Collections.Generic.List[string]]::new()
    }
    Mock Request-AdminElevation { }
    Mock New-RestorePoint { $alch.Events.Add("restore:$Description") }
    Mock Set-RegistryValue {
      $alch.Events.Add('reg')
      $alch.Reg.Add([pscustomobject]@{ Path = $Path; Name = $Name; Type = $Type; Data = $Data })
    }
    Mock Remove-RegistryValue { $alch.Removed.Add([pscustomobject]@{ Path = $Path; Name = $Name }) }
    Mock Set-NvidiaGpuRegistryValue { $alch.Nvidia.Add($Name) }
    Mock bcdedit { }
    Mock Stop-Process { }
    Mock Start-Process { }
    Mock Start-Sleep { }
    Mock Write-Host { $alch.Host.Add([string]$Object) }
  }

  Context 'Setup' {
    It 'Requests elevation once' {
      & $scriptPath

      Should -Invoke Request-AdminElevation -Times 1 -Exactly
    }

    It 'Creates a named restore point before the first registry write' {
      & $scriptPath

      $alch.Events[0] | Should -Be 'restore:Before apply-alchemy-tweaks'
      Should -Invoke New-RestorePoint -Times 1 -Exactly
    }

    It 'Skips the restore point with -NoRestorePoint' {
      & $scriptPath -NoRestorePoint

      Should -Invoke New-RestorePoint -Times 0
      $alch.Events[0] | Should -Be 'reg'
    }

    It 'Prints the completion message' {
      & $scriptPath

      $alch.Host | Should -Contain 'Alchemy tweaks applied.'
    }
  }

  Context 'Applied values' {
    It 'Writes <Name> = <Data> under <Path>' -ForEach @(
      @{ Path = "$ctl\GraphicsDrivers\Scheduler"; Name = 'EnablePreemption'; Data = '0' }
      @{ Path = "$ctl\Session Manager\kernel"; Name = 'SerializeTimerExpiration'; Data = '1' }
      @{ Path = "$ctl\FileSystem"; Name = 'LongPathsEnabled'; Data = '1' }
      @{ Path = "$ctl\FileSystem"; Name = 'NtfsDisableLastAccessUpdate'; Data = '1' }
      @{ Path = "$ctl\Session Manager\Memory Management"; Name = 'DisablePagingExecutive'; Data = '1' }
      @{ Path = $profileKey; Name = 'SystemResponsiveness'; Data = '10' }
      @{ Path = "$profileKey\Tasks\Games"; Name = 'Latency Sensitive'; Data = 'True' }
      @{ Path = 'HKLM\SYSTEM\CurrentControlSet\Services\MMCSS'; Name = 'Start'; Data = '2' }
      @{ Path = "$ctl\Power\PowerThrottling"; Name = 'PowerThrottlingOff'; Data = '1' }
      @{ Path = 'HKCU\SOFTWARE\Microsoft\GameBar'; Name = 'GameDVR_Enabled'; Data = '0' }
    ) {
      & $scriptPath

      $hit = @($alch.Reg | Where-Object { $_.Path -eq $Path -and $_.Name -eq $Name })
      $hit.Count | Should -BeGreaterThan 0
      $hit[-1].Data | Should -Be $Data
    }

    It 'Applies the per-GPU NVIDIA values through the shared helper' {
      & $scriptPath

      $alch.Nvidia | Should -Contain 'DisableDynamicPstate'
      $alch.Nvidia | Should -Contain 'RMHdcpKeyglobZero'
    }

    It 'Clears the nine power-profile event priorities' {
      & $scriptPath

      $alch.Removed.Count | Should -Be 9
      $alch.Removed.Name | Select-Object -Unique | Should -Be 'Pri'
    }

    It 'Disables the dynamic tick through bcdedit' {
      & $scriptPath

      Should -Invoke bcdedit -Times 1 -Exactly -ParameterFilter {
        $args[0] -eq '/set' -and $args[1] -eq 'disabledynamictick' -and $args[2] -eq 'yes'
      }
    }

    It 'Restarts DWM once to apply the DWM values' {
      & $scriptPath

      Should -Invoke Stop-Process -Times 1 -Exactly -ParameterFilter { $Name -eq 'dwm' }
      Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $FilePath -like '*\system32\dwm.exe' }
    }
  }

  Context 'Registry write safety' {
    It 'Uses only well-formed HKLM/HKCU paths, names, and value types' {
      & $scriptPath -IncludeExperimental

      $alch.Reg.Count | Should -BeGreaterThan 0
      foreach ($entry in $alch.Reg) {
        $entry.Path | Should -Match '^HK(LM|CU)\\\S'
        $entry.Name | Should -Not -BeNullOrEmpty
        $entry.Type | Should -BeIn 'REG_DWORD', 'REG_SZ', 'REG_QWORD', 'REG_BINARY', 'REG_EXPAND_SZ',
        'REG_MULTI_SZ'
        $entry.Data | Should -Not -BeNullOrEmpty
      }
    }

    It 'Never writes or removes under SECURITY, SAM, or Lsa' {
      & $scriptPath -IncludeExperimental

      $forbidden = '^HKLM\\(SECURITY|SAM)(\\|$)|\\Lsa(\\|$)'
      @($alch.Reg + $alch.Removed | Where-Object { $_.Path -match $forbidden }) | Should -BeNullOrEmpty
    }

    It 'Does not write conflicting values to the same path and name' {
      & $scriptPath

      $conflicts = $alch.Reg |
        Group-Object -Property { "$($_.Path)|$($_.Name)".ToLowerInvariant() } |
        Where-Object { @($_.Group.Data | Select-Object -Unique).Count -gt 1 }
      @($conflicts).Count | Should -Be 0
    }
  }

  Context 'Experimental tier' {
    It 'Is not applied by default' {
      & $scriptPath

      $alch.Reg.Name | Should -Not -Contain 'GlobalDisableThirdPartyEnhancements'
      $alch.Host -join "`n" | Should -Not -Match 'Experimental tweaks'
    }

    It 'Is applied with -IncludeExperimental on top of the default tweaks' {
      & $scriptPath
      $defaultCount = $alch.Reg.Count
      $alch.Reg.Clear()

      & $scriptPath -IncludeExperimental

      $alch.Reg.Name | Should -Contain 'GlobalDisableThirdPartyEnhancements'
      $alch.Reg.Count | Should -BeGreaterThan $defaultCount
      $alch.Host -join "`n" | Should -Match 'Applying Experimental tweaks'
    }
  }
}
