#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
}

Describe "Setup-Dotfiles.ps1" {
    Context "Script execution guard" {
        It "Should not execute main logic when dot-sourced" {
            $ErrorActionPreference = 'Stop'
            . "$PSScriptRoot/../Scripts/Setup-Dotfiles.ps1"
            $true | Should -Be $true
        }
    }

    Context "Function Definitions" {
        BeforeAll {
            . "$PSScriptRoot/../Scripts/Setup-Dotfiles.ps1"
        }

        It "Should define required helper functions" {
            Get-Command Start-Bootstrap -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Deploy-Config -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Deploy-ConfigDirectory -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Import-RegistryConfig -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Get-FirefoxDefaultProfilePath -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Get-CallOfDutyPlayersPath -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Get-StarWarsBattlefrontIIRootPath -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Get-StarWarsBattlefrontIIActiveProfilePath -ErrorAction SilentlyContinue | `
                Should -Not -BeNullOrEmpty
            Get-Command Set-CmdAliasAutoRun -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Deploy-StarWarsBattlefrontIIConfig -ErrorAction SilentlyContinue | `
                Should -Not -BeNullOrEmpty
            Get-Command Deploy-CallOfDutyBlackOps6Config -ErrorAction SilentlyContinue | `
                Should -Not -BeNullOrEmpty
            Get-Command Invoke-ConfigManifestEntry -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Install-WingetTool -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    Context "Error resilience" {
        It "Should not abort the manifest loop when one entry throws" {
            . "$PSScriptRoot/../Scripts/Setup-Dotfiles.ps1"

            $deployFailures = [System.Collections.Generic.List[pscustomobject]]::new()
            $configManifest = @(
                @{ Label = 'Throwing entry' },
                @{ Label = 'Later entry' }
            )
            $processed = [System.Collections.Generic.List[string]]::new()

            foreach ($entry in $configManifest) {
                try {
                    if ($entry.Label -eq 'Throwing entry') { throw 'simulated failure' }
                    $processed.Add($entry.Label)
                }
                catch {
                    $err = $_
                    $deployFailures.Add([pscustomobject]@{ Label = $entry.Label; Error = $err.Exception.Message })
                }
            }

            $deployFailures.Count | Should -Be 1
            $deployFailures[0].Label | Should -Be 'Throwing entry'
            $processed | Should -Contain 'Later entry'
        }
    }

    Context "OBS config tracked" {
        It "Should include an OBS Studio config manifest entry" {
            $manifestContent = Get-Content -Path "$PSScriptRoot/../Scripts/Setup-Dotfiles.ps1" -Raw
            $manifestContent | Should -Match "Label\s*=\s*'OBS Studio config'"
            $manifestContent | Should -Match "obs-studio"
        }
    }
}

# Deployment helpers: real files live under $TestDrive, and anything that touches the registry (reg.exe,
# HKCU Command Processor key) is mocked, so the machine is never modified.
Describe "Setup-Dotfiles.ps1 deployment helpers" {
    BeforeAll {
        . "$PSScriptRoot/../Scripts/Setup-Dotfiles.ps1"
    }

    BeforeEach {
        Mock Write-Host { }
        Mock Write-Warning { }
    }

    Context "Deploy-Config" {
        It "Warns and creates nothing when the source is missing" {
            $dest = Join-Path $TestDrive 'missing-src\out.txt'

            Deploy-Config -Source (Join-Path $TestDrive 'nope.txt') -Destination $dest -Label 'Missing'

            Test-Path $dest | Should -BeFalse
            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*source not found*' }
        }

        It "Copies a new file and creates the destination directory" {
            $src = Join-Path $TestDrive 'new-src.txt'
            Set-Content -LiteralPath $src -Value 'hello'
            $dest = Join-Path $TestDrive 'new-dir\nested\new-dst.txt'

            Deploy-Config -Source $src -Destination $dest -Label 'New'

            Get-Content -LiteralPath $dest | Should -Be 'hello'
            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*`[OK`] New deployed*' }
        }

        It "Does not rewrite a destination whose hash already matches" {
            $src = Join-Path $TestDrive 'same-src.txt'
            $dest = Join-Path $TestDrive 'same-dst.txt'
            Set-Content -LiteralPath $src -Value 'same'
            Set-Content -LiteralPath $dest -Value 'same'
            (Get-Item -LiteralPath $dest).LastWriteTimeUtc = [datetime]'2001-01-01'

            Deploy-Config -Source $src -Destination $dest -Label 'Same'

            (Get-Item -LiteralPath $dest).LastWriteTimeUtc | Should -Be ([datetime]'2001-01-01')
            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*UP-TO-DATE*Same*' }
        }

        It "Overwrites a destination that differs" {
            $src = Join-Path $TestDrive 'diff-src.txt'
            $dest = Join-Path $TestDrive 'diff-dst.txt'
            Set-Content -LiteralPath $src -Value 'new content'
            Set-Content -LiteralPath $dest -Value 'old content'

            Deploy-Config -Source $src -Destination $dest -Label 'Diff'

            Get-Content -LiteralPath $dest | Should -Be 'new content'
        }

        It "With -SeedOnly copies when the destination is missing" {
            $src = Join-Path $TestDrive 'seed-src.txt'
            $dest = Join-Path $TestDrive 'seed-dir\seed-dst.txt'
            Set-Content -LiteralPath $src -Value 'seed'

            Deploy-Config -Source $src -Destination $dest -Label 'Seed' -SeedOnly

            Get-Content -LiteralPath $dest | Should -Be 'seed'
        }

        It "With -SeedOnly leaves an existing, different destination untouched" {
            $src = Join-Path $TestDrive 'seedkeep-src.txt'
            $dest = Join-Path $TestDrive 'seedkeep-dst.txt'
            Set-Content -LiteralPath $src -Value 'tracked'
            Set-Content -LiteralPath $dest -Value 'live with token'

            Deploy-Config -Source $src -Destination $dest -Label 'SeedKeep' -SeedOnly

            Get-Content -LiteralPath $dest | Should -Be 'live with token'
            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*SEED-SKIP*SeedKeep*' }
        }

        It "Changes nothing under -WhatIf" {
            $src = Join-Path $TestDrive 'wi-src.txt'
            $dest = Join-Path $TestDrive 'wi-dir\wi-dst.txt'
            Set-Content -LiteralPath $src -Value 'x'

            Deploy-Config -Source $src -Destination $dest -Label 'WhatIf' -WhatIf

            Test-Path (Split-Path $dest -Parent) | Should -BeFalse
        }
    }

    Context "Deploy-ConfigDirectory" {
        BeforeEach {
            $srcDir = Join-Path $TestDrive 'srcdir'
            $dstDir = Join-Path $TestDrive 'dstdir'
            Remove-Item -LiteralPath $srcDir, $dstDir -Recurse -Force -ErrorAction SilentlyContinue
            $null = New-Item -ItemType Directory -Path (Join-Path $srcDir 'sub') -Force
            Set-Content -LiteralPath (Join-Path $srcDir 'a.ini') -Value 'a'
            Set-Content -LiteralPath (Join-Path $srcDir 'b.txt') -Value 'b'
            Set-Content -LiteralPath (Join-Path $srcDir 'sub\c.ini') -Value 'c'
        }

        It "Warns when the source directory is missing" {
            Deploy-ConfigDirectory -SourceDir (Join-Path $TestDrive 'absent') -DestDir $dstDir -Label 'Absent'

            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter {
                $Message -like '*source directory not found*'
            }
            Test-Path $dstDir | Should -BeFalse
        }

        It "Copies only top-level files matching the filter by default" {
            Deploy-ConfigDirectory -SourceDir $srcDir -DestDir $dstDir -Filter '*.ini' -Label 'Flat'

            Test-Path (Join-Path $dstDir 'a.ini') | Should -BeTrue
            Test-Path (Join-Path $dstDir 'b.txt') | Should -BeFalse
            Test-Path (Join-Path $dstDir 'c.ini') | Should -BeFalse
        }

        It "Preserves relative paths with -Recurse" {
            Deploy-ConfigDirectory -SourceDir $srcDir -DestDir $dstDir -Filter '*.ini' -Label 'Deep' -Recurse

            Test-Path (Join-Path $dstDir 'a.ini') | Should -BeTrue
            Test-Path (Join-Path $dstDir 'sub\c.ini') | Should -BeTrue
        }

        It "Skips quietly when no file matches the filter" {
            Deploy-ConfigDirectory -SourceDir $srcDir -DestDir $dstDir -Filter '*.zzz' -Label 'None'

            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*no files matching*' }
            Test-Path $dstDir | Should -BeFalse
        }

        It "Copies nothing under -WhatIf" {
            Deploy-ConfigDirectory -SourceDir $srcDir -DestDir $dstDir -Label 'WhatIf' -WhatIf

            Test-Path $dstDir | Should -BeFalse
        }
    }

    Context "Import-RegistryConfig" {
        BeforeEach {
            $regState = @{ Exit = 0; Calls = [System.Collections.Generic.List[string]]::new() }
            Mock reg.exe {
                $regState.Calls.Add((@($args | ForEach-Object { $_ }) -join ' '))
                $global:LASTEXITCODE = $regState.Exit
            }
            $regFile = Join-Path $TestDrive 'tweak.reg'
            Set-Content -LiteralPath $regFile -Value 'Windows Registry Editor Version 5.00'
        }

        It "Warns and does not call reg.exe when the file is missing" {
            Import-RegistryConfig -Source (Join-Path $TestDrive 'gone.reg') -Label 'Gone'

            $regState.Calls.Count | Should -Be 0
            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*source not found*' }
        }

        It "Imports the file through reg.exe import" {
            Import-RegistryConfig -Source $regFile -Label 'Tweak'

            $regState.Calls | Should -Be @("import $regFile")
            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*`[OK`] Tweak imported*' }
        }

        It "Warns with the exit code when reg.exe fails" {
            $regState.Exit = 1

            Import-RegistryConfig -Source $regFile -Label 'Tweak'

            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*exit code: 1*' }
        }

        It "Does not touch the registry under -WhatIf" {
            Import-RegistryConfig -Source $regFile -Label 'Tweak' -WhatIf

            $regState.Calls.Count | Should -Be 0
        }
    }

    Context "Set-CmdAliasAutoRun" {
        BeforeEach {
            $aliasScript = Join-Path $TestDrive 'alias.cmd'
            Set-Content -LiteralPath $aliasScript -Value '@echo off'
            $autoRunState = @{ Current = $null }
            Mock Get-ItemProperty {
                if ($autoRunState.Current) { [pscustomobject]@{ AutoRun = $autoRunState.Current } }
            }
            # Test-Path on the HKCU key is a read-only probe, so it stays real; writes are mocked below
            Mock New-Item { }
            Mock New-ItemProperty { }
        }

        It "Warns when the alias script is missing" {
            Set-CmdAliasAutoRun -AliasScript (Join-Path $TestDrive 'nope.cmd') -Label 'Aliases'

            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*alias script not found*' }
            Should -Invoke New-ItemProperty -Times 0 -Exactly
        }

        It "Sets AutoRun to the alias snippet when none exists" {
            Set-CmdAliasAutoRun -AliasScript $aliasScript -Label 'Aliases'

            Should -Invoke New-ItemProperty -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'AutoRun' -and $Value -eq "if exist `"$aliasScript`" call `"$aliasScript`""
            }
        }

        It "Appends to an existing AutoRun command instead of replacing it" {
            $autoRunState.Current = 'echo hi'

            Set-CmdAliasAutoRun -AliasScript $aliasScript -Label 'Aliases'

            Should -Invoke New-ItemProperty -Times 1 -Exactly -ParameterFilter {
                $Value -like "echo hi & if exist*$aliasScript*"
            }
        }

        It "Does nothing when AutoRun already references the script" {
            $autoRunState.Current = "if exist `"$aliasScript`" call `"$aliasScript`""

            Set-CmdAliasAutoRun -AliasScript $aliasScript -Label 'Aliases'

            Should -Invoke New-ItemProperty -Times 0 -Exactly
            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*UP-TO-DATE*' }
        }

        It "Writes nothing under -WhatIf" {
            Set-CmdAliasAutoRun -AliasScript $aliasScript -Label 'Aliases' -WhatIf

            Should -Invoke New-ItemProperty -Times 0 -Exactly
            Should -Invoke New-Item -Times 0 -Exactly
        }
    }

    Context "Game and browser path discovery" {
        It "Get-FirefoxDefaultProfilePath returns null when profiles.ini does not exist" {
            $oldAppData = $env:APPDATA
            try {
                $env:APPDATA = Join-Path $TestDrive 'no-appdata'
                Get-FirefoxDefaultProfilePath | Should -BeNullOrEmpty
            }
            finally {
                $env:APPDATA = $oldAppData
            }
        }

        It "Get-CallOfDutyPlayersPath returns nothing when no folder exists" {
            Mock Test-Path { $false }
            Get-CallOfDutyPlayersPath | Should -BeNullOrEmpty
        }

        It "Get-CallOfDutyPlayersPath returns the players folder when present" {
            Mock Test-Path { $true }
            $paths = @(Get-CallOfDutyPlayersPath)
            $paths.Count | Should -Be 1
            $paths[0] | Should -BeLike '*Call of Duty BO6\players'
        }

        Context "Deploy-CallOfDutyBlackOps6Config" {
            BeforeEach {
                $bo6Source = Join-Path $TestDrive 'bo6-src'
                $steamPlayers = Join-Path $TestDrive 'Call of Duty BO6\players'
                $bnetPlayers = Join-Path $TestDrive 'Call of Duty\players'
                Remove-Item -LiteralPath $steamPlayers, $bnetPlayers -Recurse -Force -ErrorAction SilentlyContinue
                $null = New-Item -ItemType Directory -Path $bo6Source, $steamPlayers, $bnetPlayers -Force
                Set-Content -Path (Join-Path $bo6Source 's.1.0.cod24.txt0') -Value 'TextureQuality = 0'
                Mock Get-CallOfDutyPlayersPath { $steamPlayers, $bnetPlayers }
            }

            It "Writes txt0 and txt1 with the source hash into every players folder, leaving .m alone" {
                Deploy-CallOfDutyBlackOps6Config -SourceDir $bo6Source -Label 'BO6' 6>$null
                $srcHash = (Get-FileHash (Join-Path $bo6Source 's.1.0.cod24.txt0')).Hash
                foreach ($players in $steamPlayers, $bnetPlayers) {
                    foreach ($slot in 's.1.0.cod24.txt0', 's.1.0.cod24.txt1') {
                        (Get-FileHash (Join-Path $players $slot)).Hash | Should -Be $srcHash
                    }
                    Test-Path (Join-Path $players 's.1.0.cod24.m') | Should -BeFalse
                }
            }

            It "Deploys keybinds only into numeric profile folders that already have a keybinds file" {
                Set-Content -Path (Join-Path $bo6Source 'keybinds.cod24.kb') -Value 'new-binds'
                $withBinds = Join-Path $steamPlayers '486616463'
                $withoutBinds = Join-Path $steamPlayers '111'
                $notNumeric = Join-Path $steamPlayers 'other'
                $null = New-Item -ItemType Directory -Path $withBinds, $withoutBinds, $notNumeric -Force
                Set-Content -Path (Join-Path $withBinds 'keybinds.cod24.kb') -Value 'old-binds'
                Set-Content -Path (Join-Path $notNumeric 'keybinds.cod24.kb') -Value 'old-binds'
                Mock Get-CallOfDutyPlayersPath { $steamPlayers }
                Deploy-CallOfDutyBlackOps6Config -SourceDir $bo6Source -Label 'BO6' 6>$null
                $srcHash = (Get-FileHash (Join-Path $bo6Source 'keybinds.cod24.kb')).Hash
                (Get-FileHash (Join-Path $withBinds 'keybinds.cod24.kb')).Hash | Should -Be $srcHash
                Test-Path (Join-Path $withoutBinds 'keybinds.cod24.kb') | Should -BeFalse
                (Get-Content (Join-Path $notNumeric 'keybinds.cod24.kb')) | Should -Be 'old-binds'
            }

            It "Warns and writes nothing when no players folder exists" {
                Mock Get-CallOfDutyPlayersPath { @() }
                Mock Write-Warning { }
                Deploy-CallOfDutyBlackOps6Config -SourceDir $bo6Source -Label 'BO6'
                Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter {
                    $Message -like '*players directory not found*'
                }
                Test-Path (Join-Path $steamPlayers 's.1.0.cod24.txt0') | Should -BeFalse
            }
        }

        It "Get-StarWarsBattlefrontIIRootPath points into Documents" {
            Get-StarWarsBattlefrontIIRootPath | Should -BeLike '*Star Wars Battlefront II'
        }

        Context "Get-StarWarsBattlefrontIIActiveProfilePath" {
            BeforeEach {
                $bf2Root = Join-Path $TestDrive 'bf2'
                Remove-Item -LiteralPath $bf2Root -Recurse -Force -ErrorAction SilentlyContinue
                Mock Get-StarWarsBattlefrontIIRootPath { $bf2Root }
            }

            It "Returns null when there is no Profiles folder" {
                Get-StarWarsBattlefrontIIActiveProfilePath | Should -BeNullOrEmpty
            }

            It "Returns the profile named by GlobalSettings.setDefaultUser" {
                $profiles = Join-Path $bf2Root 'Profiles'
                $null = New-Item -ItemType Directory -Path (Join-Path $profiles '0001'), (Join-Path $profiles '0002')
                Set-Content -LiteralPath (Join-Path $profiles 'Global.con') -Value 'GlobalSettings.setDefaultUser "0002"'

                Get-StarWarsBattlefrontIIActiveProfilePath | Should -Be (Join-Path $profiles '0002')
            }

            It "Falls back to the first non-Default profile when Global.con points nowhere" {
                $profiles = Join-Path $bf2Root 'Profiles'
                $null = New-Item -ItemType Directory -Path (Join-Path $profiles 'Default'), (Join-Path $profiles '0003')
                Set-Content -LiteralPath (Join-Path $profiles 'Global.con') -Value 'GlobalSettings.setDefaultUser "9999"'

                Get-StarWarsBattlefrontIIActiveProfilePath | Should -Be (Join-Path $profiles '0003')
            }

            It "Returns null when only the Default profile exists" {
                $null = New-Item -ItemType Directory -Path (Join-Path $bf2Root 'Profiles\Default')

                Get-StarWarsBattlefrontIIActiveProfilePath | Should -BeNullOrEmpty
            }
        }
    }
}
