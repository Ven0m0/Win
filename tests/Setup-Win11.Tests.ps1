#Requires -Version 5.1

BeforeAll {
  Import-Module Pester -MinimumVersion 5.0
  . "$PSScriptRoot/../Scripts/Setup-Win11.ps1"

  # External tools are replaced by stubs so Pester can mock them; nothing real is ever invoked.
  function wsl { }
  function git { }
  function winget { param([Parameter(ValueFromRemainingArguments)]$Rest) }
  function mise { param([Parameter(ValueFromRemainingArguments)]$Rest) }
  function Add-AppxPackage { param([switch]$RegisterByFamilyName, $MainPackage) }
}

# AGENTS.md gotcha: mocking Test-Path does NOT stop `& $debloatScript` / `& $installScript` from running the
# real files. Every call below therefore passes -SkipDebloat -SkipPackages unless the test never reaches those
# phases (not-admin relaunch, missing prerequisites).
Describe "Start-SetupWin11" {
  BeforeEach {
    $global:LASTEXITCODE = 0
    # Mock bodies resolve this through dynamic scoping; keep all per-test knobs in one object.
    $setup = @{
      Present   = @{ winget = $true; git = $true; pwsh = $true; mise = $true }
      MiseExit  = @{ install = 0; run = 0 }
      WingetExit = 0
      WslExit   = 1
      WslCalls  = [System.Collections.Generic.List[string]]::new()
    }

    Mock Test-IsAdmin { $true }
    Mock Add-AppxPackage { }
    Mock Initialize-ShellEnvironment { }
    Mock Get-Command {
      if ($setup.Present[$Name]) { [pscustomobject]@{ Name = $Name; Source = "$Name.exe" } }
    } -ParameterFilter { $Name -in @('winget', 'git', 'pwsh', 'mise') }
    Mock mise { $global:LASTEXITCODE = $setup.MiseExit[$Rest[0]] }
    Mock winget { $global:LASTEXITCODE = $setup.WingetExit }
    Mock wsl.exe {
      $setup.WslCalls.Add((@($args | ForEach-Object { $_ }) -join ' '))
      $global:LASTEXITCODE = $setup.WslExit
    }
    Mock Start-Process { }
    Mock Push-Location { }
    Mock Pop-Location { }
    Mock Write-Host { }
    function Write-Fail { param($msg) }
  }

  Context "Elevation" {
    It "Relaunches elevated with the chosen switches and does no setup work when not admin" {
      Mock Test-IsAdmin { $false }

      $result = Start-SetupWin11 -Unattended -SkipWSL

      $result | Should -BeTrue
      Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
        $Verb -eq 'RunAs' -and $ArgumentList -like '*-Unattended*' -and $ArgumentList -like '*-SkipWSL*' -and
        $ArgumentList -notlike '*-Force*'
      }
      Should -Invoke mise -Times 0 -Exactly
    }
  }

  Context "When prerequisite is missing" {
    It "Should fail when winget is not found and cannot be registered" {
      $setup.Present['winget'] = $false

      $result = Start-SetupWin11
      $result | Should -Be $false
    }

    It "Fails without deploying when mise is missing" {
      $setup.Present['mise'] = $false

      $result = Start-SetupWin11 -SkipWSL -SkipDebloat -SkipPackages

      $result | Should -BeFalse
      Should -Invoke mise -Times 0 -Exactly
      Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*mise not found*' }
    }

    It "Installs Git through winget when git is missing" {
      $setup.Present['git'] = $false

      $result = Start-SetupWin11 -SkipWSL -SkipDebloat -SkipPackages

      $result | Should -BeTrue
      Should -Invoke winget -Times 1 -Exactly -ParameterFilter { $Rest -contains 'Git.Git' }
    }

    It "Installs PowerShell 7 through winget when pwsh is missing" {
      $setup.Present['pwsh'] = $false

      $null = Start-SetupWin11 -SkipWSL -SkipDebloat -SkipPackages

      Should -Invoke winget -Times 1 -Exactly -ParameterFilter { $Rest -contains 'Microsoft.PowerShell' }
    }

    It "Reports a failed prerequisite install but keeps going" {
      $setup.Present['git'] = $false
      $setup.WingetExit = 1

      $result = Start-SetupWin11 -SkipWSL -SkipDebloat -SkipPackages

      $result | Should -BeTrue
      Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*FAIL*git install failed*' }
    }

    It "Treats winget's already-installed exit code as success" {
      $setup.Present['git'] = $false
      $setup.WingetExit = -1978335189

      $null = Start-SetupWin11 -SkipWSL -SkipDebloat -SkipPackages

      Should -Invoke Write-Host -Times 0 -Exactly -ParameterFilter { "$Object" -like '*FAIL*' }
    }
  }

  Context "When prerequisites are present" {
    It "Should succeed" {
      $result = Start-SetupWin11 -Unattended -SkipWSL -SkipDebloat -SkipPackages
      $result | Should -Be $true
    }

    It "Reports the debloat and package phases as skipped" {
      $null = Start-SetupWin11 -SkipWSL -SkipDebloat -SkipPackages

      Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*SKIP*Debloat skipped*' }
      Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*SKIP*Package install skipped*' }
    }

    It "Runs mise install then mise run bootstrap from the repo root" {
      $null = Start-SetupWin11 -SkipWSL -SkipDebloat -SkipPackages

      Should -Invoke mise -Times 1 -Exactly -ParameterFilter { $Rest -contains 'install' }
      Should -Invoke mise -Times 1 -Exactly -ParameterFilter { $Rest -contains 'run' -and $Rest -contains 'bootstrap' }
      $expectedRoot = Split-Path -Path (Join-Path $PSScriptRoot '../Scripts') -Parent
      Should -Invoke Push-Location -Times 1 -Exactly -ParameterFilter {
        (Resolve-Path -LiteralPath $Path).Path -eq (Resolve-Path -LiteralPath $expectedRoot).Path
      }
      Should -Invoke Pop-Location -Times 1 -Exactly
    }
  }

  Context "Deployment failures" {
    It "Returns false and skips bootstrap when mise install fails" {
      $setup.MiseExit['install'] = 1

      $result = Start-SetupWin11 -SkipWSL -SkipDebloat -SkipPackages

      $result | Should -BeFalse
      Should -Invoke mise -Times 0 -Exactly -ParameterFilter { $Rest -contains 'run' }
      Should -Invoke Pop-Location -Times 1 -Exactly
      Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*Bootstrap failed*mise install failed*' }
    }

    It "Returns false when mise run bootstrap fails" {
      $setup.MiseExit['run'] = 2

      $result = Start-SetupWin11 -SkipWSL -SkipDebloat -SkipPackages

      $result | Should -BeFalse
      Should -Invoke Pop-Location -Times 1 -Exactly
    }
  }

  Context "WSL phase" {
    It "Does not touch wsl.exe with -SkipWSL" {
      $null = Start-SetupWin11 -SkipWSL -SkipDebloat -SkipPackages

      $setup.WslCalls.Count | Should -Be 0
      Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*WSL2 setup skipped*' }
    }

    It "Leaves an existing WSL installation alone" {
      $setup.WslExit = 0

      $null = Start-SetupWin11 -Unattended -SkipDebloat -SkipPackages

      $setup.WslCalls | Should -Contain '--status'
      ($setup.WslCalls -join ';') | Should -Not -BeLike '*--install*'
    }

    It "Installs WSL without prompting when unattended and WSL is absent" {
      $setup.WslExit = 1

      $null = Start-SetupWin11 -Unattended -SkipDebloat -SkipPackages

      ($setup.WslCalls -join ';') | Should -BeLike '*--install --no-distribution*'
    }
  }
}
