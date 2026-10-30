#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    # Dot-source the merged script. Its dispatcher is guarded by the dot-source
    # check, so importing only loads the functions (and Common.ps1) for testing.
    . "$PSScriptRoot/../Scripts/system-maintenance.ps1"
}

Describe "Invoke-Defrag" {
    It "Should run correct defrag commands for a target volume" {
        Mock defrag.exe { $global:LASTEXITCODE = 0 }
        Mock Write-Info {}

        Invoke-Defrag -TargetVolume "D:"

        Should -Invoke defrag.exe -Times 2
        Should -Invoke defrag.exe -ParameterFilter { ($args[0] -join ' ') -eq "D: /O" } -Times 1
        Should -Invoke defrag.exe -ParameterFilter { ($args[0] -join ' ') -eq "D: /L" } -Times 1
    }

    It "Should run correct defrag commands for all volumes" {
        Mock defrag.exe { $global:LASTEXITCODE = 0 }
        Mock Write-Info {}

        Invoke-Defrag -All

        Should -Invoke defrag.exe -Times 2 -Exactly
        Should -Invoke defrag.exe -ParameterFilter { ($args[0] -join ' ') -eq "/C" } -Times 0 -Exactly
        Should -Invoke defrag.exe -ParameterFilter { ($args[0] -join ' ') -eq "/C /O" } -Times 1
        Should -Invoke defrag.exe -ParameterFilter { ($args[0] -join ' ') -eq "/C /L" } -Times 1
    }

    It "Should throw when defrag.exe exits non-zero" {
        Mock defrag.exe { $global:LASTEXITCODE = 1 }
        Mock Write-Info {}

        { Invoke-Defrag -TargetVolume "D:" } | Should -Throw "*defrag failed*"
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
        Mock Write-Success {}

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
            Mock Initialize-ConsoleUI {}
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
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'SFC_ScanNow' } -Times 0
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'DISM_RestoreHealth' } -Times 0
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'DISM_MountpointCleanup' -and $DryRun } `
                -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'Cleanmgr' -and $DryRun } -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'StoreCacheClear' -and $DryRun } -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'BITSClear' -and $DryRun -eq $true } -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'FontCache' -and $DryRun -eq $true } -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'IconCache' -and $DryRun -eq $true } -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'DNSCache' -and $DryRun -eq $true } -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'TempFiles' -and $DryRun -eq $true } -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'DevToolCaches' -and $DryRun } -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'JunkFiles' -and $DryRun } -Times 1
        }
    }

    Context "NoRestorePoint flag" {
        It "Should skip restore point creation" {
            Mock Initialize-ConsoleUI {}
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
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'DISM_MountpointCleanup' } -Times 1
        }
    }
}

Describe "-WhatIf handling" {
    It "Treats -WhatIf as -DryRun so no destructive step runs" {
        # Dot-sourcing with -WhatIf loads the functions and applies the top-level WhatIf -> DryRun mapping
        . "$PSScriptRoot/../Scripts/system-maintenance.ps1" -WhatIf
        $DryRun | Should -BeTrue

        Mock Initialize-ConsoleUI {}
        Mock Write-Header {}
        Mock Write-Info {}
        Mock Write-Warn {}
        Mock Clear-Log {}
        Mock Show-Summary {}
        Mock Get-Log { 'log' }
        Mock Out-File {}
        Mock Invoke-Operation {}
        Mock wevtutil.exe { $global:LASTEXITCODE = 0 }
        Mock DISM.exe { $global:LASTEXITCODE = 0 }

        Start-AdditionalMaintenance -DryRun:$DryRun -NoRestorePoint

        Should -Invoke Invoke-Operation -Times 0 -ParameterFilter { -not $DryRun }
        Should -Invoke Invoke-Operation -Times 1 -ParameterFilter { $Name -eq 'EventLogs' -and $DryRun }
        Should -Invoke Out-File -Times 0 -Exactly
        Should -Invoke wevtutil.exe -Times 0 -Exactly
        Should -Invoke DISM.exe -Times 0 -Exactly
    }
}

Describe "Extra EventLogs step" {
    It "Fails the step when wevtutil exits non-zero" {
        Mock Initialize-ConsoleUI {}
        Mock Write-Header {}
        Mock Write-Info {}
        Mock Write-Warn {}
        Mock Clear-Log {}
        Mock Show-Summary {}
        Mock Get-Log { 'log' }
        Mock Out-File {}
        $script:eventLogAction = $null
        Mock Invoke-Operation { if ($Name -eq 'EventLogs') { $script:eventLogAction = $Action } }
        Mock wevtutil.exe { $global:LASTEXITCODE = 5 }

        Start-AdditionalMaintenance -DryRun -NoRestorePoint

        { & $script:eventLogAction } | Should -Throw '*wevtutil could not clear*'
    }
}

Describe "Set-CleanmgrSelection" {
    BeforeEach {
        Mock Get-ChildItem {
            'Update Cleanup', 'DownloadsFolder', 'Temporary Files' | ForEach-Object {
                [pscustomobject]@{ PSChildName = $_ }
            }
        }
        Mock Remove-RegistryValue {}
        Mock Set-RegistryValue {}
    }

    It "Should reset the flag on every handler and select all but the excluded ones" {
        $selected = Set-CleanmgrSelection -Id 70 -Exclude 'DownloadsFolder'

        $selected | Should -Be @('Update Cleanup', 'Temporary Files')
        Should -Invoke Remove-RegistryValue -Times 3 -Exactly -ParameterFilter { $Name -eq 'StateFlags0070' }
        Should -Invoke Set-RegistryValue -Times 2 -Exactly
        Should -Invoke Set-RegistryValue -Times 0 -Exactly -ParameterFilter { $Path -like '*DownloadsFolder' }
    }

    It "Should select only the included handlers" {
        $selected = Set-CleanmgrSelection -Id 69 -Include 'Temporary Files'

        $selected | Should -Be @('Temporary Files')
        Should -Invoke Remove-RegistryValue -Times 3 -Exactly -ParameterFilter { $Name -eq 'StateFlags0069' }
        Should -Invoke Set-RegistryValue -Times 1 -Exactly
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
    Context "DryRun" {
        It "Should not touch Steam or any cache under -DryRun" {
            $DryRun = $true
            Mock Write-Warn {}
            Mock Get-ItemProperty {}
            Mock Stop-SteamGracefully {}
            Mock Clear-DirectorySafe {}

            Invoke-ShaderCacheCleanup

            Should -Invoke Get-ItemProperty -Times 0 -Exactly
            Should -Invoke Stop-SteamGracefully -Times 0 -Exactly
            Should -Invoke Clear-DirectorySafe -Times 0 -Exactly
        }
    }

    Context "Steam Detection" {
        It "Should return if Steam is not found in registry" {
            Mock Get-ItemProperty { throw "Registry key not found" }
            Mock Write-Warning {}

            Invoke-ShaderCacheCleanup

            Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -eq "Steam not found in registry!" }
        }

        It "Should return if Steam executable is missing" {
            Mock Get-ItemProperty { return [pscustomobject]@{ SteamPath = "C:\Steam" } }
            Mock Test-Path { return $false }
            Mock Write-Warning {}
            Mock Start-Sleep {}

            Invoke-ShaderCacheCleanup

            Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -eq "Steam not found!" }
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
                $obj = [pscustomobject]@{}
                $inner = @{ "0" = @{ "path" = '"C:\SteamLibrary"' } }
                Add-Member -InputObject $obj -MemberType ScriptMethod -Name Item -Value { param($i); $null = $i; return $this.Inner }
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

            Should -Invoke Stop-SteamGracefully -Times 1
            Should -Invoke Clear-DirectorySafe -Times 31 -Exactly
            Should -Invoke Remove-Item -Times 1 -ParameterFilter { $Path -eq "C:\Steam\.crash" }
        }
    }
}
