BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
}

Describe "DLSS-force-latest.ps1" {
    BeforeAll {
        function Initialize-ConsoleUI { param([Parameter(ValueFromRemainingArguments)]$DummyArgs) }
        function Show-Menu { param([Parameter(ValueFromRemainingArguments)]$DummyArgs) }
        function Wait-ForKeyPress { param([Parameter(ValueFromRemainingArguments)]$DummyArgs) }
        function Write-Info { param([Parameter(ValueFromRemainingArguments)]$DummyArgs) }

        # Load script for testing (will not execute main block because of guard)
        . "$PSScriptRoot/DLSS-force-latest.ps1"
    }

    BeforeEach {
        Mock -CommandName Request-AdminElevation -MockWith { }
        Mock -CommandName Set-RegistryValue -MockWith { }
        Mock -CommandName Remove-RegistryValue -MockWith { }
        Mock -CommandName Write-Host -MockWith { }
        Mock -CommandName Clear-Host -MockWith { }
        Mock -CommandName Set-ItemProperty -MockWith { }
        Mock -CommandName Get-ChildItem -MockWith { return @() }
        Mock -CommandName Unblock-File -MockWith { }
        Mock -CommandName Get-FileFromWeb -MockWith { }
        Mock -CommandName Test-Path -MockWith { return $true }
        Mock -CommandName Set-Content -MockWith { }
        Mock -CommandName Start-Process -MockWith { }
    }

    Context "Get-DLSSInspectorConfig" {
        It "Should generate XML configuration with DLSS override enabled" {
            $config = Get-DLSSInspectorConfig -EnableDLSSOverride $true
            $config | Should -Match "<SettingNameInfo>Override DLSS-SR presets</SettingNameInfo>"
            $config | Should -Match "<SettingValue>16777215</SettingValue>"
        }

        It "Should generate XML configuration with DLSS override disabled" {
            $config = Get-DLSSInspectorConfig -EnableDLSSOverride $false
            $config | Should -Not -Match "<SettingNameInfo>Override DLSS-SR presets</SettingNameInfo>"
        }
    }

    Context "Menu Options" {
        It "Option 1 (DLSS Force Latest: On) should generate nip file and start Inspector" {
            Mock -CommandName Get-MenuChoice -MockWith { return 1 }
            Mock -CommandName Start-Process -MockWith { throw "Exit loop" }

            { Invoke-DLSSForceLatest } | Should -Throw "Exit loop"

            Assert-MockCalled -CommandName Set-ItemProperty -Times 2
            Assert-MockCalled -CommandName Set-Content -Times 1
        }

        It "Option 2 (DLSS Force Latest: Off) should generate nip file and start Inspector" {
            Mock -CommandName Get-MenuChoice -MockWith { return 2 }
            Mock -CommandName Start-Process -MockWith { throw "Exit loop" }

            { Invoke-DLSSForceLatest } | Should -Throw "Exit loop"

            Assert-MockCalled -CommandName Set-ItemProperty -Times 2
            Assert-MockCalled -CommandName Set-Content -Times 1
        }

        It "Option 3 (DLSS Overlay: On) should set registry value" {
            Mock -CommandName Get-MenuChoice -MockWith { return 3 }
            Mock -CommandName Wait-ForKeyPress -MockWith { throw "Exit loop" }

            { Invoke-DLSSForceLatest } | Should -Throw "Exit loop"

            Assert-MockCalled -CommandName Set-RegistryValue -Times 1
        }

        It "Option 4 (DLSS Overlay: Off) should remove registry value" {
            Mock -CommandName Get-MenuChoice -MockWith { return 4 }
            Mock -CommandName Wait-ForKeyPress -MockWith { throw "Exit loop" }

            { Invoke-DLSSForceLatest } | Should -Throw "Exit loop"

            Assert-MockCalled -CommandName Remove-RegistryValue -Times 1
        }

        It "Option 5 (Read Only) should set nvdrsdb files to read only" {
            Mock -CommandName Get-MenuChoice -MockWith { return 5 }
            Mock -CommandName Wait-ForKeyPress -MockWith { throw "Exit loop" }

            { Invoke-DLSSForceLatest } | Should -Throw "Exit loop"

            Assert-MockCalled -CommandName Set-ItemProperty -Times 2 -ParameterFilter { $Name -eq 'IsReadOnly' -and $Value -eq $true }
        }

        It "Option 6 (Inspector) should revert read only and open Inspector" {
            Mock -CommandName Get-MenuChoice -MockWith { return 6 }
            Mock -CommandName Start-Process -MockWith { throw "Exit loop" }

            { Invoke-DLSSForceLatest } | Should -Throw "Exit loop"

            Assert-MockCalled -CommandName Set-ItemProperty -Times 2 -ParameterFilter { $Name -eq 'IsReadOnly' -and $Value -eq $false }
            Assert-MockCalled -CommandName Start-Process -Times 1
        }
    }
}
