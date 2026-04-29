#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
}

Describe "fix-system.ps1" {
    Context "Syntax and Basic Execution" {
        It "Can be parsed and executed safely in DryRun mode" {
            $content = Get-Content "$PSScriptRoot/fix-system.ps1" -Raw

            $content = $content.Replace('. "$PSScriptRoot\Common.ps1"', '# . "$PSScriptRoot\Common.ps1"')

            $baseTemp = [System.IO.Path]::GetTempFileName()
            Remove-Item $baseTemp -Force
            $tempScript = $baseTemp + ".ps1"
            Set-Content -Path $tempScript -Value $content

            $runBlock = {
                # Setup mock functions that would normally be in Common.ps1
                function Write-Header {}
                function Write-Info {}
                function Write-Warn {}
                function Write-Success {}
                function Add-Log {}
                function Clear-Log {}
                function Show-Summary {}

                . $tempScript
                Start-SystemFix -DryRun -NoReport -QuickScan
            }

            $runBlock | Should -Not -Throw

            if (Test-Path $tempScript) {
                Remove-Item $tempScript -Force
            }
        }

        It "Can be parsed and executed in DryRun mode with SkipDiskCheck" {
            $content = Get-Content "$PSScriptRoot/fix-system.ps1" -Raw
            $content = $content.Replace('. "$PSScriptRoot\Common.ps1"', '# . "$PSScriptRoot\Common.ps1"')

            $baseTemp = [System.IO.Path]::GetTempFileName()
            Remove-Item $baseTemp -Force
            $tempScript = $baseTemp + ".ps1"
            Set-Content -Path $tempScript -Value $content

            $runBlock = {
                function Write-Header {}
                function Write-Info {}
                function Write-Warn {}
                function Write-Success {}
                function Add-Log {}
                function Clear-Log {}
                function Show-Summary {}

                . $tempScript
                Start-SystemFix -DryRun -NoReport -SkipDiskCheck
            }

            $runBlock | Should -Not -Throw

            if (Test-Path $tempScript) { Remove-Item $tempScript -Force }
        }

        It "Can be parsed and executed in DryRun mode with SkipNetworkFix and SkipWUReset" {
            $content = Get-Content "$PSScriptRoot/fix-system.ps1" -Raw
            $content = $content.Replace('. "$PSScriptRoot\Common.ps1"', '# . "$PSScriptRoot\Common.ps1"')

            $baseTemp = [System.IO.Path]::GetTempFileName()
            Remove-Item $baseTemp -Force
            $tempScript = $baseTemp + ".ps1"
            Set-Content -Path $tempScript -Value $content

            $runBlock = {
                function Write-Header {}
                function Write-Info {}
                function Write-Warn {}
                function Write-Success {}
                function Add-Log {}
                function Clear-Log {}
                function Show-Summary {}

                . $tempScript
                Start-SystemFix -DryRun -NoReport -SkipNetworkFix -SkipWUReset
            }

            $runBlock | Should -Not -Throw

            if (Test-Path $tempScript) { Remove-Item $tempScript -Force }
        }
    }
}

