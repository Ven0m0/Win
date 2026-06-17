#Requires -Version 5.1

# Setup logic outside of BeforeAll for Pester 5 Discovery phase
$canLoadForms = $false

try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    $canLoadForms = $true
}
catch {
    $canLoadForms = $false
}

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    # Discovery-phase variables are not visible during the Run phase in Pester 5,
    # so the script path must be assigned here for the It blocks to see it.
    $scriptPath = "$PSScriptRoot/../Scripts/Network-Tweaker.ps1"
}

Describe "Network-Tweaker.ps1" {
    It "Should bypass ShowDialog when dot-sourced" -Skip:(-not $canLoadForms) {
        # Test if it can be dot-sourced without hanging
        & {
            # The script targets the default 'Continue' preference: it reads many
            # machine-dependent registry values at load and tolerates absent ones
            # as non-terminating errors. Pester's 'Stop' default would abort.
            $ErrorActionPreference = 'Continue'
            . $scriptPath 2>$null

            # If it dot-sources successfully, it should have created the form object
            $Form -is [System.Windows.Forms.Form] | Should -Be $true

            # The title should be correct
            $Form.Text | Should -Match "Network Pro - Tweaker"

            # Form should not be visible (because ShowDialog was bypassed)
            $Form.Visible | Should -Be $false
        }
    }

    It "Should define expected UI manipulation functions" -Skip:(-not $canLoadForms) {
        & {
            $ErrorActionPreference = 'Continue'
            . $scriptPath 2>$null

            Get-Command -Name "applyglobal" -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command -Name "RegistryTweaks" -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}
