BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
}

Describe "fix-system.ps1" {
    Context "Syntax and Basic Execution" {
        It "Can be parsed and executed in DryRun mode without throwing" {
            $content = Get-Content "$PSScriptRoot/fix-system.ps1" -Raw
            $content = $content.Replace('"$PSScriptRoot\Common.ps1"', "`"$PSScriptRoot/Common.ps1`"")
            $content = $content.Replace('$PSScriptRoot', "'$PSScriptRoot'")

            $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
            Set-Content -Path $tempScript -Value $content

            $runBlock = {
                . $tempScript -DryRun -NoReport
            }

            $runBlock | Should -Not -Throw

            Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
        }

        It "Can run with QuickScan parameter without throwing" {
            $content = Get-Content "$PSScriptRoot/fix-system.ps1" -Raw
            $content = $content.Replace('"$PSScriptRoot\Common.ps1"', "`"$PSScriptRoot/Common.ps1`"")
            $content = $content.Replace('$PSScriptRoot', "'$PSScriptRoot'")

            $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
            Set-Content -Path $tempScript -Value $content

            $runBlock = {
                . $tempScript -DryRun -NoReport -QuickScan
            }

            $runBlock | Should -Not -Throw

            Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
        }

        It "Can run with Skip flags without throwing" {
            $content = Get-Content "$PSScriptRoot/fix-system.ps1" -Raw
            $content = $content.Replace('"$PSScriptRoot\Common.ps1"', "`"$PSScriptRoot/Common.ps1`"")
            $content = $content.Replace('$PSScriptRoot', "'$PSScriptRoot'")

            $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
            Set-Content -Path $tempScript -Value $content

            $runBlock = {
                . $tempScript -DryRun -NoReport -SkipDiskCheck -SkipNetworkFix -SkipWUReset
            }

            $runBlock | Should -Not -Throw

            Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
        }
    }
}
