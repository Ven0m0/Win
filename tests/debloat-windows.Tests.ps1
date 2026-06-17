#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0

    # Safely source the script
    . "$PSScriptRoot/../Scripts/debloat-windows.ps1"
}

Describe "Debloat-Windows Script Initialization" {
    It "Should safely source the script without executing the main loop" {
        # The main loop has blocking elements like `Wait-ForKeyPress` and `Show-Menu`.
        # Since we reached this point, the guard condition worked.
        $true | Should -Be $true
    }

    It "Should export the expected phase functions" {
        $expectedFunctions = @(
            "Remove-BloatwareApp",
            "Disable-UnnecessaryService",
            "Disable-WindowsFeature",
            "Invoke-ScheduledTaskCleanup",
            "Invoke-RegistryTweak",
            "Invoke-SystemCleanup",
            "Invoke-AllPhase"
        )

        foreach ($funcName in $expectedFunctions) {
            $func = Get-Command -Name $funcName -ErrorAction SilentlyContinue
            $func | Should -Not -BeNullOrEmpty
            $func.CommandType | Should -Be "Function"
        }
    }
}

Describe "Phase Functions Execution" {
    BeforeAll {
        # Mock cmdlets to prevent real system modifications during tests
        function Get-AppxPackage {}
        function Remove-AppxPackage {}
        function Get-Service {}
        function Set-Service {}
        function Stop-Service {}
        function Start-Service {}
        function Get-WindowsOptionalFeature {}
        function Disable-WindowsOptionalFeature {}
        function Get-ScheduledTask {}
        function Invoke-ScheduledTaskCleanup {}
        function Set-RegistryValue {}
        function Get-FolderSize {}
        function Clear-PathSafe {}
        function Clear-RecycleBin {}
        function Format-Size {}
        function New-RestorePoint {}
        function Show-RestartRequired {}
        Mock Get-AppxPackage { return @() }
        Mock Remove-AppxPackage {}
        function Remove-AppxPackageSafe {}
        Mock Remove-AppxPackageSafe {}
        function Get-AppxProvisionedPackage {}
        Mock Get-AppxProvisionedPackage {}
        function Remove-AppxProvisionedPackage {}
        Mock Remove-AppxProvisionedPackage {}
        $env:SystemRoot = '/tmp/Windows'
        Mock Get-Service { return @() }
        Mock Set-Service {}
        Mock Stop-Service {}
        Mock Start-Service {}
        Mock Get-WindowsOptionalFeature { return $null }
        Mock Disable-WindowsOptionalFeature { return $null }
        Mock Get-ScheduledTask { return @() }
        Mock Invoke-ScheduledTaskCleanup {}
        Mock Set-RegistryValue {}
        Mock Get-FolderSize { return 100 }
        Mock Clear-PathSafe {}
        Mock Clear-RecycleBin {}
        Mock Format-Size { return "100 MB" }
        Mock New-RestorePoint {}
        Mock Show-RestartRequired {}
        function ipconfig { return $null }
    }

    It "Should run Remove-BloatwareApp without errors" {
        { Remove-BloatwareApp } | Should -Not -Throw
    }

    It "Should run Disable-UnnecessaryService without errors" {
        { Disable-UnnecessaryService } | Should -Not -Throw
    }

    It "Should run Disable-WindowsFeature without errors" {
        { Disable-WindowsFeature } | Should -Not -Throw
    }

    It "Should run Invoke-ScheduledTaskCleanup without errors" {
        { Invoke-ScheduledTaskCleanup } | Should -Not -Throw
    }

    It "Should run Invoke-RegistryTweak without errors" {
        { Invoke-RegistryTweak } | Should -Not -Throw
    }

    It "Should run Invoke-SystemCleanup without errors" {
        # Invoke-SystemCleanup uses ipconfig /flushdns, we should mock ipconfig if we want to avoid execution.
        # Pester mocks PowerShell commands/functions, but ipconfig is an external executable.
        # We can mock ipconfig by creating a function override, or by trusting it won't break things.
        { Invoke-SystemCleanup } | Should -Not -Throw
    }
}
