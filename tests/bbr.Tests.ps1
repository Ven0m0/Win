#Requires -Version 5.1

BeforeAll {
  Import-Module Pester -MinimumVersion 5.0
  $script:scriptPath = Join-Path -Path $PSScriptRoot -ChildPath '../Scripts/bbr.ps1'
}

# The script body is top-level, so each test invokes it with '&' after every system-touching command is
# mocked: netsh.exe (the only thing that changes TCP state) and Request-AdminElevation (a real call would
# relaunch the host elevated and exit). Pester mocks still win after the script re-dot-sources Common.ps1.
Describe 'bbr.ps1' {
  BeforeAll {
    . "$PSScriptRoot/../Scripts/Common.ps1"
  }

  BeforeEach {
    $global:LASTEXITCODE = 0
    # Mock bodies run in the invoked script's scope; share state through a reference object found by
    # dynamic scoping instead of $script: variables.
    $netsh = @{ Calls = [System.Collections.Generic.List[string]]::new(); Exit = 0 }
    Mock netsh.exe {
      # Native commands flatten array arguments; a function mock receives them as one array, so unroll
      $netsh.Calls.Add((@($args | ForEach-Object { $_ }) -join ' '))
      $global:LASTEXITCODE = $netsh.Exit
    }
    Mock Request-AdminElevation { }
    Mock Start-Process { }
    Mock Read-Host { '1' }
    Mock Write-Information { }
  }

  Context 'Parameter validation' {
    It 'Rejects a provider outside bbr2/cubic' {
      { & $scriptPath -Provider 'reno' } | Should -Throw
      $netsh.Calls.Count | Should -Be 0
    }

    It 'Declares Provider as a ValidateSet of bbr2 and cubic' {
      $cmd = Get-Command -Name $scriptPath
      $set = $cmd.Parameters['Provider'].Attributes |
        Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
      $set.ValidValues | Should -Be @('bbr2', 'cubic')
    }
  }

  Context 'Applying a provider' {
    It 'Sets the cubic provider and the related TCP globals through four netsh calls' {
      & $scriptPath -Provider cubic

      $netsh.Calls.Count | Should -Be 4
      $netsh.Calls | Should -Contain 'int tcp set supplemental template=internet congestionprovider=cubic'
      $netsh.Calls | Should -Contain 'int tcp set global rss=enabled'
      $netsh.Calls | Should -Contain 'int tcp set global fastopen=enabled'
      $netsh.Calls | Should -Contain 'int tcp set global ecncapability=enabled'
    }

    It 'Sets the bbr2 provider and not cubic' {
      & $scriptPath -Provider bbr2

      $netsh.Calls | Should -Contain 'int tcp set supplemental template=internet congestionprovider=bbr2'
      ($netsh.Calls -join ';') | Should -Not -BeLike '*cubic*'
    }

    It 'Requests elevation and forwards the chosen provider' {
      & $scriptPath -Provider cubic

      Should -Invoke Request-AdminElevation -Times 1 -Exactly -ParameterFilter {
        $BoundParameters['Provider'] -eq 'cubic'
      }
    }

    It 'Makes no netsh call under -WhatIf' {
      & $scriptPath -Provider bbr2 -WhatIf

      $netsh.Calls.Count | Should -Be 0
    }

    It 'Throws with the failing setting when netsh returns a non-zero exit code' {
      $netsh.Exit = 1

      { & $scriptPath -Provider cubic } | Should -Throw '*netsh failed (exit 1)*congestionprovider=cubic*'
      $netsh.Calls.Count | Should -Be 1
    }
  }

  Context 'Interactive menu' {
    It 'Maps choice 1 to bbr2 and forwards it to the elevation call' {
      Mock Read-Host { '1' }

      & $scriptPath

      $netsh.Calls | Should -Contain 'int tcp set supplemental template=internet congestionprovider=bbr2'
      Should -Invoke Request-AdminElevation -Times 1 -Exactly -ParameterFilter {
        $BoundParameters['Provider'] -eq 'bbr2'
      }
    }

    It 'Maps choice 2 to cubic' {
      Mock Read-Host { '2' }

      & $scriptPath

      $netsh.Calls | Should -Contain 'int tcp set supplemental template=internet congestionprovider=cubic'
    }

    It 'Throws on an invalid choice before elevating or changing anything' {
      Mock Read-Host { 'x' }

      { & $scriptPath } | Should -Throw "*Invalid choice: 'x'*"
      Should -Invoke Request-AdminElevation -Times 0 -Exactly
      $netsh.Calls.Count | Should -Be 0
    }

    It 'Does not prompt when -Provider is given' {
      & $scriptPath -Provider cubic

      Should -Invoke Read-Host -Times 0 -Exactly
    }
  }
}
