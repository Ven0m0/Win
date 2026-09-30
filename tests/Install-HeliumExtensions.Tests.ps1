#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    $script:ScriptPath = "$PSScriptRoot/../Scripts/Install-HeliumExtensions.ps1"
    $script:CrxUrl = 'https://clients2.google.com/service/update2/crx'
    $script:IdA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    $script:IdB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'

    # Defined inside the script; stubbed so Pester can mock it (the mock alias wins over
    # the script's own definition).
    function Test-Admin { }
    # CmdletInfo captured before mocking; invoking it directly bypasses the mock alias.
    $script:RealTestPath = Get-Command -Name Test-Path -CommandType Cmdlet
}

Describe 'Install-HeliumExtensions.ps1' {
    BeforeEach {
        $script:OriginalLocalAppData = $env:LOCALAPPDATA
        $env:LOCALAPPDATA = $TestDrive

        # Every registry write/delete and the elevation relaunch are mocked; HKLM is never touched.
        Mock Test-Admin { $true }
        Mock New-Item { }
        Mock New-ItemProperty { }
        Mock Remove-Item { }
        Mock Remove-ItemProperty { }
        Mock Get-Item { [pscustomobject]@{ Property = @() } }
        Mock Start-Process { }
        Mock Set-Content { }
        Mock Write-Host { }
        Mock Write-Warning { }
        # Pester 6 has no implicit fall-through for filtered mocks; pass other paths to the real cmdlet.
        Mock Test-Path { & $RealTestPath @PesterBoundParameters }
        # Ignore the tracked Scripts/helium-extensions.txt so results do not depend on its contents.
        Mock Test-Path { $false } -ParameterFilter { $Path -like '*helium-extensions.txt' }
    }

    AfterEach {
        $env:LOCALAPPDATA = $script:OriginalLocalAppData
    }

    Context 'Elevation' {
        It 'Relaunches elevated with the same method, ids and -Uninstall, and writes nothing' {
            Mock Test-Admin { $false }

            & $ScriptPath -Id $IdA, $IdB -Method Forcelist -Uninstall

            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $a = @($ArgumentList)
                $Verb -eq 'RunAs' -and
                $a[[array]::IndexOf($a, '-Method') + 1] -eq 'Forcelist' -and
                $a -contains $IdA -and $a -contains $IdB -and $a -contains '-Uninstall'
            }
            Should -Invoke New-Item -Times 0 -Exactly
            Should -Invoke Remove-Item -Times 0 -Exactly
        }
    }

    Context 'External method' {
        It 'Creates one Chrome external-extension key with update_url per id' {
            $out = & $ScriptPath -Id $IdA, $IdB

            $out | Should -Be @("queued   $IdA", "queued   $IdB")
            Should -Invoke New-Item -Times 1 -Exactly -ParameterFilter {
                $Path -eq "HKLM:\SOFTWARE\Google\Chrome\Extensions\$IdA"
            }
            Should -Invoke New-ItemProperty -Times 2 -Exactly -ParameterFilter {
                $Name -eq 'update_url' -and $Value -eq $CrxUrl
            }
        }

        It '-Uninstall removes existing keys and reports absent ones' {
            Mock Test-Path { $true } -ParameterFilter { $Path -like "*\$IdA" }

            $out = & $ScriptPath -Id $IdA, $IdB -Uninstall

            $out | Should -Be @("removed  $IdA", "absent   $IdB")
            Should -Invoke Remove-Item -Times 1 -Exactly -ParameterFilter { $Path -like "*\Extensions\$IdA" }
            Should -Invoke New-Item -Times 0 -Exactly
        }
    }

    Context 'Forcelist method' {
        It 'Clears stale policy values, then writes numbered id;update_url entries' {
            Mock Get-Item { [pscustomobject]@{ Property = @('1', '2', '3') } }

            $out = & $ScriptPath -Id $IdA, $IdB -Method Forcelist

            $out | Should -Be @("forced   $IdA", "forced   $IdB")
            Should -Invoke Remove-ItemProperty -Times 3 -Exactly
            Should -Invoke New-ItemProperty -Times 1 -Exactly -ParameterFilter {
                $Path -eq 'HKLM:\SOFTWARE\Policies\Helium\ExtensionInstallForcelist' -and
                $Name -eq '1' -and $Value -eq "$IdA;$CrxUrl"
            }
            Should -Invoke New-ItemProperty -Times 1 -Exactly -ParameterFilter {
                $Name -eq '2' -and $Value -eq "$IdB;$CrxUrl"
            }
        }
    }

    Context 'Id resolution' {
        It 'Falls back to the built-in list of 9 extensions' {
            $out = & $ScriptPath

            @($out).Count | Should -Be 9
            Should -Invoke New-ItemProperty -Times 9 -Exactly
        }

        It 'Reads ids from helium-extensions.txt, stripping comments and dropping invalid lines' {
            Mock Test-Path { $true } -ParameterFilter { $Path -like '*helium-extensions.txt' }
            Mock Get-Content {
                @("# header", "$IdA  # Some Name", 'not-an-id', '', "  $IdB")
            } -ParameterFilter { $Path -like '*helium-extensions.txt' }

            $out = & $ScriptPath

            $out | Should -Be @("queued   $IdA", "queued   $IdB")
        }

        It 'Rejects an unknown -Method' {
            { & $ScriptPath -Method Sideload } | Should -Throw
        }
    }

    Context '-Export' {
        It 'Writes id-plus-name comment lines, resolving __MSG_ names from _locales and skipping non-id folders' {
            $extRoot = Join-Path $TestDrive 'imput\Helium\User Data\Default\Extensions'
            $verA = Join-Path $extRoot "$IdA\1.0_0"
            $verB = Join-Path $extRoot "$IdB\2.0_0"
            # New-Item/Set-Content are mocked in BeforeEach, so build the fake profile via .NET.
            foreach ($dir in $verA, (Join-Path $extRoot 'Temp\1.0'), (Join-Path $verB '_locales\de')) {
                $null = [System.IO.Directory]::CreateDirectory($dir)
            }
            [System.IO.File]::WriteAllText((Join-Path $verA 'manifest.json'), '{"name":"Plain Name"}')
            [System.IO.File]::WriteAllText((Join-Path $verB 'manifest.json'),
                '{"name":"__MSG_appName__","default_locale":"de"}')
            [System.IO.File]::WriteAllText((Join-Path $verB '_locales\de\messages.json'),
                '{"appName":{"message":"Lokaler Name"}}')

            $null = & $ScriptPath -Export

            Should -Invoke Set-Content -Times 1 -Exactly -ParameterFilter {
                $Path -like '*helium-extensions.txt' -and
                $Value -contains "$IdA  # Plain Name" -and
                $Value -contains "$IdB  # Lokaler Name" -and
                @($Value | Where-Object { $_ -like 'Temp  #*' }).Count -eq 0
            }
            Should -Invoke New-ItemProperty -Times 0 -Exactly
        }
    }
}
