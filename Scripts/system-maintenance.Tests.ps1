# Test suite for system-maintenance.ps1 functions using Pester

Describe "Invoke-MsiCleanup" {
    BeforeAll {
        . "$PSScriptRoot\system-maintenance.ps1"
    }

    It "throws an exception when the root path does not exist" {
        $invalidPath = "C:\Invalid\NonExistent\Path\For\Msi"
        { Invoke-MsiCleanup -Root $invalidPath } | Should -Throw "MSI Afterburner not found at: $invalidPath"
    }
}
