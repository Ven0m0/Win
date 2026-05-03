#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    . "$PSScriptRoot/../Scripts/arc-raiders/start-arc-raiders.ps1"
}

Describe "Start-ArcRaiders Script Initialization" {
    It "Should safely source the script" {
        $true | Should -Be $true
    }

    It "Should export the Remove-Glob function" {
        $func = Get-Command -Name "Remove-Glob" -ErrorAction SilentlyContinue
        $func | Should -Not -BeNullOrEmpty
        $func.CommandType | Should -Be "Function"
    }
}

Describe "Start-ArcRaiders Functions" {
    BeforeAll {
        function Write-Host {}
        Mock Write-Host {}
        Mock Get-Item { return @() }
        Mock Get-ChildItem {}
        Mock Get-Volume { return @() }
        Mock Get-PhysicalDisk {}
        Mock Optimize-Volume {}
        Mock Start-Process {}
    }

    It "Should run Remove-Glob without errors when no items match" {
        Mock Get-Item { return @() }
        { Remove-Glob -Pattern "$env:TEMP\nonexistent\*" } | Should -Not -Throw
    }
}