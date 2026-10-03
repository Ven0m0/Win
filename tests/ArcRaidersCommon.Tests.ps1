#Requires -Version 5.1

BeforeAll {
  Import-Module Pester -MinimumVersion 5.0
  . "$PSScriptRoot/../Scripts/arc-raiders/ArcRaidersCommon.ps1"
}

Describe 'ArcRaidersCommon.ps1' {
  Context 'Find-ArcRaidersInstallPath' {
    It 'Returns the Steam library install directory when it exists' {
      Mock Get-SteamPath { "$env:SystemDrive\Steam" }
      Mock Test-Path { $true }

      Find-ArcRaidersInstallPath | Should -Be "$env:SystemDrive\Steam\steamapps\common\Arc Raiders"
    }

    It 'Falls back to the Program Files (x86) Steam library' {
      Mock Get-SteamPath { $null }
      Mock Test-Path { $Path -like "${env:ProgramFiles(x86)}\Steam\*" }

      $expected = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Steam\steamapps\common\Arc Raiders'
      Find-ArcRaidersInstallPath | Should -Be $expected
    }

    It 'Falls back to the Epic Games install when Steam has no copy' {
      Mock Get-SteamPath { "$env:SystemDrive\Steam" }
      Mock Test-Path { $Path -like '*Epic Games*' }

      $expected = Join-Path -Path $env:ProgramFiles -ChildPath 'Epic Games\Arc Raiders'
      Find-ArcRaidersInstallPath | Should -Be $expected
    }

    It 'Returns null when no install location exists' {
      Mock Get-SteamPath { $null }
      Mock Test-Path { $false }

      Find-ArcRaidersInstallPath | Should -BeNullOrEmpty
    }
  }

  Context 'Test-RunningAsAdmin' {
    It 'Matches the current Windows principal role' {
      $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
      $expected = ([Security.Principal.WindowsPrincipal]$identity).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)

      Test-RunningAsAdmin | Should -BeExactly $expected
    }
  }

  Context 'Set-GameProcessPriority' {
    BeforeEach {
      # Mock bodies resolve this through dynamic scoping.
      $procState = @{
        Procs = @([pscustomobject]@{ Id = 11; PriorityClass = 'Normal' })
      }
      Mock Get-Process { $procState.Procs }
      Mock Write-Host { }
    }

    It 'Sets High priority on matching processes by default' {
      Set-GameProcessPriority

      "$($procState.Procs[0].PriorityClass)" | Should -Be 'High'
    }

    It 'Applies the requested priority class' {
      Set-GameProcessPriority -Priority BelowNormal

      "$($procState.Procs[0].PriorityClass)" | Should -Be 'BelowNormal'
    }

    It 'Looks up every name in -GameNames' {
      Set-GameProcessPriority -GameNames 'GameA', 'GameB'

      Should -Invoke Get-Process -Times 1 -Exactly -ParameterFilter { $Name -eq 'GameA' }
      Should -Invoke Get-Process -Times 1 -Exactly -ParameterFilter { $Name -eq 'GameB' }
    }

    It 'Leaves the priority unchanged under -WhatIf' {
      Set-GameProcessPriority -WhatIf

      "$($procState.Procs[0].PriorityClass)" | Should -Be 'Normal'
    }

    It 'Does nothing when no process matches' {
      $procState.Procs = @()

      { Set-GameProcessPriority } | Should -Not -Throw
      Should -Invoke Write-Host -Times 0
    }

    It 'Swallows access-denied errors from the priority setter' {
      $denied = [pscustomobject]@{ Id = 12 } | Add-Member -MemberType ScriptProperty -Name PriorityClass `
        -Value { 'Normal' } -SecondValue { throw 'Access is denied' } -PassThru
      $procState.Procs = @($denied)

      { Set-GameProcessPriority } | Should -Not -Throw
    }
  }

  Context 'Get-ArcRaidersGameProcess' {
    It 'Returns the first running PioneerGame process' {
      Mock Get-Process {
        @([pscustomobject]@{ Id = 21 }, [pscustomobject]@{ Id = 22 })
      } -ParameterFilter { $Name -eq 'PioneerGame' }

      (Get-ArcRaidersGameProcess).Id | Should -Be 21
    }

    It 'Returns null when the game is not running' {
      Mock Get-Process { }

      Get-ArcRaidersGameProcess | Should -BeNullOrEmpty
    }
  }

  Context 'Set-VdfValue' {
    It 'Creates every missing level of a nested path' {
      $vdf = @{}

      Set-VdfValue -Vdf $vdf -Path 'a\b\c' -Value ''

      $vdf['a']['b'].Contains('c') | Should -BeTrue
    }

    It 'Creates a single top-level key' {
      $vdf = @{}

      Set-VdfValue -Vdf $vdf -Path 'solo' -Value ''

      $vdf.ContainsKey('solo') | Should -BeTrue
    }

    It 'Preserves existing keys and values along the path' {
      $vdf = @{ a = [ordered]@{ keep = '1' } }

      Set-VdfValue -Vdf $vdf -Path 'a\b' -Value ''

      $vdf['a']['keep'] | Should -Be '1'
      $vdf['a'].Contains('b') | Should -BeTrue
    }

    It 'Does not replace an existing nested table' {
      $inner = [ordered]@{ x = 'y' }
      $vdf = @{ a = [ordered]@{ b = $inner } }

      Set-VdfValue -Vdf $vdf -Path 'a\b' -Value ''

      [object]::ReferenceEquals($vdf['a']['b'], $inner) | Should -BeTrue
    }
  }

  Context 'Optimize-FixedVolume' {
    BeforeAll {
      # Storage-module CDXML cmdlets cannot be Pester-mocked directly (their generated proxies
      # reference dynamic types); plain stubs with matching parameters are shadowed instead.
      function Get-Volume { [CmdletBinding()] param() }
      function Get-PhysicalDisk { [CmdletBinding()] param() }
      function Get-Partition { [CmdletBinding()] param($DriveLetter) }
      function Get-Disk { [CmdletBinding()] param([Parameter(ValueFromPipeline)]$InputObject) }
      function Optimize-Volume {
        [CmdletBinding()]
        param($DriveLetter, [switch]$ReTrim, [switch]$Defrag)
      }
    }

    BeforeEach {
      $volState = @{
        Media   = 'SSD'
        Volumes = @(
          [pscustomobject]@{ DriveType = 'Fixed'; DriveLetter = 'C'; FileSystem = 'NTFS' }
        )
      }
      Mock Write-Host { }
      Mock Get-Volume { $volState.Volumes }
      Mock Get-PhysicalDisk { [pscustomobject]@{ UniqueId = 'disk-1'; MediaType = $volState.Media } }
      Mock Get-Partition { [pscustomobject]@{ DriveLetter = $DriveLetter } }
      Mock Get-Disk { [pscustomobject]@{ UniqueId = 'disk-1' } }
      Mock Optimize-Volume { }
    }

    It 'Re-trims solid-state volumes' {
      Optimize-FixedVolume

      Should -Invoke Optimize-Volume -Times 1 -Exactly -ParameterFilter {
        $DriveLetter -eq 'C' -and $ReTrim
      }
      Should -Invoke Optimize-Volume -Times 0 -ParameterFilter { $Defrag }
    }

    It 'Defragments HDD volumes' {
      $volState.Media = 'HDD'

      Optimize-FixedVolume

      Should -Invoke Optimize-Volume -Times 1 -Exactly -ParameterFilter {
        $DriveLetter -eq 'C' -and $Defrag
      }
      Should -Invoke Optimize-Volume -Times 0 -ParameterFilter { $ReTrim }
    }

    It 'Re-trims when the media type is unknown' {
      Mock Get-Disk { [pscustomobject]@{ UniqueId = 'no-such-disk' } }

      Optimize-FixedVolume

      Should -Invoke Optimize-Volume -Times 1 -Exactly -ParameterFilter { $ReTrim }
    }

    It 'Skips removable volumes and volumes without a drive letter' {
      $volState.Volumes = @(
        [pscustomobject]@{ DriveType = 'Removable'; DriveLetter = 'E'; FileSystem = 'FAT32' }
        [pscustomobject]@{ DriveType = 'Fixed'; DriveLetter = $null; FileSystem = 'NTFS' }
      )

      Optimize-FixedVolume

      Should -Invoke Optimize-Volume -Times 0
    }

    It 'Optimizes nothing under -WhatIf' {
      Optimize-FixedVolume -WhatIf

      Should -Invoke Optimize-Volume -Times 0
    }
  }

  # Re-dot-sourcing resets the $script:ARC_* counters before every test.
  Context 'Invoke-GlobClean and Write-ArcSummary' {
    BeforeEach {
      . "$PSScriptRoot/../Scripts/arc-raiders/ArcRaidersCommon.ps1"
      $hostLines = [System.Collections.Generic.List[string]]::new()
      Mock Write-Host { $hostLines.Add([string]$Object) }
    }

    It 'Forwards the pattern to Remove-Glob' {
      Mock Remove-Glob { }

      Invoke-GlobClean -Pattern 'C:\nowhere\*'

      Should -Invoke Remove-Glob -Times 1 -Exactly -ParameterFilter { $Pattern -eq 'C:\nowhere\*' }
    }

    It 'Reports the tallied size and count' {
      Mock Remove-Glob {
        $TotalSize.Value += 2MB
        $TotalCount.Value += 3
      }

      Invoke-GlobClean -Pattern 'C:\nowhere\*'
      Write-ArcSummary

      ($hostLines -join "`n") | Should -Match 'Cleaned: 3 item\(s\), 2 MB freed\.'
      ($hostLines -join "`n") | Should -Not -Match 'Skipped:'
    }

    It 'Reports files that were still in use' {
      Mock Remove-Glob { $FailedCount.Value += 4 }

      Invoke-GlobClean -Pattern 'C:\nowhere\*'
      Write-ArcSummary

      ($hostLines -join "`n") | Should -Match 'Skipped: 4 item\(s\)'
    }

    It 'Accumulates totals across several Invoke-GlobClean calls' {
      Mock Remove-Glob {
        $TotalSize.Value += 1MB
        $TotalCount.Value += 1
      }

      Invoke-GlobClean -Pattern 'C:\a\*'
      Invoke-GlobClean -Pattern 'C:\b\*'
      Write-ArcSummary

      ($hostLines -join "`n") | Should -Match 'Cleaned: 2 item\(s\), 2 MB freed\.'
    }
  }
}
