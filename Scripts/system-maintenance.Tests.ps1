# Test suite for system-maintenance.ps1 functions using Pester
# 
# Run locally from the repo root:
#   Invoke-Pester -Path ".\Scripts\system-maintenance.Tests.ps1"
#
# Or from within the Scripts directory:
#   Invoke-Pester -Path ".\system-maintenance.Tests.ps1"

Describe "Invoke-MsiCleanup" {
    BeforeAll {
        . "$PSScriptRoot\system-maintenance.ps1"
    }

    It "throws an exception when the root path does not exist" {
        $invalidPath = Join-Path -Path $TestDrive -ChildPath 'Invalid\NonExistent\Path\For\Msi'
        { Invoke-MsiCleanup -Root $invalidPath } | Should -Throw "MSI Afterburner not found at: $invalidPath"
    }
}
