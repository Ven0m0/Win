#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    . "$PSScriptRoot/../Scripts/arc-raiders/SkipVideosMod.ps1"
}

Describe "SkipVideosMod Script Initialization" {
    It "Should safely source the script" {
        $true | Should -Be $true
    }

    It "Should export the expected functions" {
        $expectedFunctions = @(
            "Find-ArcRaider",
            "Remove-VideoFile",
            "Remove-QuestFile",
            "Show-Menu",
            "Show-Diagnostics",
            "Show-Credit"
        )

        foreach ($funcName in $expectedFunctions) {
            $func = Get-Command -Name $funcName -ErrorAction SilentlyContinue
            $func | Should -Not -BeNullOrEmpty
            $func.CommandType | Should -Be "Function"
        }
    }
}

Describe "SkipVideosMod Functions" {
    BeforeAll {
        function Write-Host {}
        Mock Write-Host {}
        Mock Test-Path { return $false }
        Mock Get-ItemProperty {}
    }

    It "Should return null when Arc Raiders is not found" {
        Mock Test-Path { return $false }
        Mock Get-ItemProperty {}
        $result = Find-ArcRaider
        $result | Should -Be $null
    }

    It "Should not throw when removing a non-existent video file" {
        Mock Test-Path { return $false }
        { Remove-VideoFile -Dir "C:\nonexistent" -FileName "test.bk2" } | Should -Not -Throw
    }
}