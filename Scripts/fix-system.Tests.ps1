#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
}

Describe "fix-system.ps1" {
    BeforeAll {
        function Write-Header { }
        function Write-Info { }
        function Write-Warn { }
        function Write-Success { }
        function Add-Log { }
        function Clear-Log { }
        function Get-Log { }
        function Show-Summary { }
        function Measure-Execution { return @{ EndTime = (Get-Date); Duration = [timespan]::Zero } }
        function Invoke-Operation { }
        function Invoke-ServiceOperation { param($Action) & $Action }

        function DISM { }
        function sfc { }
        function cmd { }
        function chkdsk { }
        function netsh { }
        function ipconfig { }
        function winmgmt { }
        function USOClient.exe { }

    }

    BeforeEach {
        Mock -CommandName Write-Header -MockWith { }
        Mock -CommandName Write-Info -MockWith { }
        Mock -CommandName Write-Warn -MockWith { }
        Mock -CommandName Write-Success -MockWith { }
        Mock -CommandName Add-Log -MockWith { }
        Mock -CommandName Clear-Log -MockWith { }
        Mock -CommandName Get-Log -MockWith { return @() }
        Mock -CommandName Show-Summary -MockWith { }
        Mock -CommandName Measure-Execution -MockWith { return @{ EndTime = (Get-Date); Duration = [timespan]::Zero } }
        Mock -CommandName Invoke-Operation -MockWith { }
        Mock -CommandName Invoke-ServiceOperation -MockWith { param($Action) & $Action }

        # Mock external executables
        Mock -CommandName DISM -MockWith { }
        Mock -CommandName sfc -MockWith { }
        Mock -CommandName cmd -MockWith { }
        Mock -CommandName chkdsk -MockWith { }
        Mock -CommandName netsh -MockWith { }
        Mock -CommandName ipconfig -MockWith { }
        Mock -CommandName winmgmt -MockWith { }
        Mock -CommandName USOClient.exe -MockWith { }
        Mock -CommandName Rename-Item -MockWith { }
        Mock -CommandName Test-Path -MockWith { return $true }
        Mock -CommandName Set-Content -MockWith { }
        Mock -CommandName Write-Host -MockWith { }
    }

    Context "Script functions" {
        BeforeAll {
            . "$PSScriptRoot/fix-system.ps1"
        }

        It "Should run Start-SystemFix in DryRun mode without errors" {
            { Start-SystemFix -DryRun -NoReboot -NoReport } | Should -Not -Throw
        }

        It "Should run Start-SystemFix in QuickScan mode without errors" {
            { Start-SystemFix -QuickScan -DryRun -NoReboot -NoReport } | Should -Not -Throw
        }

        It "Should skip CHKDSK when SkipDiskCheck is provided" {
            Start-SystemFix -SkipDiskCheck -DryRun -NoReboot -NoReport
            Assert-MockCalled -CommandName chkdsk -Times 0 -Exactly
        }
    }
}
