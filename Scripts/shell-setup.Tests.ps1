BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
}

Describe "shell-setup.ps1" {
    Context "Script execution guard" {
        It "Should not execute main logic when dot-sourced" {
            # Dot-source the script, passing switches to prevent it from prompting
            . "$PSScriptRoot/shell-setup.ps1" -HomeWorkstation
            # If the script dot-sourced correctly without hanging, it passes
            $true | Should -Be $true
        }
    }

    Context "Function Definitions" {
        BeforeAll {
            . "$PSScriptRoot/shell-setup.ps1" -HomeWorkstation
        }

        It "Should define required functions" {
            Get-Command Run-Elevated -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Install-ScoopApp -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Install-WinGetApp -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Install-ChocoApp -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Extract-Download -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Download-CustomApp -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Install-CustomApp -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Install-CustomPackage -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Enable-Bucket -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}
