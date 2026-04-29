BeforeAll {
    Import-Module Pester -MinimumVersion 5.0

    # Mock all UI, IO, and external system commands used in the script
    function Request-AdminElevation {}
    function Initialize-ConsoleUI {}
    function Show-Menu {}
    function Get-MenuChoice { return 6 }
    function Clear-Host {}
    function Write-Host {}
    function Write-Info {}
    function Wait-ForKeyPress {}
    function Get-FileFromWeb {}
    function Set-RegistryValue {}
    function Remove-RegistryValue {}
    function Start-Process {}
    function Unblock-File {}

    Mock Request-AdminElevation {}
    Mock Initialize-ConsoleUI {}
    Mock Show-Menu {}
    Mock Get-MenuChoice { return 6 }
    Mock Clear-Host {}
    Mock Write-Host {}
    Mock Write-Info {}
    Mock Wait-ForKeyPress {}
    Mock Test-Path { return $true }
    Mock Get-ChildItem { return @() }
    Mock Get-FileFromWeb {}
    Mock Set-RegistryValue {}
    Mock Remove-RegistryValue {}
    Mock Set-ItemProperty {}
    Mock Set-Content {}
    Mock Start-Process {}

    # Load the script to test safely
    . "$PSScriptRoot/DLSS-force-latest.ps1"
}

Describe "DLSS-force-latest.ps1 functions" {
    Context "New-DLSSInspectorConfig" {
        It "Returns configuration with DLSS override enabled when true" {
            $result = New-DLSSInspectorConfig -EnableDLSSOverride $true

            $result | Should -Match "<SettingNameInfo>Override DLSS-SR presets</SettingNameInfo>"
            $result | Should -Match "<SettingNameInfo>Enable DLSS-SR override</SettingNameInfo>"
            $result | Should -Match "<SettingID>283385331</SettingID>"
            $result | Should -Match "<SettingValue>16777215</SettingValue>"
        }

        It "Returns configuration with DLSS override disabled when false" {
            $result = New-DLSSInspectorConfig -EnableDLSSOverride $false

            $result | Should -Not -Match "<SettingNameInfo>Override DLSS-SR presets</SettingNameInfo>"
            $result | Should -Not -Match "<SettingNameInfo>Enable DLSS-SR override</SettingNameInfo>"
            $result | Should -Not -Match "<SettingID>283385331</SettingID>"
            $result | Should -Match "<SettingNameInfo>Texture filtering - Negative LOD bias</SettingNameInfo>"
        }

        It "Always includes base configuration settings" {
            $result = New-DLSSInspectorConfig -EnableDLSSOverride $true

            $result | Should -Match "<ProfileName>Base Profile</ProfileName>"
            $result | Should -Match "<SettingNameInfo>Texture filtering - Anisotropic filter optimization</SettingNameInfo>"
            $result | Should -Match "<SettingNameInfo>Shader disk cache maximum size</SettingNameInfo>"
            $result | Should -Match "<SettingNameInfo>G-SYNC</SettingNameInfo>"
        }
    }

    Context "Start-DLSSForceLatestMenu" {
        It "Exports the expected main menu function" {
            $func = Get-Command -Name "Start-DLSSForceLatestMenu" -ErrorAction SilentlyContinue
            $func | Should -Not -BeNullOrEmpty
            $func.CommandType | Should -Be "Function"
        }
    }
}
