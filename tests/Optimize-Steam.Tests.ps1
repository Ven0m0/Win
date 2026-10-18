#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    # Stub Common.ps1 helpers before any dot-source to prevent real downloads/ops
    function Get-FileFromWeb { param([string]$URL, [string]$File) }
    function Wait-ForWinget { }
    function Invoke-CommandChecked { }
}

Describe "Optimize-Steam.ps1" {

    # -------------------------------------------------------------------------
    # Get-SteamPath — HKLM path present
    # -------------------------------------------------------------------------
    Context "Get-SteamPath — HKLM registry" {
        BeforeAll {
            Mock Write-Host { }
            Mock Write-Warning { }
            # Only Steam.exe exists; redist subdirs don't, so Get-ChildItem is never called
            Mock Test-Path { $Path -like '*Steam.exe' }
            Mock Get-ItemProperty {
                [PSCustomObject]@{ InstallPath = 'C:\FakeSteam' }
            } -ParameterFilter { $Path -like '*Wow6432Node*' }
            . "$PSScriptRoot/../Scripts/Optimize-Steam.ps1" -WhatIf
        }

        It "Returns path from HKLM Wow6432Node when available" {
            Get-SteamPath | Should -Be 'C:\FakeSteam'
        }
    }

    # -------------------------------------------------------------------------
    # Get-SteamPath — HKLM absent, HKCU fallback
    # -------------------------------------------------------------------------
    Context "Get-SteamPath — HKCU fallback" {
        BeforeAll {
            Mock Write-Host { }
            Mock Write-Warning { }
            Mock Test-Path { $Path -like '*Steam.exe' }
            Mock Get-ItemProperty { $null } -ParameterFilter { $Path -like '*HKLM*' }
            Mock Get-ItemProperty {
                [PSCustomObject]@{ SteamPath = 'C:\HkcuSteam' }
            } -ParameterFilter { $Path -like '*HKCU*' }
            . "$PSScriptRoot/../Scripts/Optimize-Steam.ps1" -WhatIf
        }

        It "Returns HKCU SteamPath when HKLM is absent" {
            Get-SteamPath | Should -Be 'C:\HkcuSteam'
        }
    }

    # -------------------------------------------------------------------------
    # Get-SteamPath — both registry keys missing, ProgramFiles fallback
    # -------------------------------------------------------------------------
    Context "Get-SteamPath — ProgramFiles fallback" {
        BeforeAll {
            Mock Write-Host { }
            Mock Write-Warning { }
            Mock Test-Path { $Path -like '*Steam.exe' }
            Mock Get-ItemProperty { $null }
            . "$PSScriptRoot/../Scripts/Optimize-Steam.ps1" -WhatIf
        }

        It "Falls back to ProgramFiles Steam when both registry keys are missing" {
            Get-SteamPath | Should -BeLike '*Steam*'
        }
    }

    # -------------------------------------------------------------------------
    # Get-SteamPath — explicit -SteamPath override
    # -------------------------------------------------------------------------
    Context "Get-SteamPath — explicit override" {
        BeforeAll {
            Mock Write-Host { }
            Mock Write-Warning { }
            Mock Test-Path { $Path -like '*Steam.exe' }
            Mock Get-ItemProperty { $null }
            . "$PSScriptRoot/../Scripts/Optimize-Steam.ps1" -SteamPath 'C:\CustomSteam' -WhatIf
        }

        It "Returns the override path directly without registry lookup" {
            Get-SteamPath -Override 'C:\CustomSteam' | Should -Be 'C:\CustomSteam'
        }
    }

    # -------------------------------------------------------------------------
    # Invoke-CleanRedist
    # -------------------------------------------------------------------------
    Context "Invoke-CleanRedist — WhatIf suppresses deletions" {
        BeforeAll {
            Mock Write-Host { }
            Mock Write-Warning { }
            Mock Test-Path { $Path -like '*Steam.exe' }
            Mock Remove-Item { }
            Mock Get-ItemProperty {
                [PSCustomObject]@{ InstallPath = 'C:\FakeSteam' }
            } -ParameterFilter { $Path -like '*Wow6432Node*' }
            . "$PSScriptRoot/../Scripts/Optimize-Steam.ps1" -WhatIf
            # Mock after dot-source: Write-ColorOutput comes from Common.ps1 and
            # must exist to be mockable; Write-Host mocks don't catch it
            Mock Write-ColorOutput { }
        }

        It "Does not call Remove-Item when WhatIfPreference is set" {
            Invoke-CleanRedist -SteamPath 'C:\FakeSteam' -WhatIf
            Should -Not -Invoke Remove-Item
        }

        It "Reports no files to clean when redist dirs are absent" {
            # Test-Path returns false for redist paths (only Steam.exe returns true)
            Invoke-CleanRedist -SteamPath 'C:\FakeSteam' -WhatIf
            Should -Invoke Write-ColorOutput -ParameterFilter { $Object -match 'No installer files' } -Scope It
        }
    }
}

