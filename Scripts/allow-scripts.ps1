#Requires -Version 5.1

# allow-scripts.ps1 - PowerShell Script Execution Policy Manager
# Enables or disables PowerShell script execution and file associations

#Requires -RunAsAdministrator

. "$PSScriptRoot\Common.ps1"


function Enable-ScriptExecution {
  <#
  .SYNOPSIS
    Sets execution policy to RemoteSigned and unblocks scripts in this directory.
  #>
  Write-Host "Enabling PowerShell scripts..." -ForegroundColor Cyan
  Write-Host ""

  Write-Host "[1/3] Configuring PowerShell file associations..."
  Set-RegistryValue -Path 'HKCR\Applications\powershell.exe\shell\open\command' -Name '' `
    -Type REG_SZ `
    -Data 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -ExecutionPolicy RemoteSigned -File "%1"'

  Write-Host "[2/3] Setting execution policy to RemoteSigned..."
  Set-RegistryValue -Path 'HKCU\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell' `
    -Name 'ExecutionPolicy' -Type REG_SZ -Data 'RemoteSigned'
  Set-RegistryValue -Path 'HKLM\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell' `
    -Name 'ExecutionPolicy' -Type REG_SZ -Data 'RemoteSigned'

  Write-Host "[3/3] Unblocking all scripts in current directory..."
  Get-ChildItem -Path $PSScriptRoot -Recurse -ErrorAction SilentlyContinue |
    Unblock-File -ErrorAction SilentlyContinue

  Write-Host ""
  Write-Host "PowerShell Scripts Enabled!" -ForegroundColor Green
  Write-Host "  - Scripts can now be run by double-clicking" -ForegroundColor Gray
  Write-Host "  - Execution policy set to RemoteSigned" -ForegroundColor Gray
  Write-Host "  - All files in this directory unblocked" -ForegroundColor Gray
}

function Disable-ScriptExecution {
  <#
  .SYNOPSIS
    Removes PowerShell file associations and restricts execution policy.
  #>
  Write-Host "Disabling PowerShell scripts..." -ForegroundColor Cyan
  Write-Host ""

  Write-Host "[1/2] Removing PowerShell file associations..."
  Remove-RegistryValue -Path 'HKCR\Applications\powershell.exe' -Name '' -ErrorAction SilentlyContinue
  Remove-RegistryValue -Path 'HKCR\ps1_auto_file' -Name '' -ErrorAction SilentlyContinue

  Write-Host "[2/2] Setting execution policy to Restricted..."
  Set-RegistryValue -Path 'HKCU\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell' `
    -Name 'ExecutionPolicy' -Type REG_SZ -Data 'Restricted'
  Set-RegistryValue -Path 'HKLM\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell' `
    -Name 'ExecutionPolicy' -Type REG_SZ -Data 'Restricted'

  Write-Host ""
  Write-Host "PowerShell Scripts Disabled!" -ForegroundColor Yellow
  Write-Host "  - Script execution has been restricted" -ForegroundColor Gray
  Write-Host "  - Double-click execution disabled" -ForegroundColor Gray
}

if ($MyInvocation.InvocationName -ne '.') {
  Request-AdminElevation
  Initialize-ConsoleUI -Title "PowerShell Script Manager (Administrator)"

  while ($true) {
    Show-Menu -Title "PowerShell Script Manager" -Options @(
      "Enable Scripts (Recommended)"
      "Disable Scripts"
      "Exit"
    )

    $choice = Get-MenuChoice -Min 1 -Max 3

    switch ($choice) {
      1 {
        Enable-ScriptExecution
        Wait-ForKeyPress -Message "Press any key to continue..."
      }
      2 {
        Disable-ScriptExecution
        Wait-ForKeyPress -Message "Press any key to continue..."
      }
      3 { exit }
    }
  }
}
