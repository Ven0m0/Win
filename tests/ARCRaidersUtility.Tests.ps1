#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0

    $scriptPath = Join-Path $PSScriptRoot '../Scripts/arc-raiders/ARCRaidersUtility.ps1'
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)

    $parseErrors | Should -BeNullOrEmpty

    $definitions = New-Object System.Collections.Generic.List[string]

    foreach ($functionAst in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
        $definitions.Add($functionAst.Extent.Text)
    }

    foreach ($assignmentAst in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)) {
        if ($assignmentAst.Left -is [System.Management.Automation.Language.VariableExpressionAst]) {
            $variableName = $assignmentAst.Left.VariablePath.UserPath
            if ($variableName -in @('PRESETS', 'CACHE_PATHS')) {
                $definitions.Add($assignmentAst.Extent.Text)
            }
        }
    }

    $definitions.Count | Should -BeGreaterThan 0
    . ([scriptblock]::Create(($definitions -join [Environment]::NewLine + [Environment]::NewLine)))
}

Describe "ARCRaidersUtility Script Initialization" {
    It "Should safely source the script" {
        $true | Should -Be $true
    }

    It "Should export the expected helper functions" {
        $expectedFunctions = @(
            "Write-Log",
            "Is-Admin",
            "Detect-RTX",
            "Set-IniValue",
            "Action-RTXDetect",
            "Action-ApplyPreset",
            "Action-Backup",
            "Action-NetFix",
            "Action-Optimize",
            "Action-CpuBoost",
            "Action-ClearCaches",
            "Action-Rollback"
        )

        foreach ($funcName in $expectedFunctions) {
            $func = Get-Command -Name $funcName -ErrorAction SilentlyContinue
            $func | Should -Not -BeNullOrEmpty
            $func.CommandType | Should -Be "Function"
        }
    }
}

Describe "ARCRaidersUtility Functions" {
    BeforeAll {
        function Write-Host {}
        Mock Write-Host {}
        Mock Get-CimInstance { return [pscustomobject]@{ Name = 'Test GPU' } }
        Mock Test-Path { return $false }
        Mock Get-Content {}
        Mock Set-Content {}
    }

    It "Should not throw when detecting RTX" {
        { Detect-RTX } | Should -Not -Throw
    }

    It "Should validate preset names" {
        $presets = $PRESETS
        $presets.Keys -contains 'High' | Should -Be $true
        $presets.Keys -contains 'Low' | Should -Be $true
        $presets.Keys -contains 'Cinematic' | Should -Be $true
    }

    It "Should export all cache path categories" {
        $CACHE_PATHS.Keys -contains 'ARC Raiders cache' | Should -Be $true
        $CACHE_PATHS.Keys -contains 'NVIDIA cache' | Should -Be $true
        $CACHE_PATHS.Keys -contains 'Steam cache' | Should -Be $true
    }
}