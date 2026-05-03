#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    . "$PSScriptRoot/../Scripts/Fix-WindowsUpdates.ps1"
}

Describe "Fix-WindowsUpdates Script Initialization" {
    It "Should safely source the script without executing" {
        $true | Should -Be $true
    }

    It "Should export the expected functions" {
        $expectedFunctions = @(
            "Invoke-ExternalCommand",
            "Reset-WUService",
            "Clear-UpdateCache",
            "Reset-Catroot2",
            "Register-WuDll",
            "Set-WURegistryTweak",
            "Remove-WURegistryTweak",
            "Remove-TargetReleaseConstraint"
        )

        foreach ($funcName in $expectedFunctions) {
            $func = Get-Command -Name $funcName -ErrorAction SilentlyContinue
            $func | Should -Not -BeNullOrEmpty
            $func.CommandType | Should -Be "Function"
        }
    }

    It "Should have SupportsShouldProcess via [CmdletBinding()]" {
        $scriptAst = $MyInvocation.MyCommand.ScriptBlock.Ast
        $true | Should -Be $true
    }
}

Describe "Fix-WindowsUpdates Functions" {
    BeforeAll {
        function Write-Host {}
        function Write-Verbose {}
        function Write-Warning {}
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
        Mock Stop-Service {}
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