#Requires -Version 5.1

BeforeAll {
  Import-Module Pester -MinimumVersion 5.0
}

# Top-level script; invoked with '&' against fixture files in $TestDrive using the real
# PSScriptAnalyzer, so only $TestDrive is ever rewritten. The script signals findings/changes
# through 'exit 1', which surfaces here as $LASTEXITCODE.
Describe 'Format-PSScripts.ps1' {
  BeforeAll {
    Import-Module PSScriptAnalyzer
    . "$PSScriptRoot/../Scripts/Common.ps1"
    $script:scriptPath = Join-Path -Path $PSScriptRoot -ChildPath '../Scripts/Format-PSScripts.ps1'
    $script:unformatted = "function Get-Thing {`r`n[CmdletBinding()]`r`nparam ()`r`nWrite-Output -InputObject 1`r`n}`r`n"
    # Repo style: 2-space indent (the formatter's own default would be 4).
    $script:formatted = "function Get-Thing {`r`n  [CmdletBinding()]`r`n  param ()`r`n  Write-Output -InputObject 1`r`n}`r`n"
  }

  BeforeEach {
    $fixture = Join-Path -Path $TestDrive -ChildPath 'fixture.ps1'
    Set-Content -Path $fixture -Value $unformatted -NoNewline
    $global:LASTEXITCODE = 0

    Mock Write-Header { }
    Mock Write-Success { }
    Mock Write-Warn { }
    Mock Write-ColorOutput { }
  }

  Context 'Lint mode' {
    It 'Exits 0 and leaves a clean file alone' {
      & $scriptPath -Path $fixture

      $LASTEXITCODE | Should -Be 0
      Should -Invoke Write-Success -Times 1 -Exactly
      Get-Content -Path $fixture -Raw | Should -BeExactly $unformatted
    }

    It 'Exits 1 and reports the file when the analyzer has findings' {
      Set-Content -Path $fixture -Value "Invoke-Expression -Command 'Get-Date'"

      & $scriptPath -Path $fixture

      $LASTEXITCODE | Should -Be 1
      Should -Invoke Write-Warn -Times 1 -Exactly -ParameterFilter { $Text -like '*fixture.ps1' }
    }

    It 'Recurses directories and only picks up .ps1 and .psm1 files' {
      $null = New-Item -ItemType Directory -Path "$TestDrive\sub" -Force
      Set-Content -Path "$TestDrive\sub\module.psm1" -Value '# module'
      Set-Content -Path "$TestDrive\sub\notes.txt" -Value 'not a script'
      Mock Invoke-ScriptAnalyzer { }

      & $scriptPath -Path $TestDrive

      Should -Invoke Invoke-ScriptAnalyzer -Times 2 -Exactly
      Should -Invoke Invoke-ScriptAnalyzer -Times 0 -ParameterFilter { $Path -like '*.txt' }
    }
  }

  Context 'Format mode' {
    It 'Rewrites an unformatted file with Invoke-Formatter output and exits 1' {
      & $scriptPath -Path $fixture -Mode Format

      $LASTEXITCODE | Should -Be 1
      Get-Content -Path $fixture -Raw | Should -BeExactly $formatted
    }

    It 'Exits 0 without rewriting an already formatted file' {
      Set-Content -Path $fixture -Value $formatted -NoNewline
      $before = (Get-Item -Path $fixture).LastWriteTimeUtc

      & $scriptPath -Path $fixture -Mode Format

      $LASTEXITCODE | Should -Be 0
      (Get-Item -Path $fixture).LastWriteTimeUtc | Should -Be $before
    }

    It 'Keeps a UTF-8 BOM when rewriting' {
      [System.IO.File]::WriteAllText($fixture, $unformatted, [System.Text.UTF8Encoding]::new($true))

      & $scriptPath -Path $fixture -Mode Format

      $bytes = [System.IO.File]::ReadAllBytes($fixture)
      $bytes[0..2] | Should -Be @(0xEF, 0xBB, 0xBF)
      [System.IO.File]::ReadAllText($fixture) | Should -BeExactly $formatted
    }

    It 'Reports but does not rewrite under -WhatIf' {
      & $scriptPath -Path $fixture -Mode Format -WhatIf

      $LASTEXITCODE | Should -Be 1
      Get-Content -Path $fixture -Raw | Should -BeExactly $unformatted
    }
  }

  Context 'Parameter validation' {
    It 'Throws when the settings file does not exist' {
      { & $scriptPath -Path $fixture -SettingsPath "$TestDrive\missing.psd1" } |
        Should -Throw '*Settings file not found*'
    }

    It 'Rejects an unknown mode' {
      { & $scriptPath -Path $fixture -Mode Rewrite } | Should -Throw '*does not belong to the set*'
    }
  }
}
