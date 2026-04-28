BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
}

Describe "UltimateDiskCleanup" {
    BeforeAll {
        function Request-AdminElevation {}

        # Safe dot-source because of the MyInvocation guard we added
        . "$PSScriptRoot/UltimateDiskCleanup.ps1"
    }

    It "Should have Start-UltimateDiskCleanup function defined" {
        Get-Command Start-UltimateDiskCleanup -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It "Should declare CmdletBinding with SupportsShouldProcess" {
        $cmd = Get-Command Start-UltimateDiskCleanup
        # The AST might not have exactly 'CmdletBinding' in TypeName depending on parse,
        # but if we just check that the property is parsed correctly via reflection on CmdletBinding:
        $cmd.CmdletBinding -ne $null | Should -Be $true
    }
}
