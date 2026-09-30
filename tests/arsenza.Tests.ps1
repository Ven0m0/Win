#Requires -Version 5.1

BeforeDiscovery {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $script:notAdmin = -not ([Security.Principal.WindowsPrincipal]$identity).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
}

BeforeAll {
  Import-Module Pester -MinimumVersion 5.0
}

# The script has '#Requires -RunAsAdministrator', so it can only be invoked from an elevated session.
Describe 'arsenza.ps1' -Skip:$notAdmin {
  BeforeAll {
    $script:scriptPath = Join-Path -Path $PSScriptRoot -ChildPath '../Scripts/arsenza.ps1'
    $script:planGuid = '9aebceaa-2f39-4339-9a54-749a56ee82b4'
    function powercfg { }
  }

  BeforeEach {
    # Mock bodies run in the invoked script's scope, so they return literals rather than test variables.
    Mock powercfg {
      if ($args[0] -eq '/list') { 'Power Scheme GUID: 381b4222-f694-41f0-9685-ff5bb260df2e  (Balanced)' }
    }
    Mock Test-Path { $true }
    Mock Write-Host { }
  }

  It 'Imports the plan with its fixed GUID when it is not yet present' {
    & $scriptPath

    Should -Invoke powercfg -Times 1 -Exactly -ParameterFilter {
      $args[0] -eq '/import' -and $args[1] -like '*arsenza.pow' -and $args[2] -eq $planGuid
    }
    Should -Invoke powercfg -Times 0 -ParameterFilter { $args[0] -eq '/setactive' }
  }

  It 'Skips the import when the plan GUID is already listed' {
    Mock powercfg {
      if ($args[0] -eq '/list') { 'Power Scheme GUID: 9aebceaa-2f39-4339-9a54-749a56ee82b4  (ARSENZA)' }
    }

    & $scriptPath

    Should -Invoke powercfg -Times 0 -ParameterFilter { $args[0] -eq '/import' }
  }

  It 'Activates the plan with -SetActive' {
    & $scriptPath -SetActive

    Should -Invoke powercfg -Times 1 -Exactly -ParameterFilter {
      $args[0] -eq '/setactive' -and $args[1] -eq $planGuid
    }
  }

  It 'Makes no changes under -WhatIf' {
    & $scriptPath -SetActive -WhatIf

    Should -Invoke powercfg -Times 0 -ParameterFilter { $args[0] -in '/import', '/setactive' }
  }

  It 'Fails before calling powercfg when the .pow file is missing' {
    Mock Test-Path { $false }

    { & $scriptPath -SetActive } | Should -Throw '*Power plan file not found*'
    Should -Invoke powercfg -Times 0
  }
}
