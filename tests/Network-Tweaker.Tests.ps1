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

Describe "Network-Tweaker.ps1 Set-DwordTweak" {
    # Mocks only: no registry is touched. Each case dot-sources the script in its own scope.
    BeforeAll {
        $scriptPath = "$PSScriptRoot/../Scripts/Network-Tweaker.ps1"
        $tweak = @{ Path = 'REGISTRY::HKLM\Fake'; RegPath = 'HKLM\Fake'; Name = 'Val' }
    }

    It "Writes REG_DWORD when text is set and value exists" -Skip:(-not $canLoadForms) {
        & {
            $ErrorActionPreference = 'Continue'
            . $scriptPath 2>$null
            Mock Get-ItemProperty { [pscustomobject]@{ Val = 1 } }
            Mock Set-RegistryValue {}
            Mock Remove-RegistryValue {}
            Mock Write-Host {}

            Set-DwordTweak @tweak -Text '65535'

            Should -Invoke Set-RegistryValue -Times 1 -Exactly -ParameterFilter {
                $Type -eq 'REG_DWORD' -and $Data -eq '65535' -and $Name -eq 'Val' -and $Path -eq 'HKLM\Fake'
            }
            Should -Invoke Remove-RegistryValue -Times 0 -Exactly
        }
    }

    It "Removes the value when text is empty and value exists" -Skip:(-not $canLoadForms) {
        & {
            $ErrorActionPreference = 'Continue'
            . $scriptPath 2>$null
            Mock Get-ItemProperty { [pscustomobject]@{ Val = 1 } }
            Mock Set-RegistryValue {}
            Mock Remove-RegistryValue {}
            Mock Write-Warning {}

            Set-DwordTweak @tweak -Text ''

            Should -Invoke Remove-RegistryValue -Times 1 -Exactly -ParameterFilter { $Name -eq 'Val' }
            Should -Invoke Set-RegistryValue -Times 0 -Exactly
        }
    }

    It "Does nothing when text is empty and value is absent" -Skip:(-not $canLoadForms) {
        & {
            $ErrorActionPreference = 'Continue'
            . $scriptPath 2>$null
            Mock Get-ItemProperty { [pscustomobject]@{ Other = 1 } }
            Mock Set-RegistryValue {}
            Mock Remove-RegistryValue {}

            Set-DwordTweak @tweak -Text ''

            Should -Invoke Remove-RegistryValue -Times 0 -Exactly
            Should -Invoke Set-RegistryValue -Times 0 -Exactly
        }
    }

    It "Treats DefaultText as unset (removes existing, skips absent)" -Skip:(-not $canLoadForms) {
        & {
            $ErrorActionPreference = 'Continue'
            . $scriptPath 2>$null
            Mock Set-RegistryValue {}
            Mock Remove-RegistryValue {}
            Mock Write-Warning {}

            Mock Get-ItemProperty { [pscustomobject]@{ Val = 1 } }
            Set-DwordTweak @tweak -Text '0' -DefaultText '0'
            Should -Invoke Remove-RegistryValue -Times 1 -Exactly

            Mock Get-ItemProperty { [pscustomobject]@{ Other = 1 } }
            Set-DwordTweak @tweak -Text '0' -DefaultText '0'
            Should -Invoke Remove-RegistryValue -Times 1 -Exactly
            Should -Invoke Set-RegistryValue -Times 0 -Exactly
        }
    }

    It "Skips non-numeric text with a warning" -Skip:(-not $canLoadForms) {
        & {
            $ErrorActionPreference = 'Continue'
            . $scriptPath 2>$null
            Mock Get-ItemProperty { [pscustomobject]@{ Val = 1 } }
            Mock Set-RegistryValue {}
            Mock Remove-RegistryValue {}
            Mock Write-Warning {}

            Set-DwordTweak @tweak -Text 'abc'

            Should -Invoke Write-Warning -Times 1 -Exactly
            Should -Invoke Set-RegistryValue -Times 0 -Exactly
            Should -Invoke Remove-RegistryValue -Times 0 -Exactly
        }
    }

    It "AFD table has unique names and a combo box for every entry" -Skip:(-not $canLoadForms) {
        & {
            $ErrorActionPreference = 'Continue'
            . $scriptPath 2>$null

            $table = @(Get-AfdTweakTable)
            $table.Count | Should -BeGreaterThan 0
            ($table.Name | Select-Object -Unique).Count | Should -Be $table.Count
            foreach ($entry in $table) {
                $entry.Box | Should -BeOfType [System.Windows.Forms.ComboBox]
            }
        }
    }
}
