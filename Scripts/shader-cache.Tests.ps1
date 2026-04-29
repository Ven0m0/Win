BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    function ConvertFrom-VDF {}
    function Stop-SteamGracefully {}
    function Clear-DirectorySafe {}
    function Request-AdminElevation {}
}

Describe "Invoke-ShaderCacheCleanup" {
    BeforeAll {
        $global:PSScriptRoot = $TestDrive
        . "$PSScriptRoot/shader-cache.ps1" -ErrorAction SilentlyContinue
    }

    Context "Steam Detection" {
        It "Should return if Steam is not found in registry" {
            Mock Get-ItemProperty { throw "Registry key not found" }
            Mock Write-Warning {}

            Invoke-ShaderCacheCleanup

            Assert-MockCalled Write-Warning -Times 1 -ParameterFilter { $Message -eq "Steam not found in registry!" }
        }

        It "Should return if Steam executable is missing" {
            Mock Get-ItemProperty { return [pscustomobject]@{ SteamPath = "C:\Steam" } }
            Mock Test-Path { return $false }
            Mock Write-Warning {}
            Mock Start-Sleep {}

            Invoke-ShaderCacheCleanup

            Assert-MockCalled Write-Warning -Times 1 -ParameterFilter { $Message -eq "Steam not found!" }
        }
    }

    Context "Cache Clearing Execution" {
        It "Should correctly resolve Steam directories and clear caches" {
            $env:APPDATA = "C:\Users\Test\AppData\Roaming"
            $env:ProgramData = "C:\ProgramData"
            $env:LOCALAPPDATA = "C:\Users\Test\AppData\Local"
            $env:SystemDrive = "C:"

            Mock Get-ItemProperty { return [pscustomobject]@{ SteamPath = "C:\Steam" } }
            Mock Test-Path { return $true }
            Mock Get-Content { return @('"libraryfolders"', '{', '}') }

            Mock ConvertFrom-VDF {
                $obj = New-Object PSObject
                $inner = @{ "0" = @{ "path" = '"C:\SteamLibrary"' } }
                Add-Member -InputObject $obj -MemberType ScriptMethod -Name Item -Value { param($i) return $this.Inner }
                Add-Member -InputObject $obj -MemberType NoteProperty -Name Inner -Value $inner
                return $obj
            }
            Mock Stop-SteamGracefully {}
            Mock Stop-Process {}
            Mock Remove-Item {}
            Mock Write-Host {}
            Mock Clear-DirectorySafe {}
            Mock Get-ChildItem { return @() }
            Mock Start-Sleep {}
            Mock Split-Path {}

            Invoke-ShaderCacheCleanup

            Assert-MockCalled Stop-SteamGracefully -Times 1
            Assert-MockCalled Clear-DirectorySafe -Exactly 25
            Assert-MockCalled Remove-Item -Times 1 -ParameterFilter { $Path -eq "C:\Steam\.crash" }
        }
    }
}

