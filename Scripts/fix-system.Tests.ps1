BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
}

Describe "fix-system.ps1" {
    BeforeAll {
        function DISM { }
        function cmd { }
        function chkdsk { }
        function winmgmt { }
        function USOClient.exe { }

        . "$PSScriptRoot/fix-system.ps1"
    }

    BeforeEach {
        Mock -CommandName 'DISM' -MockWith { return }
        Mock -CommandName 'cmd' -MockWith { return }
        Mock -CommandName 'chkdsk' -MockWith { return }
        Mock -CommandName 'winmgmt' -MockWith { return }
        Mock -CommandName 'USOClient.exe' -MockWith { return }

        Mock -CommandName 'Write-Header' -MockWith { return }
        Mock -CommandName 'Write-Info' -MockWith { return }
        Mock -CommandName 'Write-Warn' -MockWith { return }
        Mock -CommandName 'Write-Success' -MockWith { return }
        Mock -CommandName 'Write-Error' -MockWith { return }
        Mock -CommandName 'Add-Log' -MockWith { return }
        Mock -CommandName 'Clear-Log' -MockWith { return }
        Mock -CommandName 'Get-Log' -MockWith { return @("Mock Log") }
        Mock -CommandName 'Measure-Execution' -MockWith { return [pscustomobject]@{ EndTime = (Get-Date); Duration = "00:00:01" } }
        Mock -CommandName 'Show-Summary' -MockWith { return }

        # Override Common.ps1's Invoke-Operation inside Pester
        # Looking at Common.ps1 it defines `param([Parameter(Mandatory)] [scriptblock]$Action, ...)`
        # If we just mock it and don't care about the params, Pester still validates the mandatory parameter signature of the original function.
        # We can bypass this by redefining the function entirely before we Mock it, OR passing a Mock parameter filter, or mocking the Command/Action appropriately.
        # Let's redefine Invoke-Operation to not require Action.
    }

    Context "Execution Modes" {
        BeforeAll {
            function Invoke-Operation {
                param(
                    [string]$Name,
                    [hashtable]$Results,
                    [string]$Command,
                    [string]$ArgumentList,
                    [scriptblock]$Action = { }
                )
            }
        }

        BeforeEach {
            Mock -CommandName 'Invoke-Operation' -MockWith { return }
            Mock -CommandName 'Invoke-ServiceOperation' -MockWith { param($Name, $Action) & $Action }
            Mock -CommandName 'Write-Host' -MockWith { return }
            Mock -CommandName 'Rename-Item' -MockWith { return }
            Mock -CommandName 'Test-Path' -MockWith { return $true }
            Mock -CommandName 'Set-Content' -MockWith { return }
        }

        It "Should run in DryRun mode without errors" {
            { Start-SystemFix -DryRun -NoReboot -NoReport } | Should -Not -Throw
        }

        It "Should run QuickScan without errors" {
            { Start-SystemFix -QuickScan -NoReboot -NoReport } | Should -Not -Throw
            Assert-MockCalled 'chkdsk' -Times 0 -Exactly
            Assert-MockCalled 'winmgmt' -Times 0 -Exactly
        }

        It "Should run standard execution without errors" {
            { Start-SystemFix -NoReboot -NoReport } | Should -Not -Throw
            Assert-MockCalled 'DISM'
            Assert-MockCalled 'cmd'
            Assert-MockCalled 'chkdsk'
            Assert-MockCalled 'winmgmt'
        }
    }
}
