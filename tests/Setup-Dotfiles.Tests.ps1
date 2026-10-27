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

        It "Should track the rtk global filters source" {
            Test-Path -Path "$PSScriptRoot/../user/.dotfiles/config/rtk/filters.toml" | Should -BeTrue
        }

        It "Should track the rtk config source" {
            Test-Path -Path "$PSScriptRoot/../user/.dotfiles/config/rtk/config.toml" | Should -BeTrue
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

# App/game resolvers live in Setup-Dotfiles.Apps.ps1; they are exercised against fake trees under $TestDrive.
Describe "Setup-Dotfiles.Apps.ps1 resolvers" {
    BeforeAll {
        . "$PSScriptRoot/../Scripts/Setup-Dotfiles.ps1"
    }

    BeforeEach {
        Mock Write-Host { }
        Mock Write-Warning { }
    }

    Context "Get-StarWarsBattlefrontIIActiveProfilePath" {
        BeforeEach {
            $bf2Root = Join-Path $TestDrive 'bf2'
            Remove-Item -LiteralPath $bf2Root -Recurse -Force -ErrorAction SilentlyContinue
            Mock Get-StarWarsBattlefrontIIRootPath { $bf2Root }
        }

        It "Returns null when there is no Profiles directory" {
            $null = New-Item -ItemType Directory -Path $bf2Root -Force

            Get-StarWarsBattlefrontIIActiveProfilePath | Should -BeNullOrEmpty
        }

        It "Honors the default user named in Global.con" {
            $profiles = Join-Path $bf2Root 'Profiles'
            $null = New-Item -ItemType Directory -Path (Join-Path $profiles '0001'), (Join-Path $profiles '0002') -Force
            Set-Content -LiteralPath (Join-Path $profiles 'Global.con') -Value 'GlobalSettings.setDefaultUser "0002"'

            Get-StarWarsBattlefrontIIActiveProfilePath | Should -Be (Join-Path $profiles '0002')
        }

        It "Falls back to the first non-Default profile when Global.con is absent" {
            $profiles = Join-Path $bf2Root 'Profiles'
            $null = New-Item -ItemType Directory -Path (Join-Path $profiles 'Default'), (Join-Path $profiles '0007') -Force

            Get-StarWarsBattlefrontIIActiveProfilePath | Should -Be (Join-Path $profiles '0007')
        }
    }

    # PSIni is stubbed (Import-Ini, Get-Module, Import-Module mocked) so the tests are deterministic
    # and never touch the network or the installed module set.
    Context "Get-FirefoxDefaultProfilePath" {
        BeforeAll {
            function Import-Ini { param($Path) }
        }

        BeforeEach {
            $script:savedAppData = $env:APPDATA
            $env:APPDATA = Join-Path $TestDrive 'appdata'
            $ffDir = Join-Path $env:APPDATA 'Mozilla\Firefox'
            Remove-Item -LiteralPath $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
            $null = New-Item -ItemType Directory -Path $ffDir -Force
            # Existence check only; the parsed content comes from the Import-Ini mock.
            Set-Content -LiteralPath (Join-Path $ffDir 'profiles.ini') -Value ''
            Mock Get-Module { [pscustomobject]@{ Name = 'PsIni' } }
            Mock Import-Module { }
        }

        AfterEach {
            $env:APPDATA = $script:savedAppData
        }

        It "Returns the Default=1 profile as an absolute path for relative entries" {
            Mock Import-Ini {
                [ordered]@{
                    Profile0 = [ordered]@{ Name = 'other'; IsRelative = '1'; Path = 'Profiles/other.x' }
                    Profile1 = [ordered]@{
                        Name = 'main'; IsRelative = '1'; Path = 'Profiles/main.default'; Default = '1'
                    }
                }
            }

            Get-FirefoxDefaultProfilePath | Should -Be (Join-Path $ffDir 'Profiles/main.default')
        }

        It "Falls back to the first profile when none is marked Default" {
            Mock Import-Ini {
                [ordered]@{ Profile0 = [ordered]@{ Name = 'first'; IsRelative = '1'; Path = 'Profiles/first.x' } }
            }

            Get-FirefoxDefaultProfilePath | Should -Be (Join-Path $ffDir 'Profiles/first.x')
        }

        It "Returns an absolute Path unchanged" {
            $abs = Join-Path $TestDrive 'abs-profile'
            Mock Import-Ini -MockWith ([scriptblock]::Create(
                    "[ordered]@{ Profile0 = [ordered]@{ Name = 'abs'; IsRelative = '0'; Path = '$abs'; Default = '1' } }"))

            Get-FirefoxDefaultProfilePath | Should -Be $abs
        }

        It "Treats a profile without IsRelative as absolute instead of throwing" {
            $abs = Join-Path $TestDrive 'no-isrelative'
            Mock Import-Ini -MockWith ([scriptblock]::Create(
                    "[ordered]@{ Profile0 = [ordered]@{ Name = 'x'; Path = '$abs'; Default = '1' } }"))

            Get-FirefoxDefaultProfilePath | Should -Be $abs
        }

        It "Returns null when profiles.ini has no Profile sections" {
            Mock Import-Ini { [ordered]@{ General = [ordered]@{ StartWithLastProfile = '1' } } }

            Get-FirefoxDefaultProfilePath | Should -BeNullOrEmpty
        }

        It "Returns null without PSIni installed" {
            Mock Get-Module { }

            Get-FirefoxDefaultProfilePath | Should -BeNullOrEmpty
        }
    }

    Context "Resolve-QtEmulatorConfigPath" {
        BeforeEach {
            $script:savedScoop = $env:SCOOP
            $script:savedAppData = $env:APPDATA
            $env:SCOOP = Join-Path $TestDrive 'scoop'
            $env:APPDATA = Join-Path $TestDrive 'appdata'
            Remove-Item -LiteralPath $env:SCOOP, $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
        }

        AfterEach {
            $env:SCOOP = $script:savedScoop
            $env:APPDATA = $script:savedAppData
        }

        It "Prefers the scoop persist directory" {
            $null = New-Item -ItemType Directory -Path (Join-Path $env:SCOOP 'persist\eden') -Force
            $null = New-Item -ItemType Directory -Path (Join-Path $env:APPDATA 'eden') -Force

            Resolve-QtEmulatorConfigPath -ScoopApp 'eden' -AppDataDir 'eden' |
                Should -Be (Join-Path $env:SCOOP 'persist\eden\user\config\qt-config.ini')
        }

        It "Falls back to the AppData directory" {
            $null = New-Item -ItemType Directory -Path (Join-Path $env:APPDATA 'eden') -Force

            Resolve-QtEmulatorConfigPath -ScoopApp 'eden' -AppDataDir 'eden' |
                Should -Be (Join-Path $env:APPDATA 'eden\config\qt-config.ini')
        }

        It "Returns nothing when the emulator is not installed" {
            Resolve-QtEmulatorConfigPath -ScoopApp 'eden' -AppDataDir 'eden' | Should -BeNullOrEmpty
        }
    }
}

Describe "Invoke-ConfigManifestEntry dispatch" {
    BeforeAll {
        . "$PSScriptRoot/../Scripts/Setup-Dotfiles.ps1"
        $script:cfgRoot = Join-Path $TestDrive 'cfg'
        $null = New-Item -ItemType Directory -Path (Join-Path $script:cfgRoot 'app') -Force
        Set-Content -LiteralPath (Join-Path $script:cfgRoot 'app\f.txt') -Value 'x'
    }

    BeforeEach {
        Mock Write-Host { }
        Mock Write-Warning { }
        Mock Deploy-Config { }
        Mock Deploy-ConfigDirectory { }
        Mock Import-RegistryConfig { }
    }

    It "Skips with a warning when the source is missing" {
        $entry = @{ Label = 'L'; Path = 'nope'; Mode = 'file' }

        Invoke-ConfigManifestEntry -Entry $entry -ConfigRoot $script:cfgRoot

        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*source not found*' }
        Should -Invoke Deploy-Config -Times 0 -Exactly
    }

    It "'file' deploys to the resolved destination, passing SeedOnly" {
        $entry = @{
            Label = 'L'; Path = 'app\f.txt'; Mode = 'file'; SeedOnly = $true
            ResolveDestination = { 'D:\dest.txt' }
        }

        Invoke-ConfigManifestEntry -Entry $entry -ConfigRoot $script:cfgRoot

        Should -Invoke Deploy-Config -Times 1 -Exactly -ParameterFilter {
            $Destination -eq 'D:\dest.txt' -and $SeedOnly -and $Label -eq 'L'
        }
    }

    It "'file' warns with the skip reason when no destination resolves" {
        $entry = @{
            Label = 'L'; Path = 'app\f.txt'; Mode = 'file'
            ResolveDestination = { $null }; GetSkipReason = { 'app not installed' }
        }

        Invoke-ConfigManifestEntry -Entry $entry -ConfigRoot $script:cfgRoot

        Should -Invoke Deploy-Config -Times 0 -Exactly
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*app not installed*' }
    }

    It "'directory' forwards filter and recurse to Deploy-ConfigDirectory" {
        $entry = @{
            Label = 'L'; Path = 'app'; Mode = 'directory'; Filter = '*.txt'; Recurse = $true
            ResolveDestination = { 'D:\dir' }
        }

        Invoke-ConfigManifestEntry -Entry $entry -ConfigRoot $script:cfgRoot

        Should -Invoke Deploy-ConfigDirectory -Times 1 -Exactly -ParameterFilter {
            $DestDir -eq 'D:\dir' -and $Filter -eq '*.txt' -and $Recurse
        }
    }

    It "'registry' imports the source file" {
        $entry = @{ Label = 'L'; Path = 'app\f.txt'; Mode = 'registry' }

        Invoke-ConfigManifestEntry -Entry $entry -ConfigRoot $script:cfgRoot

        Should -Invoke Import-RegistryConfig -Times 1 -Exactly -ParameterFilter { $Label -eq 'L' }
    }

    It "'manual' only warns with the note" {
        $entry = @{ Label = 'L'; Path = 'app\f.txt'; Mode = 'manual'; Note = 'do it by hand' }

        Invoke-ConfigManifestEntry -Entry $entry -ConfigRoot $script:cfgRoot

        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*do it by hand*' }
        Should -Invoke Deploy-Config -Times 0 -Exactly
    }

    It "'script' invokes the scriptblock with source path and label" {
        $script:seen = $null
        $entry = @{
            Label = 'L'; Path = 'app\f.txt'; Mode = 'script'
            Invoke = { param($s, $l) $script:seen = "$s|$l" }
        }

        Invoke-ConfigManifestEntry -Entry $entry -ConfigRoot $script:cfgRoot

        $script:seen | Should -Be ((Join-Path $script:cfgRoot 'app\f.txt') + '|L')
    }
}

# Runs the real manifest entry for the rtk filters with rtk stubbed, so exit-code handling,
# Push/Pop-Location and the -WhatIf skip are exercised without a real rtk or APPDATA write.
Describe "Setup-Dotfiles.ps1 rtk trust entry" {
    BeforeAll {
        $scriptPath = "$PSScriptRoot/../Scripts/Setup-Dotfiles.ps1"
        . $scriptPath
        # The manifest is built inside Start-Bootstrap; pull the entry's Invoke block out of its AST.
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        $hashes = $ast.FindAll({
                param($n)
                $n -is [System.Management.Automation.Language.HashtableAst] -and
                $n.Extent.Text -match "Path\s*=\s*'rtk\\filters\.toml'"
            }, $true)
        $invokePair = $hashes[-1].KeyValuePairs | Where-Object { $_.Item1.Value -eq 'Invoke' }
        $inner = $invokePair.Item2.Extent.Text.Trim()
        $inner = $inner.Substring(1, $inner.Length - 2)
        # Wrapped as a cmdlet so $PSCmdlet.ShouldProcess works as it does inside Start-Bootstrap.
        $script:rtkInvoke = "function Invoke-RtkEntry { [CmdletBinding(SupportsShouldProcess)]$inner }"
    }

    BeforeEach {
        $script:rtkApp = Join-Path $TestDrive 'appdata'
        $script:savedAppData = $env:APPDATA
        $env:APPDATA = $script:rtkApp
        $null = New-Item -ItemType Directory -Path (Join-Path $script:rtkApp 'rtk') -Force
        $script:rtkCalls = 0
        $script:rtkExit = 0
        function rtk { $script:rtkCalls++; $global:LASTEXITCODE = $script:rtkExit }
        Mock Deploy-Config { }
        Mock Write-Host { }
        Mock Write-Warning { }
        Mock Push-Location { }
        Mock Pop-Location { }
    }

    AfterEach {
        $env:APPDATA = $script:savedAppData
    }

    It "Locates the entry" {
        $script:rtkInvoke | Should -Not -BeNullOrEmpty
    }

    It "Pushes into the rtk dir, runs rtk trust, and pops" {
        . ([scriptblock]::Create($script:rtkInvoke))
        $null = Invoke-RtkEntry 'src' 'rtk global filters'
        $script:rtkCalls | Should -Be 1
        Should -Invoke Push-Location -Times 1
        Should -Invoke Pop-Location -Times 1
    }

    It "Throws on a non-zero rtk exit code but still pops the location" {
        $script:rtkExit = 3
        . ([scriptblock]::Create($script:rtkInvoke))
        { Invoke-RtkEntry 'src' 'rtk global filters' } | Should -Throw '*exited with 3*'
        Should -Invoke Pop-Location -Times 1
    }

    It "Skips trust under -WhatIf" {
        . ([scriptblock]::Create($script:rtkInvoke))
        $null = Invoke-RtkEntry 'src' 'rtk global filters' -WhatIf
        $script:rtkCalls | Should -Be 0
        Should -Invoke Push-Location -Times 0
    }
}
