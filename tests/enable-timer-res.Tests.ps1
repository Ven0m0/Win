#Requires -Version 5.1

BeforeDiscovery {
    # Must live here so -Skip: expressions can evaluate it during discovery.
    $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
}

Describe "enable-timer-res.ps1" {
    BeforeAll {
        # Stub Common.ps1 helpers so dot-source does not trigger downloads
        function Get-FileFromWeb { param([string]$URL, [string]$File) }
        # Mocks for all system-mutating operations
        Mock Set-ItemProperty { }
        Mock Get-ScheduledTask { $null }
        Mock Register-ScheduledTask { }
        Mock Unregister-ScheduledTask { }
        Mock Start-ScheduledTask { }
        Mock Start-Process { [PSCustomObject]@{ Id = 9999 } }
        Mock Get-Process { $null }
        Mock Write-Host { }
        # Prevent the main execution block from running fully
        Mock Select-OptimalResolution { [uint32]5040 }
    }

    Context "Write-StatusMessage" -Skip:(-not $IsAdmin) {
        BeforeAll {
            . "$PSScriptRoot/../Scripts/enable-timer-res.ps1" -ErrorAction SilentlyContinue
        }

        It "Calls Write-Host with the message text" {
            Write-StatusMessage "test message" "Info"
            Should -Invoke Write-Host -ParameterFilter { $Object -match 'test message' } -Scope It
        }

        It "Formats Info status with [INFO] prefix" {
            Write-StatusMessage "info test" "Info"
            Should -Invoke Write-Host -ParameterFilter { $Object -match '\[INFO\]' } -Scope It
        }

        It "Formats Success status with [OK] prefix" {
            Write-StatusMessage "ok test" "Success"
            Should -Invoke Write-Host -ParameterFilter { $Object -match '\[OK\]' } -Scope It
        }

        It "Formats Error status with [ERROR] prefix" {
            Write-StatusMessage "error test" "Error"
            Should -Invoke Write-Host -ParameterFilter { $Object -match '\[ERROR\]' } -Scope It
        }
    }

    Context "Get-TimerResolutionExe — file already present" -Skip:(-not $IsAdmin) {
        BeforeAll {
            . "$PSScriptRoot/../Scripts/enable-timer-res.ps1" -ErrorAction SilentlyContinue
        }

        It "Returns true and skips download when exe exists" {
            Mock Test-Path { $true } -ParameterFilter { $Path -like '*SetTimerResolution.exe' }
            $result = Get-TimerResolutionExe
            $result | Should -BeTrue
            Should -Not -Invoke Get-FileFromWeb
        }
    }

    Context "Get-TimerResolutionExe — file missing" -Skip:(-not $IsAdmin) {
        BeforeAll {
            . "$PSScriptRoot/../Scripts/enable-timer-res.ps1" -ErrorAction SilentlyContinue
        }

        It "Calls Get-FileFromWeb when exe is not present" {
            Mock Test-Path { $false } -ParameterFilter { $Path -like '*SetTimerResolution.exe' }
            Mock Get-FileFromWeb {
                # Simulate successful download by making file appear
                Mock Test-Path { $true } -ParameterFilter { $Path -like '*SetTimerResolution.exe' }
            }
            $result = Get-TimerResolutionExe
            Should -Invoke Get-FileFromWeb -Times 1 -Scope It
            $result | Should -BeTrue
        }

        It "Returns false when download fails" {
            Mock Test-Path { $false }
            Mock Get-FileFromWeb { throw 'network error' }
            $result = Get-TimerResolutionExe
            $result | Should -BeFalse
        }
    }

    Context "Set-TimerResolutionTask — task does not exist" -Skip:(-not $IsAdmin) {
        BeforeAll {
            . "$PSScriptRoot/../Scripts/enable-timer-res.ps1" -ErrorAction SilentlyContinue
        }

        It "Registers the scheduled task when it is absent" {
            Mock Get-ScheduledTask { $null }
            Mock New-ScheduledTaskAction { [PSCustomObject]@{} }
            Mock New-ScheduledTaskTrigger { [PSCustomObject]@{} }
            Mock New-ScheduledTaskSettingsSet { [PSCustomObject]@{} }
            Mock New-ScheduledTaskPrincipal { [PSCustomObject]@{} }
            Mock Register-ScheduledTask { [PSCustomObject]@{ TaskName = 'SetTimerResolution-AutoStart' } }
            $result = Set-TimerResolutionTask
            $result | Should -BeTrue
            Should -Invoke Register-ScheduledTask -Times 1 -Scope It
        }
    }

    Context "Set-TimerResolutionTask — task already exists, no -Force" -Skip:(-not $IsAdmin) {
        BeforeAll {
            . "$PSScriptRoot/../Scripts/enable-timer-res.ps1" -ErrorAction SilentlyContinue
        }

        It "Skips re-registration when task exists and -Force is not set" {
            Mock Get-ScheduledTask { [PSCustomObject]@{ TaskName = 'SetTimerResolution-AutoStart' } }
            $result = Set-TimerResolutionTask
            $result | Should -BeTrue
            Should -Not -Invoke Register-ScheduledTask
        }
    }

    Context "Get-TimerResolutionStatus" -Skip:(-not $IsAdmin) {
        BeforeAll {
            . "$PSScriptRoot/../Scripts/enable-timer-res.ps1" -ErrorAction SilentlyContinue
        }

        It "Reports scheduled task state when task exists" {
            Mock Get-ScheduledTask { [PSCustomObject]@{ TaskName = 'SetTimerResolution-AutoStart'; State = 'Ready' } }
            Mock Get-Process { $null }
            Mock Get-ItemProperty { $null }
            Get-TimerResolutionStatus
            Should -Invoke Write-Host -ParameterFilter { $Object -match 'EXISTS' } -Scope It
        }

        It "Reports task not found when task is absent" {
            Mock Get-ScheduledTask { $null }
            Mock Get-Process { $null }
            Mock Get-ItemProperty { $null }
            Get-TimerResolutionStatus
            Should -Invoke Write-Host -ParameterFilter { $Object -match 'NOT FOUND' } -Scope It
        }
    }
}
