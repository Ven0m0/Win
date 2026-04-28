BeforeAll {
  Import-Module Pester -MinimumVersion 5.0

  # Define mocks for Common.ps1 functions since they are defined there
  function Request-AdminElevation {}
  function Initialize-ConsoleUI {}

  # We must use the . dot-sourcing pattern that avoids side effects
  . "$PSScriptRoot/allow-scripts.ps1"
}

Describe "allow-scripts" {
  Context "Enable-ScriptExecution" {
    BeforeEach {
      Mock Set-RegistryValue {}
      Mock Unblock-File {}
      Mock Get-ChildItem { return @() }
      Mock Write-Host {}
    }

    It "Sets execution policy to RemoteSigned and unblocks files" {
      Enable-ScriptExecution

      Assert-MockCalled Set-RegistryValue -ParameterFilter {
        $Path -eq 'HKCR\Applications\powershell.exe\shell\open\command'
      } -Times 1 -Exactly

      Assert-MockCalled Set-RegistryValue -ParameterFilter {
        $Path -eq 'HKCU\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell' -and
        $Name -eq 'ExecutionPolicy' -and
        $Data -eq 'RemoteSigned'
      } -Times 1 -Exactly

      Assert-MockCalled Set-RegistryValue -ParameterFilter {
        $Path -eq 'HKLM\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell' -and
        $Name -eq 'ExecutionPolicy' -and
        $Data -eq 'RemoteSigned'
      } -Times 1 -Exactly

      Assert-MockCalled Get-ChildItem -Times 1 -Exactly
    }
  }

  Context "Disable-ScriptExecution" {
    BeforeEach {
      Mock Remove-RegistryValue {}
      Mock Set-RegistryValue {}
      Mock Write-Host {}
    }

    It "Removes file associations and restricts execution policy" {
      Disable-ScriptExecution

      Assert-MockCalled Remove-RegistryValue -ParameterFilter {
        $Path -eq 'HKCR\Applications\powershell.exe'
      } -Times 1 -Exactly

      Assert-MockCalled Remove-RegistryValue -ParameterFilter {
        $Path -eq 'HKCR\ps1_auto_file'
      } -Times 1 -Exactly

      Assert-MockCalled Set-RegistryValue -ParameterFilter {
        $Path -eq 'HKCU\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell' -and
        $Name -eq 'ExecutionPolicy' -and
        $Data -eq 'Restricted'
      } -Times 1 -Exactly

      Assert-MockCalled Set-RegistryValue -ParameterFilter {
        $Path -eq 'HKLM\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell' -and
        $Name -eq 'ExecutionPolicy' -and
        $Data -eq 'Restricted'
      } -Times 1 -Exactly
    }
  }
}
