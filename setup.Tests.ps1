BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    . "$PSScriptRoot/setup.ps1"
}

Describe "Set-SetupStep" {
    It "Updates the global step variable" {
        Set-SetupStep -Name "TestStep"
        $script:CurrentSetupStep | Should -Be "TestStep"
    }
}

Describe "Invoke-NativeCommand" {
    It "Executes a command and returns successfully if exit code is allowed" {
        $act = { Invoke-NativeCommand -FilePath 'pwsh' -ArgumentList @('-c', 'exit 0') -Action 'TestSuccess' }
        $act | Should -Not -Throw
    }

    It "Throws an error if the exit code is not allowed" {
        $act = { Invoke-NativeCommand -FilePath 'pwsh' -ArgumentList @('-c', 'exit 1') -Action 'TestFailure' }
        $act | Should -Throw "TestFailure failed with exit code 1."
    }
}

Describe "Get-ActivePhysicalAdapterAlias" {
    It "Returns empty array when Get-NetAdapter fails or is not available" {
        # Get-NetAdapter is a Windows-specific command, we need to mock it gracefully
        # By defining a fake Get-NetAdapter function first, Pester can mock it
        function Get-NetAdapter {}
        Mock Get-NetAdapter { throw "Simulated failure" }
        $result = Get-ActivePhysicalAdapterAlias
        $result.Count | Should -Be 0
    }

    It "Returns adapter names when Get-NetAdapter succeeds" {
        function Get-NetAdapter {}
        Mock Get-NetAdapter {
            [PSCustomObject]@{ Name = 'Ethernet'; Status = 'Up' }
            [PSCustomObject]@{ Name = 'Wi-Fi'; Status = 'Up' }
            [PSCustomObject]@{ Name = 'Bluetooth'; Status = 'Down' }
        }
        $result = Get-ActivePhysicalAdapterAlias
        $result.Count | Should -Be 2
        $result[0] | Should -Be 'Ethernet'
        $result[1] | Should -Be 'Wi-Fi'
    }
}

Describe "Remove-ItemBestEffort" {
    It "Removes an item without throwing if it doesn't exist" {
        $path = "$env:TEMP/non-existent-test-file-123.tmp"
        $act = { Remove-ItemBestEffort -Path $path }
        $act | Should -Not -Throw
    }
}
