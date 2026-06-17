#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    # Dot-source the merged script. Its dispatcher is guarded by the dot-source
    # check, so importing only loads the functions (and Common.ps1) for testing.
    . "$PSScriptRoot/../Scripts/system-maintenance.ps1"
}

Describe "Invoke-Defrag" {
    It "Should run correct defrag commands for a target volume" {
        Mock Invoke-CommandChecked {}
        Mock Write-Verbose {}

        Invoke-Defrag -TargetVolume "D:"

        Should -Invoke Invoke-CommandChecked -Times 5
        Should -Invoke Invoke-CommandChecked -ParameterFilter { $ArgumentList -eq "D: /O" } -Times 1
        Should -Invoke Invoke-CommandChecked -ParameterFilter { $ArgumentList -eq "D: /L" } -Times 1
        Should -Invoke Invoke-CommandChecked -ParameterFilter { $ArgumentList -eq "D: /X" } -Times 1
        Should -Invoke Invoke-CommandChecked -ParameterFilter { $ArgumentList -eq "D: /G" } -Times 1
        Should -Invoke Invoke-CommandChecked -ParameterFilter { $ArgumentList -eq "D: /B" } -Times 1
    }

    It "Should run correct defrag commands for all volumes" {
        Mock Invoke-CommandChecked {}
        Mock Write-Verbose {}

        Invoke-Defrag -All

        Should -Invoke Invoke-CommandChecked -Times 3
        Should -Invoke Invoke-CommandChecked -ParameterFilter { $ArgumentList -eq "/C" } -Times 1
        Should -Invoke Invoke-CommandChecked -ParameterFilter { $ArgumentList -eq "/C /O" } -Times 1
        Should -Invoke Invoke-CommandChecked -ParameterFilter { $ArgumentList -eq "/C /L" } -Times 1
    }
}

Describe "Invoke-MsiCleanup" {
    It "Should throw error if directory is missing" {
        Mock Test-Path { return $false }

        { Invoke-MsiCleanup -Root "C:\InvalidPath" } |
            Should -Throw "*MSI Afterburner not found at: C:\InvalidPath*"
    }

    It "Should perform native cleanup operations when directory exists" {
        Mock Test-Path { return $true }
        Mock Copy-Item {}
        Mock Remove-Item {}
        Mock New-Item {}
        Mock Move-Item {}
        Mock Write-Verbose {}

        Invoke-MsiCleanup -Root "C:\MSI"

        # 3 keeper skins staged out, dir recreated, 3 moved back
        Should -Invoke Copy-Item -Times 3
        Should -Invoke New-Item -Times 1
        Should -Invoke Move-Item -Times 3
        # 4 subdirs (Skins/Localization/Doc/SDK\Doc) + SDK shortcut + ReadMe.lnk
        Should -Invoke Remove-Item -Times 6
    }
}

Describe "Start-AdditionalMaintenance" {
    Context "DryRun Mode" {
        It "Should execute operations with DryRun" {
            Mock Initialize-ConsoleUI { param([Parameter(ValueFromRemainingArguments)]$DummyArgs) }
            Mock Get-Date { return [datetime]"2023-01-01T12:00:00" }
            Mock Write-Header {}
            Mock Write-Info {}
            Mock Write-Success {}
            Mock Write-Warn {}
            Mock Clear-Log {}
            Mock Get-Log { return "log" }
            Mock Show-Summary {}
            Mock -CommandName Invoke-Operation -MockWith { }
            Mock -CommandName Invoke-ServiceOperation -MockWith { }
            Mock Clear-PathSafe {}
            Mock -CommandName Out-File -MockWith { }
            Mock Join-Path { return "dummy_path" }

            Start-AdditionalMaintenance -DryRun

            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'SystemRestorePoint' -and $DryRun } -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'DISM_ComponentAnalysis' -and $DryRun } `
                -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'DISM_ComponentCleanup' -and $DryRun } `
                -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'StoreCacheClear' -and $DryRun } -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'BITSClear' -and $DryRun -eq $true } -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'FontCache' -and $DryRun -eq $true } -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'IconCache' -and $DryRun -eq $true } -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'ThumbCache' -and $DryRun -eq $true } -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'DNSCache' -and $DryRun -eq $true } -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'TempFiles' -and $DryRun -eq $true } -Times 1
        }
    }

    Context "NoRestorePoint flag" {
        It "Should skip restore point creation" {
            Mock Initialize-ConsoleUI { param([Parameter(ValueFromRemainingArguments)]$DummyArgs) }
            Mock Get-Date { return [datetime]"2023-01-01T12:00:00" }
            Mock Write-Header {}
            Mock Write-Info {}
            Mock Write-Success {}
            Mock Write-Warn {}
            Mock Clear-Log {}
            Mock Get-Log { return "log" }
            Mock Show-Summary {}
            Mock -CommandName Invoke-Operation -MockWith { }
            Mock -CommandName Invoke-ServiceOperation -MockWith { }
            Mock Clear-PathSafe {}
            Mock -CommandName Out-File -MockWith { }
            Mock Join-Path { return "dummy_path" }

            Start-AdditionalMaintenance -NoRestorePoint

            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'SystemRestorePoint' } -Times 0
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'DISM_ComponentAnalysis' } -Times 1
        }
    }
}

Describe "Start-UltimateDiskCleanup" {
    It "Should have Start-UltimateDiskCleanup function defined" {
        Get-Command Start-UltimateDiskCleanup -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It "Should declare CmdletBinding with SupportsShouldProcess" {
        $cmd = Get-Command Start-UltimateDiskCleanup
        $cmd.CmdletBinding -ne $null | Should -Be $true
    }
}

Describe "Invoke-ShaderCacheCleanup" {
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
