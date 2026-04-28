BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    . "$PSScriptRoot/Common.ps1"
    . "$PSScriptRoot/additional-maintenance.ps1"
}

Describe "additional-maintenance.ps1" {
    Context "DryRun Mode" {
        It "Should execute operations with DryRun" {
            # Mock Common functions instead of depending on Common.ps1 side-effects
            Mock Get-Date { return [datetime]"2023-01-01T12:00:00" }
            Mock Write-Header {}
            Mock Write-Info {}
            Mock Write-Success {}
            Mock Write-Warn {}
            Mock Clear-Log {}
            Mock Get-Log { return "log" }
            Mock Show-Summary {}

            # Since Invoke-Operation has mandatory Action parameter, Pester mock sometimes tries to validate it.
            # We can override the param block by not using -CommandName, or just let Pester mock it with the same signature.
            # Actually, `Mock Invoke-Operation { }` uses an empty script block, which expects no parameters if parameter binding occurs.
            # Let's specify the param block in the Mock!
            Mock Invoke-Operation {
                param(
                    $Name,
                    $Action,
                    $Result,
                    $Results,
                    $DryRun,
                    $CaptureOutput,
                    $Command,
                    $ArgumentList
                )
            }
            Mock Invoke-ServiceOperation {
                param($Name, $Action, $Restart, $Force)
            }
            Mock Clear-PathSafe {}
            Mock Out-File {}
            Mock Join-Path { return "dummy_path" }

            Start-AdditionalMaintenance -DryRun

            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'SystemRestorePoint' -and $DryRun -eq $true } -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'DISM_ComponentAnalysis' -and $DryRun -eq $true } -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'DISM_ComponentCleanup' -and $DryRun -eq $true } -Times 1
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'StoreCacheClear' -and $DryRun -eq $true } -Times 1
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
            Mock Get-Date { return [datetime]"2023-01-01T12:00:00" }
            Mock Write-Header {}
            Mock Write-Info {}
            Mock Write-Success {}
            Mock Write-Warn {}
            Mock Clear-Log {}
            Mock Get-Log { return "log" }
            Mock Show-Summary {}
            Mock Invoke-Operation {
                param(
                    $Name,
                    $Action,
                    $Result,
                    $Results,
                    $DryRun,
                    $CaptureOutput,
                    $Command,
                    $ArgumentList
                )
            }
            Mock Invoke-ServiceOperation {
                param($Name, $Action, $Restart, $Force)
            }
            Mock Clear-PathSafe {}
            Mock Out-File {}
            Mock Join-Path { return "dummy_path" }

            Start-AdditionalMaintenance -NoRestorePoint

            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'SystemRestorePoint' } -Times 0
            Should -Invoke Invoke-Operation -ParameterFilter { $Name -eq 'DISM_ComponentAnalysis' } -Times 1
        }
    }
}