Describe "Optimize-Steam.ps1 - VDF parser" {
    BeforeAll {
        # Main block is gated on InvocationName, so dot-sourcing has no side effects
        . "$PSScriptRoot/../Scripts/Optimize-Steam.ps1"
    }

    Context "parsevdf" {
        It "Parses a minimal valid VDF string" {
            $vdf = '"root"' + "`r`n{`r`n}`r`n"
            $tree = parsevdf $vdf
            $tree.name | Should -Be 'root'
            $tree.node.entries.Count | Should -Be 0
        }

        It "Parses a key-value pair inside the root block" {
            $vdf = '"root"' + "`r`n{`r`n`t`"key`"`t`t`"value`"`r`n}`r`n"
            $tree = parsevdf $vdf
            $tree.node.entries.Count | Should -Be 1
            $tree.node.entries[0].name | Should -Be 'key'
            $tree.node.entries[0].value | Should -Be 'value'
        }

        It "Parses a nested block" {
            $vdf = '"root"' + "`r`n{`r`n`t`"section`"`r`n`t{`r`n`t}`r`n}`r`n"
            $tree = parsevdf $vdf
            $tree.node.entries[0].kind | Should -Be 'block'
            $tree.node.entries[0].name | Should -Be 'section'
        }

        It "Throws on missing root key" {
            { parsevdf '{}' } | Should -Throw
        }

        It "Throws on missing root block" {
            { parsevdf '"root"' } | Should -Throw
        }
    }

    Context "writevdf" {
        It "Produces parseable output from a roundtrip" {
            $vdf = '"root"' + "`r`n{`r`n`t`"key`"`t`t`"value`"`r`n}`r`n"
            $tree = parsevdf $vdf
            $output = writevdf $tree
            $tree2 = parsevdf $output
            $tree2.name | Should -Be 'root'
            $tree2.node.entries[0].value | Should -Be 'value'
        }

        It "Escapes backslashes in written output" {
            $vdf = '"root"' + "`r`n{`r`n`t`"path`"`t`t`"C:\\Steam`"`r`n}`r`n"
            $tree = parsevdf $vdf
            $output = writevdf $tree
            $output | Should -Match '\\\\'
        }
    }

    Context "findentry" {
        It "Returns the index of an existing entry" {
            $vdf = '"root"' + "`r`n{`r`n`t`"alpha`"`t`t`"1`"`r`n`t`"beta`"`t`t`"2`"`r`n}`r`n"
            $tree = parsevdf $vdf
            findentry $tree.node 'beta' | Should -Be 1
        }

        It "Returns -1 when the entry does not exist" {
            $vdf = '"root"' + "`r`n{`r`n`t`"alpha`"`t`t`"1`"`r`n}`r`n"
            $tree = parsevdf $vdf
            findentry $tree.node 'missing' | Should -Be -1
        }

        It "Performs case-sensitive lookup" {
            $vdf = '"root"' + "`r`n{`r`n`t`"Key`"`t`t`"1`"`r`n}`r`n"
            $tree = parsevdf $vdf
            findentry $tree.node 'key' | Should -Be -1
            findentry $tree.node 'Key' | Should -Be 0
        }
    }

    Context "setvalue" {
        It "Adds a new key-value entry when key does not exist" {
            $vdf = '"root"' + "`r`n{`r`n}`r`n"
            $tree = parsevdf $vdf
            setvalue $tree.node 'newkey' 'newval'
            $tree.node.entries.Count | Should -Be 1
            $tree.node.entries[0].value | Should -Be 'newval'
        }

        It "Updates an existing value in place" {
            $vdf = '"root"' + "`r`n{`r`n`t`"key`"`t`t`"old`"`r`n}`r`n"
            $tree = parsevdf $vdf
            setvalue $tree.node 'key' 'new'
            $tree.node.entries.Count | Should -Be 1
            $tree.node.entries[0].value | Should -Be 'new'
        }

        It "Throws when trying to set a value on a block entry" {
            $vdf = '"root"' + "`r`n{`r`n`t`"section`"`r`n`t{`r`n`t}`r`n}`r`n"
            $tree = parsevdf $vdf
            { setvalue $tree.node 'section' 'val' } | Should -Throw
        }
    }

    Context "ensureblock" {
        It "Creates a new child block when it does not exist" {
            $vdf = '"root"' + "`r`n{`r`n}`r`n"
            $tree = parsevdf $vdf
            $child = ensureblock $tree.node 'section'
            $child | Should -Not -BeNullOrEmpty
            $tree.node.entries.Count | Should -Be 1
            $tree.node.entries[0].kind | Should -Be 'block'
        }

        It "Returns the existing block node when it already exists" {
            $vdf = '"root"' + "`r`n{`r`n`t`"section`"`r`n`t{`r`n`t`"k`"`t`t`"v`"`r`n`t}`r`n}`r`n"
            $tree = parsevdf $vdf
            $child = ensureblock $tree.node 'section'
            $child.entries.Count | Should -Be 1
        }

        It "Throws when the named entry is a value, not a block" {
            $vdf = '"root"' + "`r`n{`r`n`t`"flat`"`t`t`"val`"`r`n}`r`n"
            $tree = parsevdf $vdf
            { ensureblock $tree.node 'flat' } | Should -Throw
        }
    }

    Context "settings application roundtrip" {
        It "Applies all settings keys to an empty VDF tree without error" {
            $vdf = '"UserLocalConfigStore"' + "`r`n{`r`n}`r`n"
            $tree = parsevdf $vdf

            $root = $tree.node
            foreach ($scope in $settings.Keys) {
                $node = if ($scope -eq 'root') { $root } else { ensureblock $root $scope }
                foreach ($name in $settings[$scope].Keys) {
                    { setvalue $node $name $settings[$scope][$name] } | Should -Not -Throw
                }
            }
        }

        It "Roundtrips the modified tree without data loss" {
            $vdf = '"UserLocalConfigStore"' + "`r`n{`r`n}`r`n"
            $tree = parsevdf $vdf
            $root = $tree.node
            setvalue $root 'LibraryLowBandwidthMode' '1'

            $out = writevdf $tree
            $tree2 = parsevdf $out
            $i = findentry $tree2.node 'LibraryLowBandwidthMode'
            $tree2.node.entries[$i].value | Should -Be '1'
        }
    }
}

