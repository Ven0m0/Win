#Requires -Version 5.1

# Setup logic outside of BeforeAll for Pester 5 Discovery phase
$scriptPath = "$PSScriptRoot/Network-Tweaker.ps1"
$canLoadForms = $false

try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    $canLoadForms = $true
} catch {
    $canLoadForms = $false
}

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
}

Describe "Network-Tweaker.ps1" {
    It "Should bypass ShowDialog when dot-sourced" -Skip:(-not $canLoadForms) {
        # Test if it can be dot-sourced without hanging
        & {
            . $scriptPath

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
            . $scriptPath

            # Verify core functions are defined by checking if they are exported in this scope
            Get-Command -Name "Opacity" -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command -Name "Set-ConsoleColor" -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command -Name "Initialize-AdapterUI" -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}
