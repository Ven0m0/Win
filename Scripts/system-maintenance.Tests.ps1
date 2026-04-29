#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    # Dot-source with skip flags so it doesn't execute maintenance during import
    . "$PSScriptRoot/system-maintenance.ps1" -NoDefrag -NoMsi
}

Describe "Invoke-Defrag" {
    It "Should run correct commands for target volume" {
        Mock Invoke-Step {}
        Mock Write-Verbose {}

        Invoke-Defrag -TargetVolume "D:"

        Should -Invoke Invoke-Step -Times 5
        Should -Invoke Invoke-Step -ParameterFilter { $CommandLine -eq "defrag D: /O" } -Times 1
        Should -Invoke Invoke-Step -ParameterFilter { $CommandLine -eq "defrag D: /L" } -Times 1
        Should -Invoke Invoke-Step -ParameterFilter { $CommandLine -eq "defrag D: /X" } -Times 1
        Should -Invoke Invoke-Step -ParameterFilter { $CommandLine -eq "defrag D: /G" } -Times 1
        Should -Invoke Invoke-Step -ParameterFilter { $CommandLine -eq "defrag D: /B" } -Times 1
    }

    It "Should run correct commands for all volumes" {
        Mock Invoke-Step {}
        Mock Write-Verbose {}

        Invoke-Defrag -All

        Should -Invoke Invoke-Step -Times 3
        Should -Invoke Invoke-Step -ParameterFilter { $CommandLine -eq "defrag /C" } -Times 1
        Should -Invoke Invoke-Step -ParameterFilter { $CommandLine -eq "defrag /C /O" } -Times 1
        Should -Invoke Invoke-Step -ParameterFilter { $CommandLine -eq "defrag /C /L" } -Times 1
    }
}

Describe "Invoke-MsiCleanup" {
    It "Should throw error if directory is missing" {
        Mock Test-Path { return $false }

        { Invoke-MsiCleanup -Root "C:\InvalidPath" } | Should -Throw "MSI Afterburner not found at: C:\InvalidPath"
    }

    It "Should perform cleanup commands if directory exists" {
        Mock Test-Path { return $true }
        Mock Invoke-Step {}
        Mock Write-Verbose {}

        Invoke-MsiCleanup -Root "C:\MSI"

        Should -Invoke Invoke-Step -ParameterFilter { $CommandLine -match "^copy /Y" } -Times 3
        Should -Invoke Invoke-Step -ParameterFilter { $CommandLine -match "^rmdir /S /Q .*Skins" } -Times 1
        Should -Invoke Invoke-Step -ParameterFilter { $CommandLine -match "^rmdir /S /Q .*Localization" } -Times 1
        Should -Invoke Invoke-Step -ParameterFilter { $CommandLine -match "^rmdir /S /Q .*Doc" } -Times 2
        Should -Invoke Invoke-Step -ParameterFilter { $CommandLine -match "^mkdir " } -Times 1
        Should -Invoke Invoke-Step -ParameterFilter { $CommandLine -match "^move /Y" } -Times 3
        Should -Invoke Invoke-Step -ParameterFilter { $CommandLine -match "^rmdir /S /Q .*SDK" } -Times 1
        Should -Invoke Invoke-Step -ParameterFilter { $CommandLine -match "^del /F /Q .*ReadMe.lnk" } -Times 1
    }
}
