BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
}

Describe "Install-Packages" {
    BeforeAll {
        function winget {}
        function scoop {}
        function choco {}
        function DISM {}
        function fsutil.exe {}
        function tzutil.exe {}
        function Set-TimeZone {}
        function Set-Culture {}
        . "$PSScriptRoot/../Scripts/Install-Packages.ps1"
    }

    Context "Initialization" {
        It "Should load the module and functions without execution" {
            Get-Command Start-InstallPackage -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    Context "Parameters functionality" {
        BeforeEach {
            $script:isAdminOverride = $true
            Mock Write-Host {}
            Mock Write-Warning {}
            Mock Invoke-RestMethod {}
            Mock Remove-Item {}
            Mock Set-ExecutionPolicy {}
            Mock Set-ItemProperty {}
            Mock New-Item {}
            Mock Test-Path { return $true }

            Mock winget {}
            # Wait-ForWinget returns the real exe path; '& $winget' would bypass the
            # winget mock entirely and run real installs. Return the bare name so
            # invocation resolves to the mocked function instead.
            Mock Wait-ForWinget { 'winget' }
            Mock scoop {}
            Mock choco {}
            Mock DISM {}
            Mock fsutil.exe {}
            Mock tzutil.exe {}
            Mock Set-TimeZone {}
            Mock Set-Culture {}
            # Post-install writes HKLM (LabConfig, WPBT, DeviceRegion) through this helper.
            Mock Set-RegistryValue {}
            Mock Install-Module {}
            Mock Start-Process {}
            Mock Get-FileFromWeb {}
            # Second guard: report child installer scripts as missing even if a skip switch is dropped.
            Mock Test-Path { $false } -ParameterFilter { "$LiteralPath" -like '*third-party*' }

            # Peripheral/manual-install phases invoke child scripts that re-dot-source Common.ps1,
            # shadowing these mocks and running real winget/7z; language packages call real
            # bun/npm/cargo. Always skip them.
            $safeSkips = @{
                SkipPowerShellModules = $true
                SkipNotepadReplacer   = $true
                SkipPeripherals       = $true
                SkipManualInstalls    = $true
                SkipLanguagePackages  = $true
            }

            # The script uses $env:SystemDrive. On Linux, this is null.
            # So $env:SystemDrive.TrimEnd('\') fails with "You cannot call a method on a null-valued expression."
            $env:SystemDrive = "C:\"
        }

        AfterEach {
            $script:isAdminOverride = $null
            $env:SystemDrive = $null
        }

        It "Should bypass winget when SkipWinget is provided" {
            Start-InstallPackage -SkipWinget -SkipScoop -SkipChoco -SkipSystemFeatures -ApplyPostInstall:$false @safeSkips
            Should -Invoke winget -Times 0
        }

        It "Should bypass scoop when SkipScoop is provided" {
            Start-InstallPackage -SkipScoop -ApplyPostInstall:$false @safeSkips
            Should -Invoke scoop -Times 0
            Should -Invoke Invoke-RestMethod -Times 0 -ParameterFilter { $Uri -match 'scoop' }
        }

        It "Should bypass choco when SkipChoco is provided" {
            Start-InstallPackage -SkipChoco -ApplyPostInstall:$false @safeSkips
            Should -Invoke choco -Times 0
            Should -Invoke Invoke-RestMethod -Times 0 -ParameterFilter { $Uri -match 'chocolatey' }
        }

        It "Should bypass system features when SkipSystemFeatures is provided" {
            Start-InstallPackage -SkipSystemFeatures -ApplyPostInstall:$false @safeSkips
            Should -Invoke DISM -Times 0
        }

        It "Should not apply post-install when ApplyPostInstall is missing" {
            Start-InstallPackage -SkipWinget -SkipScoop -SkipChoco -SkipSystemFeatures @safeSkips
            Should -Invoke Set-TimeZone -Times 0
            Should -Invoke Set-Culture -Times 0
            Should -Invoke fsutil.exe -Times 0
        }

        It "Should not throw when packages.psd1 has no ManualInstalls key" {
            # Manual installs enabled on purpose; every child script path reads as missing
            # (Test-Path mock above), so nothing real can run even if the key is added later.
            $manualSkips = $safeSkips.Clone()
            $manualSkips.Remove('SkipManualInstalls')
            {
                Start-InstallPackage -SkipWinget -SkipScoop -SkipChoco -SkipSystemFeatures `
                    -ApplyPostInstall:$false @manualSkips
            } | Should -Not -Throw
        }

        It "Should apply post-install when ApplyPostInstall is provided" {
            Start-InstallPackage -SkipWinget -SkipScoop -SkipChoco -SkipSystemFeatures -ApplyPostInstall @safeSkips
            Should -Invoke Set-TimeZone -Times 1
            Should -Invoke Set-Culture -Times 1
            Should -Invoke fsutil.exe -Times 2
        }
    }
}
