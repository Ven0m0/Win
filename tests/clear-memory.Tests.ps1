#Requires -Version 5.1

BeforeDiscovery {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $script:notAdmin = -not ([Security.Principal.WindowsPrincipal]$identity).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
}

BeforeAll {
  Import-Module Pester -MinimumVersion 5.0
}

# The script body is top-level (no dispatcher guard), so each test invokes it with '&' after every
# state-changing command is mocked. Pester mocks are aliases, so they still win after the script
# re-dot-sources Common.ps1. '#Requires -RunAsAdministrator' means this only runs elevated.
Describe 'clear-memory.ps1' -Skip:$notAdmin {
  BeforeAll {
    . "$PSScriptRoot/../Scripts/Common.ps1"
    $script:scriptPath = Join-Path -Path $PSScriptRoot -ChildPath '../Scripts/clear-memory.ps1'
  }

  BeforeEach {
    # Mock bodies run inside the invoked script's scope; share state through a reference object
    # found by dynamic scoping instead of $script: variables.
    $clearMemState = @{ CimCalls = 0; FreeKb = @(1000, 3000); ServiceStatus = @{} }
    $clearMemState.ServiceStatus = @{ WSearch = 'Running'; DoSvc = 'Stopped' }

    Mock Get-Service {
      $status = $clearMemState.ServiceStatus[$Name]
      if ($status) { [pscustomobject]@{ Name = $Name; Status = $status } }
    }
    Mock Stop-Service { }
    Mock Get-CimInstance {
      $value = $clearMemState.FreeKb[[math]::Min($clearMemState.CimCalls, 1)]
      $clearMemState.CimCalls++
      [pscustomobject]@{ FreePhysicalMemory = $value }
    }
    Mock Invoke-MemoryTrim { }
    Mock Start-Sleep { }
    Mock Get-FolderSize { 0 }
    Mock Clear-DirectorySafe { }
    Mock Remove-Item { }
    Mock Write-Info { }
    Mock Write-Warn { }
    Mock Write-Success { }
  }

  It 'Stops only services that are running' {
    & $scriptPath

    Should -Invoke Stop-Service -Times 1 -Exactly
    Should -Invoke Stop-Service -Times 1 -Exactly -ParameterFilter { $Name -eq 'WSearch' }
  }

  It 'Skips services that do not exist' {
    $clearMemState.ServiceStatus = @{}

    & $scriptPath

    Should -Invoke Stop-Service -Times 0
  }

  It 'Warns and continues when Stop-Service fails' {
    Mock Stop-Service { throw 'access denied' }

    { & $scriptPath } | Should -Not -Throw

    Should -Invoke Write-Warn -Times 1 -Exactly -ParameterFilter {
      $Text -like 'Could not stop WSearch*access denied*'
    }
    Should -Invoke Invoke-MemoryTrim -Times 1 -Exactly
  }

  It 'Trims memory and reports the freed amount' {
    & $scriptPath

    Should -Invoke Invoke-MemoryTrim -Times 1 -Exactly -ParameterFilter { $TypeName -eq 'ClearMemoryTrim' }
    $expectedFreed = Format-Size -Bytes (2000 * 1KB)
    Should -Invoke Write-Success -Times 1 -Exactly -ParameterFilter {
      $Text -like "Free RAM after:*(+$expectedFreed freed)"
    }
  }

  It 'Clears the user and system temp folders' {
    & $scriptPath

    Should -Invoke Clear-DirectorySafe -Times 2 -Exactly
    Should -Invoke Clear-DirectorySafe -Times 1 -Exactly -ParameterFilter { $Path -eq $env:TEMP }
    Should -Invoke Clear-DirectorySafe -Times 1 -Exactly -ParameterFilter {
      $Path -eq "$env:SystemRoot\Temp"
    }
  }

  It 'Does not stop services, trim memory, or clear temp folders under -WhatIf' {
    & $scriptPath -WhatIf

    Should -Invoke Stop-Service -Times 0
    Should -Invoke Invoke-MemoryTrim -Times 0
    Should -Invoke Clear-DirectorySafe -Times 0
  }
}
