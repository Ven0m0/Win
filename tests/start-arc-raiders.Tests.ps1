#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0

    # Remove-Glob lives in Common.ps1 (shared helper library);
    # start-arc-raiders.ps1 consumes it via its Invoke-GlobClean wrapper.
    $scriptPath = Join-Path $PSScriptRoot "../Scripts/Common.ps1"
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)

    if ($parseErrors) {
        throw "Failed to parse Common.ps1: $($parseErrors[0].Message)"
    }

    $removeGlobDefinition = $ast.Find(
        {
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Remove-Glob'
        },
        $true
    )

    if (-not $removeGlobDefinition) {
        throw "Remove-Glob function was not found in Common.ps1."
    }

    . ([ScriptBlock]::Create($removeGlobDefinition.Extent.Text))
}

Describe "Start-ArcRaiders Script Initialization" {
    It "Should safely load the Remove-Glob function definition" {
        $true | Should -Be $true
    }

    It "Should export the Remove-Glob function" {
        $func = Get-Command -Name "Remove-Glob" -ErrorAction SilentlyContinue
        $func | Should -Not -BeNullOrEmpty
        $func.CommandType | Should -Be "Function"
    }

    It "Should delegate to start-optimized-game.ps1 with the Arc Raiders manifest" {
        $content = Get-Content -Raw "$PSScriptRoot/../Scripts/arc-raiders/start-arc-raiders.ps1"
        $content | Should -Match 'start-optimized-game\.ps1'
        $content | Should -Match 'arc-raiders\.psd1'
    }
}

Describe "Start-ArcRaiders Functions" {
    BeforeAll {
        function Write-Host {}
        # Storage-module CDXML cmdlets cannot be Pester-mocked: their generated
        # proxies reference dynamic types (e.g. Get-PhysicalDisk.PhysicalDiskUsage)
        # that fail to parse. Plain stub functions shadow them instead.
        function Get-Volume { return @() }
        function Get-PhysicalDisk {}
        function Optimize-Volume {}
        Mock Write-Host {}
        Mock Get-Item { return @() }
        Mock Get-ChildItem {}
        Mock Start-Process {}
    }

    It "Should run Remove-Glob without errors when no items match" {
        Mock Get-Item { return @() }
        { Remove-Glob -Pattern "$env:TEMP\nonexistent\*" } | Should -Not -Throw
    }
}