Describe "Optimize-Steam.ps1 - Get-SteamPath (registry error)" {
    BeforeAll {
        Mock Write-Host { }
        Mock Write-Warning { }
        Mock Test-Path { $Path -like '*Steam.exe' }
        Mock Get-ItemProperty { throw 'no registry entry' }
        . "$PSScriptRoot/../Scripts/Optimize-Steam.ps1" -WhatIf
    }

    It "Falls back to ProgramFiles Steam when registry lookups throw" {
        Get-SteamPath | Should -BeLike '*Steam*'
    }
}

Describe "Optimize-Steam.ps1 - Invoke-CreateShortcut" {
    BeforeAll {
        Mock Write-Host { }
        Mock Write-Warning { }
        Mock Test-Path { $true }
        . "$PSScriptRoot/../Scripts/Optimize-Steam.ps1" -WhatIf
        Mock Write-ColorOutput { }
        Mock New-Shortcut { }
    }

    Context "DryRun suppresses COM shortcut creation" {
        It "Does not instantiate WScript.Shell when -DryRun is set" {
            Mock New-Object { } -ParameterFilter { $ComObject -eq 'WScript.Shell' }
            Invoke-CreateShortcut -SteamPath 'C:\FakeSteam' -DryRun
            Should -Not -Invoke New-Object -ParameterFilter { $ComObject -eq 'WScript.Shell' }
        }

        It "Writes at least one status message in DryRun mode" {
            Invoke-CreateShortcut -SteamPath 'C:\FakeSteam' -DryRun
            Should -Invoke Write-ColorOutput -Times 1 -Exactly:$false
        }

        It "Does not call New-Shortcut in DryRun mode" {
            Invoke-CreateShortcut -SteamPath 'C:\FakeSteam' -DryRun
            Should -Invoke New-Shortcut -Times 0 -Exactly
        }
    }

    Context "Real run" {
        It "Creates the shortcut targeting Steam.exe with the optimized launch arguments" {
            Invoke-CreateShortcut -SteamPath 'C:\FakeSteam' -Name 'Test Steam'
            Should -Invoke New-Shortcut -Times 1 -Exactly -ParameterFilter {
                $ShortcutPath -like '*Test Steam.lnk' -and $TargetPath -eq 'C:\FakeSteam\Steam.exe' -and
                $Arguments -like '*-nofriendsui*'
            }
        }

        It "Does not create the shortcut under -WhatIf" {
            Invoke-CreateShortcut -SteamPath 'C:\FakeSteam' -WhatIf
            Should -Invoke New-Shortcut -Times 0 -Exactly
        }

        It "Warns and creates nothing when Steam.exe is missing" {
            Mock Test-Path { $false }
            Invoke-CreateShortcut -SteamPath 'C:\FakeSteam'
            Should -Invoke Write-Warning -Times 1 -Exactly
            Should -Invoke New-Shortcut -Times 0 -Exactly
        }
    }
}

