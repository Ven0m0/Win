BeforeAll {
    Import-Module Pester -MinimumVersion 5.0

    # Define dummy functions for missing commands on non-Windows environments
    function Stop-SteamGracefully {}
    function Get-ItemProperty {}
    function Get-Process {}
    function Start-Process {}
    function Start-Sleep {}
    function Get-ChildItem {}
    function ConvertFrom-VDF {}
    function ConvertTo-VDF {}
    function New-Object {}

    . "$PSScriptRoot/steam.ps1"
}

Describe "steam.ps1" {
    Context "Testability pattern" {
        It "Should have a main function Start-SteamMin" {
            $scriptContent = Get-Content "$PSScriptRoot/steam.ps1" -Raw
            $scriptContent | Should -Match 'function Start-SteamMin'
        }

        It "Should use execution guard" {
            $scriptContent = Get-Content "$PSScriptRoot/steam.ps1" -Raw
            $scriptContent | Should -Match 'if \(\$MyInvocation\.InvocationName -ne ''\.''\) \{'
        }
    }

    Context "Registry lookup" {
        It "Should error out if registry throws" {
            Mock Get-ItemProperty { throw "Registry error" }
            Mock Write-Error {}
            Mock Write-Output {}

            Start-SteamMin

            Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -eq "Steam not found in registry!" }
        }

        It "Should output error if files missing" {
            Mock Get-ItemProperty { [pscustomobject]@{ SteamPath = "C:\Steam" } }
            Mock Test-Path { $false }
            Mock Write-Output {}
            Mock Start-Sleep {}
            Mock Write-Error {}

            Start-SteamMin

            Should -Invoke Write-Output -Times 1 -ParameterFilter { $InputObject -eq "Steam not found!" }
        }
    }
}
