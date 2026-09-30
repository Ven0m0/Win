#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    $script:ScriptPath = "$PSScriptRoot/../Scripts/system-update.ps1"

    # The script runs updates at top level (no dispatcher guard) and requires admin, so it
    # is never executed here. Its AST is parsed instead and only the helper functions under
    # test are defined in this scope.
    $parseErrors = $null
    $script:Ast = [System.Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path $ScriptPath).Path, [ref]$null, [ref]$parseErrors)
    $script:ParseErrors = $parseErrors

    $wanted = @(
        'Test-Command', 'ConvertTo-StringMap', 'Write-Section', 'Write-UpdateLog', 'Write-Status',
        'Write-Detail', 'Update-ChocolateyState', 'Compare-PackageMap', 'Invoke-Update',
        'Complete-StepState', 'Get-WingetUpgradeEntry'
    )
    $functionAsts = $Ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -in $wanted
        }, $false)
    foreach ($fn in $functionAsts) {
        . ([scriptblock]::Create($fn.Extent.Text))
    }

    # Stub so Test-Command 'choco' resolves without a real Chocolatey install.
    function choco { }

    function Get-InvokeUpdateCall {
        param([string]$Name)
        $Ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.GetCommandName() -eq 'Invoke-Update' -and
                $node.Extent.Text -match "-Name '$Name'"
            }, $true) | Select-Object -First 1
    }
}

