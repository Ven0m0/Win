BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
}

Describe "steam.ps1" {
    BeforeAll {
        function Close-SteamGracefully { }
        . "$PSScriptRoot/../Scripts/steam.ps1"
    }

    BeforeEach {
        Mock -CommandName ConvertFrom-VDF -MockWith {
            $script:mockVdf = [ordered]@{
                Software = [ordered]@{
                    Valve = [ordered]@{
                        Steam = [ordered]@{
                            SteamDefaultDialog = '"#app_games"'
                            FriendsUI = [ordered]@{ FriendsUIJSON = '{"bSignIntoFriends":true}' }
                            SmallMode = '"0"'
                        }
                    }
                }
                friends = [ordered]@{
                    SignIntoFriends = '"1"'
                }
            }
            $obj = [pscustomobject]@{
                Count = 1
            }
            Add-Member -InputObject $obj -MemberType ScriptMethod `
                -Name Item -Value { return $script:mockVdf }
            return $obj
        }

        Mock -CommandName Get-ItemProperty -MockWith {
            return [pscustomobject]@{ SteamPath = 'C:\Fake\Steam' }
        }
        Mock -CommandName Test-Path -MockWith { return $true }
        Mock -CommandName Write-Host -MockWith { }
        Mock -CommandName Write-Error -MockWith { }
        Mock -CommandName Start-Sleep -MockWith { }
        Mock -CommandName Get-Process -MockWith { return $null }
        Mock -CommandName Close-SteamGracefully -MockWith { }
        Mock -CommandName Remove-Item -MockWith { }
        Mock -CommandName Get-ChildItem -MockWith {
            return [pscustomobject]@{ FullName = 'C:\Fake\Steam\file.vdf' }
        }
        Mock -CommandName Get-Content -MockWith { return 'fake content' }
        Mock -CommandName ConvertTo-VDF -MockWith { return 'fake vdf output' }
        Mock -CommandName Write-Output -MockWith { }

        Mock -CommandName New-Object -MockWith {
            $lnk = [pscustomobject]@{
                Description = ''
                IconLocation = ''
                WindowStyle = ''
                TargetPath = ''
                Arguments = ''
            }
            Add-Member -InputObject $lnk -MemberType ScriptMethod -Name Save -Value { }
            $wsh = [pscustomobject]@{ }
            Add-Member -InputObject $wsh -MemberType ScriptMethod `
                -Name CreateShortcut -Value { return $lnk }
            return $wsh
        }

        Mock -CommandName Start-Process -MockWith { }
        Mock -CommandName Set-Content -MockWith { }

        # Override the function globally to prevent IO operations
        function global:sc-nonew($fn, $txt) { }
    }

    Context "Steam is not found" {
        It "Should log an error and return if Test-Path fails" {
            Mock -CommandName Test-Path -MockWith { return $false }
            Invoke-SteamOptimization
            Assert-MockCalled -CommandName Write-Host -Times 1 -Exactly
            Assert-MockCalled -CommandName Start-Sleep -Times 1 -Exactly
            Assert-MockCalled -CommandName Start-Process -Times 0 -Exactly
        }

        It "Should log an error and return if Get-ItemProperty throws" {
            Mock -CommandName Get-ItemProperty -MockWith { throw "Registry error" }
            Invoke-SteamOptimization
            Assert-MockCalled -CommandName Write-Error -Times 1 -Exactly
            Assert-MockCalled -CommandName Start-Process -Times 0 -Exactly
        }
    }

    Context "Steam is found and running" {
        It "Should execute the full optimization flow and start Steam" {
            Mock -CommandName Get-Process -MockWith { return [pscustomobject]@{ Name = 'steam' } }

            Invoke-SteamOptimization

            Assert-MockCalled -CommandName Close-SteamGracefully -Times 1 -Exactly
            Assert-MockCalled -CommandName Remove-Item -Times 1 -Exactly
            Assert-MockCalled -CommandName Get-ChildItem -Times 2 -Exactly
            Assert-MockCalled -CommandName Start-Process -Times 1 -Exactly
        }

        It "Should execute the optimization flow and start Steam if not running" {
            Mock -CommandName Get-Process -MockWith { return $null }

            Invoke-SteamOptimization

            Assert-MockCalled -CommandName Close-SteamGracefully -Times 0 -Exactly
            Assert-MockCalled -CommandName Remove-Item -Times 0 -Exactly
            Assert-MockCalled -CommandName Start-Process -Times 1 -Exactly
        }
    }
}
