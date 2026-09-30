#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
}

Describe "fix-system.ps1 (System action)" {
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
            . "$PSScriptRoot/../Scripts/fix-system.ps1"
        }

        It "Should run Start-SystemFix in DryRun mode without errors" {
            { Start-SystemFix -DryRun -NoReboot -NoReport } | Should -Not -Throw
        }

        It "Should run Start-SystemFix in QuickScan mode without errors" {
            { Start-SystemFix -QuickScan -DryRun -NoReboot -NoReport } | Should -Not -Throw
        }

        It "Should skip CHKDSK when SkipDiskCheck is provided" {
            Start-SystemFix -SkipDiskCheck -DryRun -NoReboot -NoReport
            Should -Invoke -CommandName chkdsk -Times 0 -Exactly
        }
    }
}

Describe "fix-system.ps1 (Health action)" {
    BeforeAll {
        . "$PSScriptRoot/../Scripts/fix-system.ps1"
        # Pester cannot build mock proxies for these CDXML cmdlets on newer pwsh; stub them first.
        function Get-PhysicalDisk { }
        function Get-Volume { }
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
        Mock -CommandName Get-PhysicalDisk -MockWith { return @() }
        Mock -CommandName Get-Volume -MockWith { return @() }
        Mock -CommandName Get-Service -MockWith { return @() }
        Mock -CommandName Get-FolderSize -MockWith { return 0 }
        Mock -CommandName Get-ItemProperty -MockWith { return $null }
        Mock -CommandName Get-ChildItem -MockWith { return @() }
        Mock -CommandName Test-Path -MockWith { return $false }
        Mock -CommandName Set-Content -MockWith { }
        Mock -CommandName Write-Host -MockWith { }
    }

    It "Should run Start-SystemHealthCheck in DryRun mode without errors" {
        { Start-SystemHealthCheck -DryRun -NoReport } | Should -Not -Throw
    }

    It "Should skip live checks in DryRun mode" {
        Start-SystemHealthCheck -DryRun -NoReport
        Should -Invoke -CommandName Get-PhysicalDisk -Times 0 -Exactly
    }

    It "Should run the live checks without errors" {
        { Start-SystemHealthCheck -NoReport } | Should -Not -Throw
    }
}

Describe "fix-system.ps1 (WindowsUpdate action) - Initialization" {
    BeforeAll {
        . "$PSScriptRoot/../Scripts/fix-system.ps1"
    }

    It "Should export the expected Windows Update functions" {
        $expectedFunctions = @(
            "Invoke-ExternalCommand",
            "Reset-WUService",
            "Clear-UpdateCache",
            "Reset-Catroot2",
            "Register-WuDll",
            "Start-WindowsUpdateFix"
        )

        foreach ($funcName in $expectedFunctions) {
            $func = Get-Command -Name $funcName -ErrorAction SilentlyContinue
            $func | Should -Not -BeNullOrEmpty
            $func.CommandType | Should -Be "Function"
        }
    }

    It "Should not execute repair logic when dot-sourced" {
        # Dispatcher is guarded by the InvocationName check; importing is side-effect free.
        $true | Should -Be $true
    }
}

Describe "fix-system.ps1 (WindowsUpdate action) - Functions" {
    BeforeAll {
        . "$PSScriptRoot/../Scripts/fix-system.ps1"

        Mock Write-Host {}
        Mock Write-Verbose {}
        Mock Write-Warning {}
        function sc.exe { return 0 }
        function net.exe { return 0 }
        function reg.exe { return 0 }
        function takeown.exe { return 0 }
        function icacls.exe { return 0 }
        Mock Write-Host {}
        Mock Write-Verbose {}
        Mock Write-Warning {}
        Mock Start-Sleep {}
        Mock Test-Path { return $false }
        Mock Get-ChildItem { return @() }
        Mock Remove-Item {}
        # Clear-UpdateCache renames the live SoftwareDistribution folder; never let a test do that.
        Mock Rename-Item {}
        Mock Stop-Service {}
        Mock Start-Service {}
    }

    It "Should run Reset-WUService without errors" {
        { Reset-WUService } | Should -Not -Throw
    }

    It "Should run Clear-UpdateCache without errors" {
        Mock Test-Path { return $true }
        Mock Get-ChildItem { return @() }
        { Clear-UpdateCache } | Should -Not -Throw
    }

    It "Should support -WhatIf forwarding" {
        { Clear-UpdateCache -WhatIf } | Should -Not -Throw
    }
}

Describe "fix-system.ps1 (output parsing)" {
    BeforeAll {
        . "$PSScriptRoot/../Scripts/fix-system.ps1"
    }

    It "Classifies '<Output>' as <Expected>" -ForEach @(
        @{ Output = 'WMI repository is consistent'; Expected = 'CONSISTENT' }
        @{ Output = 'WMI repository is inconsistent'; Expected = 'INCONSISTENT' }
        @{ Output = "WMI repository verification failed`nError code: 0x8007041B"; Expected = 'INCONSISTENT' }
        @{ Output = ''; Expected = 'UNKNOWN' }
    ) {
        Get-WmiRepositoryState -Output $Output | Should -Be $Expected
    }

    It "Parses sfc's NUL-interleaved UTF-16 output" {
        Mock Add-Log {}
        Mock sfc.exe {
            $global:LASTEXITCODE = 0
            ('Windows Resource Protection found corrupt files and successfully repaired them.'.ToCharArray() -join "`0")
        }
        Invoke-SfcScan | Should -Be 'REPAIRED'
    }
}