Describe "Optimize-Steam.ps1 - Invoke-Configure" {
    BeforeAll {
        Mock Write-Host { }
        Mock Write-Warning { }
        . "$PSScriptRoot/../Scripts/Optimize-Steam.ps1" -WhatIf
        Mock Write-ColorOutput { }
    }

    It "Warns and returns when no localconfig.vdf is found" {
        Invoke-Configure -SteamPath (Join-Path $TestDrive 'NoSteam')
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like 'No localconfig.vdf*' }
    }

    It "Applies settings, writes a .bak and leaves a valid VDF" {
        $cfg = Join-Path $TestDrive 'localconfig.vdf'
        $original = '"UserLocalConfigStore"' + "`r`n{`r`n`t`"keep`"`t`t`"me`"`r`n}`r`n"
        [System.IO.File]::WriteAllText($cfg, $original)

        Invoke-Configure -SteamPath $TestDrive -Paths $cfg

        Test-Path "$cfg.bak" | Should -BeTrue
        [System.IO.File]::ReadAllText("$cfg.bak") | Should -Be $original
        $tree = parsevdf ([System.IO.File]::ReadAllText($cfg))
        $tree.name | Should -Be 'UserLocalConfigStore'
        $tree.node.entries[(findentry $tree.node 'keep')].value | Should -Be 'me'
        (findentry $tree.node 'LibraryLowBandwidthMode') | Should -BeGreaterOrEqual 0
    }

    It "Leaves the file untouched under -WhatIf" {
        $cfg = Join-Path $TestDrive 'whatif.vdf'
        $original = '"UserLocalConfigStore"' + "`r`n{`r`n}`r`n"
        [System.IO.File]::WriteAllText($cfg, $original)

        Invoke-Configure -SteamPath $TestDrive -Paths $cfg -WhatIf

        [System.IO.File]::ReadAllText($cfg) | Should -Be $original
        Test-Path "$cfg.bak" | Should -BeFalse
    }

    It "Skips files with an unexpected root key" {
        $cfg = Join-Path $TestDrive 'wrongroot.vdf'
        $original = '"SomethingElse"' + "`r`n{`r`n}`r`n"
        [System.IO.File]::WriteAllText($cfg, $original)

        Invoke-Configure -SteamPath $TestDrive -Paths $cfg

        [System.IO.File]::ReadAllText($cfg) | Should -Be $original
        Should -Invoke Write-Warning -ParameterFilter { $Message -like "*Unexpected root key*" }
    }
}

Describe "Optimize-Steam.ps1 - Invoke-Launch" {
    BeforeAll {
        Mock Write-Host { }
        Mock Write-Warning { }
        Mock Test-Path { $true }
        . "$PSScriptRoot/../Scripts/Optimize-Steam.ps1" -WhatIf
        Mock Write-ColorOutput { }
        Mock Start-Process { }
        Mock Stop-SteamGracefully { }
        Mock Remove-Item { }
        Mock Get-Process { $null }
    }

    It "Warns and starts nothing when Steam.exe is missing" {
        Mock Test-Path { $false }
        Invoke-Launch -SteamPath 'C:\FakeSteam'
        Should -Invoke Start-Process -Times 0 -Exactly
        Should -Invoke Write-Warning -Times 1 -Exactly
    }

    It "Starts Steam with the optimized arguments and does not stop it when not running" {
        Invoke-Launch -SteamPath 'C:\FakeSteam'
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq 'C:\FakeSteam\Steam.exe' -and $ArgumentList -like '*-nofriendsui*' -and
            $ArgumentList -notlike '*-foreground*'
        }
        Should -Invoke Stop-SteamGracefully -Times 0 -Exactly
    }

    It "Stops a running Steam first and adds -foreground" {
        Mock Get-Process { [pscustomobject]@{ Name = 'steam' } }
        Invoke-Launch -SteamPath 'C:\FakeSteam'
        Should -Invoke Stop-SteamGracefully -Times 1 -Exactly
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $ArgumentList -like '*-foreground' }
    }

    It "Starts nothing under -WhatIf" {
        Invoke-Launch -SteamPath 'C:\FakeSteam' -WhatIf
        Should -Invoke Start-Process -Times 0 -Exactly
    }
}
