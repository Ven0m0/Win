#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
}

Describe "Backup-GameConfigs.ps1" {
    BeforeAll {
        $script:testDir = New-TemporaryFile | Select-Object -ExpandProperty DirectoryName
        $script:originalUserProfile = $env:USERPROFILE
        $script:originalLocalAppData = $env:LOCALAPPDATA
        $env:USERPROFILE = $testDir
        $env:LOCALAPPDATA = Join-Path $testDir "AppData\Local"
        $script:dotfilesPath = Join-Path $testDir "dotfiles\config\games"
        $script:bo6Source = Join-Path $env:USERPROFILE "Documents\Call of Duty\players"
        $script:arcRaidersSource = Join-Path $env:LOCALAPPDATA "PioneerGame\Saved\SaveGames"
    }

    AfterAll {
        $env:USERPROFILE = $script:originalUserProfile
        $env:LOCALAPPDATA = $script:originalLocalAppData
    }

    BeforeEach {
        Mock -CommandName Write-Host -MockWith { }
        Mock -CommandName Write-BackupStatus -MockWith { }
        Mock -CommandName Test-Path -MockWith { return $false }
        Mock -CommandName New-Item -MockWith { }
        Mock -CommandName Get-ChildItem -MockWith { }
        Mock -CommandName Copy-Item -MockWith { }
    }

    Context "DotfilesPath directory creation" {
        BeforeAll {
            . "$PSScriptRoot/../Scripts/Backup-GameConfigs.ps1"
        }

        It "Should create DotfilesPath directory if it does not exist" {
            Backup-GameConfigs -DotfilesPath $dotfilesPath
            Should -Invoke New-Item -ParameterFilter {
                $Path -eq $dotfilesPath -and $ItemType -eq 'Directory'
            }
        }

        It "Should not create DotfilesPath directory if it already exists" {
            Mock Test-Path -ParameterFilter { $Path -eq $dotfilesPath } -MockWith { return $true }
            Backup-GameConfigs -DotfilesPath $dotfilesPath
            Should -Invoke New-Item -Times 0
        }
    }

    Context "Black Ops 6 backup" {
        BeforeAll {
            . "$PSScriptRoot/../Scripts/Backup-GameConfigs.ps1"
        }

        It "Should skip Black Ops 6 backup if source does not exist" {
            Mock Test-Path -ParameterFilter { $Path -eq $bo6Source } -MockWith { return $false }
            Backup-GameConfigs -DotfilesPath $dotfilesPath
            Should -Invoke Copy-Item -Times 0
            Should -Invoke Write-BackupStatus -ParameterFilter {
                $Message -like "*not found*" -and $Message -like "*Black Ops 6*"
            }
        }

        It "Should create bo6 destination directory if source exists" {
            Mock Test-Path -ParameterFilter { $Path -eq $bo6Source } -MockWith { return $true }
            Mock Test-Path -ParameterFilter { $Path -eq $dotfilesPath } -MockWith { return $true }
            $expectedDest = Join-Path $dotfilesPath "bo6"
            Backup-GameConfigs -DotfilesPath $dotfilesPath
            Should -Invoke New-Item -ParameterFilter {
                $Path -eq $expectedDest
            }
        }

        It "Should copy player folder files" {
            Mock Test-Path -ParameterFilter { $Path -eq $bo6Source } -MockWith { return $true }
            Mock Test-Path -ParameterFilter { $Path -eq $dotfilesPath } -MockWith { return $true }
            Mock Test-Path -ParameterFilter { $Path -like "*bo6*" } -MockWith { return $true }
            Mock Get-ChildItem -ParameterFilter { $Path -eq $bo6Source } -MockWith {
                @(
                    [PSCustomObject]@{ FullName = "test1"; Name = "config.cfg"; Directory = $true }
                )
            }
            Backup-GameConfigs -DotfilesPath $dotfilesPath
            Should -Invoke Copy-Item -Times 1
        }

        It "Should copy root files matching '^s' pattern" {
            Mock Test-Path -ParameterFilter { $Path -eq $bo6Source } -MockWith { return $true }
            Mock Test-Path -ParameterFilter { $Path -like "*bo6*" } -MockWith { return $true }
            Mock Get-ChildItem -ParameterFilter { $Path -eq $bo6Source -and $Directory } -MockWith {
                @()
            }
            Mock Get-ChildItem -ParameterFilter { $Path -eq $bo6Source -and -not $Directory } -MockWith {
                @([PSCustomObject]@{ FullName = "settings.cfg"; Name = "settings.cfg" })
            }
            Backup-GameConfigs -DotfilesPath $dotfilesPath
            Should -Invoke Copy-Item -Times 1
        }
    }

    Context "Arc Raiders backup" {
        BeforeAll {
            . "$PSScriptRoot/../Scripts/Backup-GameConfigs.ps1"
        }

        It "Should skip Arc Raiders backup if source does not exist" {
            Mock Test-Path -ParameterFilter { $Path -eq $arcRaidersSource } -MockWith { return $false }
            Backup-GameConfigs -DotfilesPath $dotfilesPath
            Should -Invoke Write-BackupStatus -ParameterFilter {
                $Message -like "*not found*" -and $Message -like "*Arc Raiders*"
            }
        }

        It "Should copy KeyBindings files" {
            Mock Test-Path -ParameterFilter { $Path -eq $arcRaidersSource } -MockWith { return $true }
            Mock Test-Path -ParameterFilter { $Path -like "*arc-raiders*" } -MockWith { return $true }
            Mock Get-ChildItem -ParameterFilter { $Filter -like "*KeyBindings*" } -MockWith {
                @([PSCustomObject]@{ FullName = "keybinds.sav"; Name = "keybinds.sav" })
            }
            Backup-GameConfigs -DotfilesPath $dotfilesPath
            Should -Invoke Copy-Item -ParameterFilter {
                $Destination -like "*keybinds.sav*"
            }
        }

        It "Should copy GameUserSettings.ini and Engine.ini" {
            Mock Test-Path -ParameterFilter { $Path -eq $arcRaidersSource } -MockWith { return $true }
            Mock Test-Path -ParameterFilter { $Path -like "*arc-raiders*" } -MockWith { return $true }
            Mock Get-ChildItem -ParameterFilter { $Filter -like "*KeyBindings*" } -MockWith { @() }
            Mock Get-ChildItem -ParameterFilter {
                $Path -eq $arcRaidersSource -and $Recurse -and $Filter -in @('GameUserSettings.ini', 'Engine.ini')
            } -MockWith {
                @([PSCustomObject]@{ FullName = "GameUserSettings.ini"; Name = "GameUserSettings.ini" })
            }
            Backup-GameConfigs -DotfilesPath $dotfilesPath
            Should -Invoke Copy-Item -ParameterFilter {
                $Destination -like "*GameUserSettings.ini*"
            }
        }
    }

    Context "Hash validation" {
        BeforeAll {
            . "$PSScriptRoot/../Scripts/Backup-GameConfigs.ps1"
        }

        It "Should overwrite existing files when content differs" {
            Mock Test-Path -ParameterFilter { $Path -eq $bo6Source } -MockWith { return $true }
            Mock Test-Path -ParameterFilter { $Path -like "*bo6*" } -MockWith { return $true }
            Mock Get-ChildItem -ParameterFilter { $Path -eq $bo6Source -and $Directory } -MockWith {
                @([PSCustomObject]@{ FullName = "test.cfg"; Name = "test.cfg"; Directory = $true })
            }
            Backup-GameConfigs -DotfilesPath $dotfilesPath
            Should -Invoke Copy-Item -ParameterFilter { $Force -eq $true }
        }
    }

    Context "Error handling for missing source" {
        BeforeAll {
            . "$PSScriptRoot/../Scripts/Backup-GameConfigs.ps1"
        }

        It "Should handle missing Black Ops 6 source gracefully" {
            Mock Test-Path -ParameterFilter { $Path -eq $bo6Source } -MockWith { return $false }
            { Backup-GameConfigs -DotfilesPath $dotfilesPath } | Should -Not -Throw
        }

        It "Should handle missing Arc Raiders source gracefully" {
            Mock Test-Path -ParameterFilter { $Path -eq $arcRaidersSource } -MockWith { return $false }
            { Backup-GameConfigs -DotfilesPath $dotfilesPath } | Should -Not -Throw
        }
    }
}