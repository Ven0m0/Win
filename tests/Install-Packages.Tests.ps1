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
            Get-Command Start-InstallPackages -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
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
            Mock scoop {}
            Mock choco {}
            Mock DISM {}
            Mock fsutil.exe {}
            Mock tzutil.exe {}
            Mock Set-TimeZone {}
            Mock Set-Culture {}

            # The script uses $env:SystemDrive. On Linux, this is null.
            # So $env:SystemDrive.TrimEnd('\') fails with "You cannot call a method on a null-valued expression."
            $env:SystemDrive = "C:\"
        }

        AfterEach {
            $script:isAdminOverride = $null
            $env:SystemDrive = $null
        }

        It "Should bypass winget when SkipWinget is provided" {
            Start-InstallPackages -SkipWinget -SkipScoop -SkipChoco -SkipSystemFeatures -ApplyPostInstall:$false
            Assert-MockCalled winget -Times 0
        }

        It "Should bypass scoop when SkipScoop is provided" {
            Start-InstallPackages -SkipScoop -ApplyPostInstall:$false
            Assert-MockCalled scoop -Times 0
            Assert-MockCalled Invoke-RestMethod -Times 0 -ParameterFilter { $Uri -match 'scoop' }
        }

        It "Should bypass choco when SkipChoco is provided" {
            Start-InstallPackages -SkipChoco -ApplyPostInstall:$false
            Assert-MockCalled choco -Times 0
            Assert-MockCalled Invoke-RestMethod -Times 0 -ParameterFilter { $Uri -match 'chocolatey' }
        }

        It "Should bypass system features when SkipSystemFeatures is provided" {
            Start-InstallPackages -SkipSystemFeatures -ApplyPostInstall:$false
            Assert-MockCalled DISM -Times 0
        }

        It "Should not apply post-install when ApplyPostInstall is missing" {
            Start-InstallPackages -SkipWinget -SkipScoop -SkipChoco -SkipSystemFeatures
            Assert-MockCalled Set-TimeZone -Times 0
            Assert-MockCalled Set-Culture -Times 0
            Assert-MockCalled fsutil.exe -Times 0
        }

        It "Should apply post-install when ApplyPostInstall is provided" {
            Start-InstallPackages -SkipWinget -SkipScoop -SkipChoco -SkipSystemFeatures -ApplyPostInstall
            Assert-MockCalled Set-TimeZone -Times 1
            Assert-MockCalled Set-Culture -Times 1
            Assert-MockCalled fsutil.exe -Times 2
        }
    }
}