Describe 'system-update.ps1' {
    BeforeEach {
        $commandCache = @{}
        $isAdmin = $true
        $FastMode = $false
        $script:IsSimulation = $false
        $script:LogFile = Join-Path $TestDrive 'system-update.log'
        $script:SectionTimings = @{}
        $script:State = @{ Chocolatey = @{ keep = '1.0' } }
        $updateResults = @{
            Success = [System.Collections.Generic.List[string]]::new()
            Failed  = [System.Collections.Generic.List[string]]::new()
            Checked = [System.Collections.Generic.List[string]]::new()
            Skipped = [System.Collections.Generic.List[pscustomobject]]::new()
            Details = [ordered]@{}
        }
        Mock Write-Host { }
    }

    It 'Parses without syntax errors' {
        $ParseErrors | Should -BeNullOrEmpty
    }

    Context 'Invoke-Update gating' {
        It '-DryRun (simulation) skips the step action and records no result' {
            $script:IsSimulation = $true
            $ran = @{ Value = $false }

            Invoke-Update -Name 'Probe' -Action { $ran.Value = $true }

            $ran.Value | Should -BeFalse
            $updateResults.Success.Count + $updateResults.Failed.Count + $updateResults.Checked.Count |
                Should -Be 0
        }

        It 'Records skip reason <Reason>' -ForEach @(
            @{ Reason = 'flag'; Splat = @{ Disabled = $true } }
            @{ Reason = 'not installed'; Splat = @{ RequiresCommand = 'definitely-not-a-real-command-xyz' } }
            @{ Reason = 'requires admin'; Splat = @{ RequiresAdmin = $true }; NonAdmin = $true }
            @{ Reason = 'fast mode'; Splat = @{ SlowOperation = $true }; Fast = $true }
        ) {
            if ($NonAdmin) { $isAdmin = $false }
            if ($Fast) { $FastMode = $true }
            $ran = @{ Value = $false }

            Invoke-Update -Name 'Probe' -Action { $ran.Value = $true } @Splat

            $ran.Value | Should -BeFalse
            $updateResults.Skipped[0].Reason | Should -Be $Reason
        }

        It 'Records a throwing step as Failed without aborting the run' {
            { Invoke-Update -Name 'Boom' -Action { throw 'kaput' } } | Should -Not -Throw

            $updateResults.Failed | Should -Contain 'Boom'
            $updateResults.Details['Boom'] | Should -Be 'kaput'
        }

        It 'Separates changed steps (Success) from no-op steps (Checked)' {
            Invoke-Update -Name 'Changed' -Action { $script:stepChanged = $true }
            Invoke-Update -Name 'Current' -Action { }

            $updateResults.Success | Should -Be @('Changed')
            $updateResults.Checked | Should -Be @('Current')
        }
    }

    Context 'Update-ChocolateyState' {
        It 'Does not run choco when not elevated (regression: -and precedence)' {
            # Unparenthesized `Test-Command 'choco' -and $isAdmin` passed -and/$isAdmin as extra
            # arguments to Test-Command, so choco ran whenever it existed, admin or not.
            $isAdmin = $false
            Mock choco { 'pkg 1.0' }

            Update-ChocolateyState

            Should -Invoke choco -Times 0 -Exactly
            $script:State.Chocolatey.Keys | Should -Be @('keep')
        }

        It 'Parses "choco list" output into a name/version map when elevated' {
            Mock choco { "Chocolatey v2.2.2`n7zip 23.1.0`ngit 2.44.0`n2 packages installed." }

            Update-ChocolateyState

            $script:State.Chocolatey['7zip'] | Should -Be '23.1.0'
            $script:State.Chocolatey['git'] | Should -Be '2.44.0'
            $script:State.Chocolatey.Count | Should -Be 2
        }
    }

    Context 'Windows Update step' {
        It 'Wraps the whole WindowsUpdate step in `if (-not $SkipWindowsUpdate)`' {
            $call = Get-InvokeUpdateCall -Name 'WindowsUpdate'
            $call | Should -Not -BeNullOrEmpty

            $parentIf = $call.Parent
            while ($parentIf -and $parentIf -isnot [System.Management.Automation.Language.IfStatementAst]) {
                $parentIf = $parentIf.Parent
            }
            $parentIf.Clauses[0].Item1.Extent.Text | Should -Be '-not $SkipWindowsUpdate'
        }

        It 'Only touches PSWindowsUpdate inside the step action, never at script level' {
            $call = Get-InvokeUpdateCall -Name 'WindowsUpdate'
            $moduleCalls = $Ast.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -in 'Install-Module', 'Import-Module' -and
                    $node.Extent.Text -match 'PSWindowsUpdate'
                }, $true)

            $moduleCalls | Should -Not -BeNullOrEmpty
            foreach ($moduleCall in $moduleCalls) {
                $moduleCall.Extent.StartOffset | Should -BeGreaterThan $call.Extent.StartOffset
                $moduleCall.Extent.EndOffset | Should -BeLessThan $call.Extent.EndOffset
            }
        }
    }

    Context 'Paths' {
        It 'Never hardcodes the Windows directory' {
            $literals = $Ast.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
                    $node.Value -match '(?i)^[a-z]:\\windows'
                }, $true)

            $literals | Should -BeNullOrEmpty
        }

        It 'Builds the system Temp and Prefetch paths from $env:SystemRoot' {
            $joins = $Ast.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -eq 'Join-Path' -and
                    $node.Extent.Text -match "'(Temp|Prefetch)'"
                }, $true)

            @($joins).Count | Should -BeGreaterOrEqual 3
            foreach ($join in $joins) {
                $join.CommandElements[1].Extent.Text | Should -Be '$env:SystemRoot'
            }
        }
    }

    Context 'Pure helpers' {
        It 'Get-WingetUpgradeEntry parses upgrade rows and skips headers/separators' {
            # Layout of `winget upgrade --source winget`: a single source means no Source column.
            $output = @(
                'Name               Id                    Version   Available'
                '----------------------------------------------------------'
                'Git                Git.Git               2.44.0    2.45.0'
                'Some Tool          Vendor.Some-Tool      Unknown   1.2.3'
                '2 upgrades available.'
            ) -join "`n"

            $entries = Get-WingetUpgradeEntry -WingetOutput $output

            $entries.Id | Should -Be @('Git.Git', 'Vendor.Some-Tool')
            $entries[1].Version | Should -Be 'Unknown'
        }

        It 'Compare-PackageMap reports added, changed and removed packages' {
            $changes = Compare-PackageMap @{ a = '1'; b = '1'; gone = '9' } @{ a = '1'; b = '2'; new = '3' }

            $changes | Should -Contain '~ b 1 -> 2'
            $changes | Should -Contain '+ new 3 (new)'
            $changes | Should -Contain '- gone 9 (removed)'
            $changes.Count | Should -Be 3
        }
    }
}
