#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
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
