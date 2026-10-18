#Requires -Version 5.1

BeforeDiscovery {
  # Key cases are built at discovery time so -ForEach can use them
  $script:acceptedKeys = @('F1', 'F9', 'F10', 'F19', 'F24', 'R', 'r', 'Z', '0', '9')
  $script:rejectedKeys = @('F0', 'F25', 'F100', 'RR', '', '-', ' ', '1F', 'Ctrl')
}

BeforeAll {
  Import-Module Pester -MinimumVersion 5.0
}

# mc-freeze.ps1 registers a system-wide hotkey and Add-Type's P/Invoke at load, and its main loop never
# returns, so it is never run or dot-sourced here. Everything is checked against the parsed AST.
Describe 'mc-freeze.ps1 (static)' {
  BeforeAll {
    $script:scriptPath = (Resolve-Path -Path (Join-Path $PSScriptRoot '../Scripts/mc-freeze.ps1')).Path
    $tokens = $null
    $errors = $null
    $script:ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
    $script:parseErrors = @($errors)
    $script:text = Get-Content -Path $scriptPath -Raw

    $script:params = @{}
    foreach ($p in $ast.ParamBlock.Parameters) {
      $script:params[$p.Name.VariablePath.UserPath] = $p
    }

    function Get-ParamAttribute {
      param([string]$Parameter, [string]$TypeName)
      $params[$Parameter].Attributes | Where-Object { $_.TypeName.Name -eq $TypeName }
    }

    # The validation pattern is pulled out of the script and compiled so behaviour is tested, not just text
    $patternAttr = Get-ParamAttribute -Parameter 'Key' -TypeName 'ValidatePattern'
    $script:keyRegex = [regex]::new($patternAttr.PositionalArguments[0].Value)
  }

  Context 'Parsing and metadata' {
    It 'Parses without syntax errors' {
      $parseErrors.Count | Should -Be 0
    }

    It 'Requires PowerShell 5.1' {
      $text | Should -Match '(?m)^#Requires -Version 5\.1\s*$'
    }

    It 'Has comment-based help with synopsis, description and example' {
      $text | Should -Match '(?m)^\.SYNOPSIS\s*\r?\n\s*\S'
      $text | Should -Match '(?m)^\.DESCRIPTION\s*\r?\n\s*\S'
      $text | Should -Match '(?m)^\.EXAMPLE\s*\r?\n\s*\S'
    }

    It 'Is an advanced script (CmdletBinding)' {
      $ast.ParamBlock.Attributes.TypeName.Name | Should -Contain 'CmdletBinding'
    }

    It 'Stops on errors' {
      $text | Should -Match "\`$ErrorActionPreference = 'Stop'"
    }
  }

  Context 'Parameters' {
    It 'Declares exactly Seconds, Key, TitlePattern and ProcessName' {
      @($params.Keys) | Sort-Object | Should -Be @('Key', 'ProcessName', 'Seconds', 'TitlePattern')
    }

    It 'Defaults Seconds to 10, Key to R, TitlePattern to ^Minecraft and ProcessName to javaw' {
      $params['Seconds'].DefaultValue.Value | Should -Be 10
      $params['Key'].DefaultValue.Value | Should -Be 'R'
      $params['TitlePattern'].DefaultValue.Value | Should -Be '^Minecraft'
      $params['ProcessName'].DefaultValue.Value | Should -Be 'javaw'
    }

    It 'Types Seconds as int' {
      $params['Seconds'].StaticType | Should -Be ([int])
    }

    It 'Limits Seconds to 1-14 (below the ~15 s server keep-alive timeout)' {
      $range = Get-ParamAttribute -Parameter 'Seconds' -TypeName 'ValidateRange'
      $range.PositionalArguments[0].Value | Should -Be 1
      $range.PositionalArguments[1].Value | Should -Be 14
    }

    It 'Default Seconds satisfies its own range' {
      $params['Seconds'].DefaultValue.Value | Should -BeIn (1..14)
    }

    It 'Accepts Key <_>' -ForEach $acceptedKeys {
      $keyRegex.IsMatch($_) | Should -BeTrue
    }

    It 'Rejects Key "<_>"' -ForEach $rejectedKeys {
      $keyRegex.IsMatch($_) | Should -BeFalse
    }

    It 'Default Key satisfies its own pattern' {
      $keyRegex.IsMatch($params['Key'].DefaultValue.Value) | Should -BeTrue
    }
  }

  Context 'Safety of the suspend/resume logic' {
    BeforeAll {
      $script:invokeFreeze = $ast.Find({
          param($node)
          $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-Freeze'
        }, $true)
      $script:tryStatements = $invokeFreeze.FindAll({
          param($node) $node -is [System.Management.Automation.Language.TryStatementAst]
        }, $true)
    }

    It 'Defines Invoke-Freeze' {
      $invokeFreeze | Should -Not -BeNullOrEmpty
    }

    It 'Resumes the process inside a finally block so the game is never left suspended' {
      $finallyBlocks = @($tryStatements | Where-Object { $_.Finally } | ForEach-Object { $_.Finally.Extent.Text })
      ($finallyBlocks -match 'NtResumeProcess').Count | Should -BeGreaterOrEqual 1
    }

    It 'Suspends before the try block and never inside the finally' {
      $suspendPos = $invokeFreeze.Extent.Text.IndexOf('NtSuspendProcess')
      $tryPos = $invokeFreeze.Extent.Text.IndexOf('try {')
      $suspendPos | Should -BeGreaterThan -1
      $suspendPos | Should -BeLessThan $tryPos
      @($tryStatements | Where-Object { $_.Finally -and $_.Finally.Extent.Text -match 'NtSuspendProcess' }).Count |
        Should -Be 0
    }

    It 'Sleeps for -Seconds between suspend and resume' {
      $tryStatements[0].Body.Extent.Text | Should -Match 'Start-Sleep -Seconds \$Seconds'
    }

    It 'Warns instead of freezing when no matching window is found' {
      $invokeFreeze.Extent.Text | Should -Match 'Write-Warning'
    }

    It 'Unregisters the hotkey in a finally block around the main loop' {
      $topLevelTry = @($ast.EndBlock.Statements | Where-Object {
          $_ -is [System.Management.Automation.Language.TryStatementAst]
        })
      $topLevelTry.Count | Should -Be 1
      $topLevelTry[0].Finally.Extent.Text | Should -Match 'UnregisterHotKey'
    }

    It 'Throws when the hotkey cannot be registered' {
      $text | Should -Match 'if \(-not \[McFreeze\]::RegisterHotKey[^\r\n]*\{\s*throw'
    }
  }
}
