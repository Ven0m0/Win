#Requires -Version 5.1

BeforeDiscovery {
    $scriptExists = Test-Path "$PSScriptRoot/../Scripts/Backup-GameConfigs.ps1"
}

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
}

Describe "Backup-GameConfig.ps1" -Skip:(-not $scriptExists) {
    BeforeAll {
        # Pester v5 runs BeforeAll even in skipped Describes; guard to avoid throwing.
        if (-not (Test-Path "$PSScriptRoot/../Scripts/Backup-GameConfigs.ps1")) { return }
        . "$PSScriptRoot/../Scripts/Backup-GameConfigs.ps1"
        $script:testDir = New-TemporaryFile | Select-Object -ExpandProperty DirectoryName
        $script:dotfilesPath = Join-Path $testDir "dotfiles\config\games"
        $script:bo6Source = Join-Path $testDir "Documents\Call of Duty BO6\players"
        $script:arcRaidersSource = Join-Path $env:LOCALAPPDATA "PioneerGame\Saved\SaveGames"
    }

    BeforeEach {
        Mock -CommandName Write-Host -MockWith { }
        Mock -CommandName Write-ColorOutput -MockWith { }
        Mock -CommandName Test-Path -MockWith { return $false }
        Mock -CommandName New-Item -MockWith { }
        Mock -CommandName Get-ChildItem -MockWith { }
        Mock -CommandName Copy-Item -MockWith { }
    }

    Context "DotfilesPath directory creation" {
        It "Should create DotfilesPath directory if it does not exist" {
            Backup-GameConfig -DotfilesPath $dotfilesPath
            Should -Invoke New-Item -ParameterFilter {
                $Path -eq $dotfilesPath -and $ItemType -eq 'Directory'
            }
        }

        It "Should not create DotfilesPath directory if it already exists" {
            # Ensure-Directory probes with -LiteralPath, not -Path
            Mock Test-Path -ParameterFilter { $LiteralPath -eq $dotfilesPath } -MockWith { return $true }
            Backup-GameConfig -DotfilesPath $dotfilesPath
            Should -Invoke New-Item -Times 0
        }
    }

    Context "Black Ops 6 backup" {
        It "Should skip Black Ops 6 backup if source does not exist" {
            Mock Test-Path -ParameterFilter { $Path -eq $bo6Source } -MockWith { return $false }
            Backup-GameConfig -DotfilesPath $dotfilesPath
            Should -Invoke Copy-Item -Times 0
            Should -Invoke Write-ColorOutput -ParameterFilter {
                $Object -like "*not found*" -and $Object -like "*Black Ops 6*"
            }
        }

        It "Should create bo6 destination directory if source exists" {
            Mock Test-Path -ParameterFilter { $Path -eq $bo6Source } -MockWith { return $true }
            Mock Test-Path -ParameterFilter { $Path -eq $dotfilesPath } -MockWith { return $true }
            $expectedDest = Join-Path $dotfilesPath "bo6"
            Backup-GameConfig -DotfilesPath $dotfilesPath
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
            # Files inside the mocked player folder (second-level enumeration)
            Mock Get-ChildItem -ParameterFilter { $Path -eq 'test1' } -MockWith {
                @([PSCustomObject]@{ FullName = 'test1\config.cfg'; Name = 'config.cfg' })
            }
            Backup-GameConfig -DotfilesPath $dotfilesPath
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
            Backup-GameConfig -DotfilesPath $dotfilesPath
            Should -Invoke Copy-Item -Times 1
        }
    }

    Context "Arc Raiders backup" {
    }
}
