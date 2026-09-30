#Requires -Version 5.1

BeforeDiscovery {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $script:notAdmin = -not ([Security.Principal.WindowsPrincipal]$identity).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
}

BeforeAll {
  Import-Module Pester -MinimumVersion 5.0
}

# Top-level script with '#Requires -RunAsAdministrator'; invoked with '&' after every CIM, registry,
# and powercfg call is mocked.
Describe 'DisableUSBPowerManagement.ps1' -Skip:$notAdmin {
  BeforeAll {
    . "$PSScriptRoot/../Scripts/Common.ps1"
    $script:scriptPath = Join-Path -Path $PSScriptRoot -ChildPath '../Scripts/DisableUSBPowerManagement.ps1'
    function powercfg { }
    # The real cmdlet only binds [CimInstance]; this stub lets the fixtures be plain objects.
    function Set-CimInstance { param($InputObject, [hashtable]$Property) }
  }

  BeforeEach {
    # Mock bodies run inside the invoked script's scope; share data through this reference object.
    $usbState = @{
      Devices   = @([pscustomobject]@{ Name = 'Mouse'; PNPDeviceID = 'USB\VID_1234&PID_5678\SER1' })
      PowerMgmt = @([pscustomobject]@{ InstanceName = 'USB\VID_1234&PID_5678\SER1_0'; Enable = $true })
      WakeArmed = @('NONE')
    }

    Mock Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_PnPEntity' } { $usbState.Devices }
    Mock Get-CimInstance -ParameterFilter { $ClassName -eq 'MSPower_DeviceEnable' } { $usbState.PowerMgmt }
    Mock Set-CimInstance { }
    Mock Set-RegistryValue { }
    Mock powercfg { if ($args[0] -eq '-devicequery') { $usbState.WakeArmed } }
    Mock Clear-Host { }
    Mock Write-Host { }
    Mock Write-Verbose { }
    Mock Write-Warning { }
    Mock Read-Host { }
    $global:LASTEXITCODE = 0
  }

  It 'Disables power management and clears the WDF idle flag for an enabled device' {
    & $scriptPath

    Should -Invoke Set-CimInstance -Times 1 -Exactly -ParameterFilter { $Property.Enable -eq $false }
    # The trailing '_0' WMI instance suffix is stripped to get the Enum registry key.
    Should -Invoke Set-RegistryValue -Times 1 -Exactly -ParameterFilter {
      $Path -eq 'HKLM\SYSTEM\ControlSet001\Enum\USB\VID_1234&PID_5678\SER1\Device Parameters\WDF' -and
      $Name -eq 'IdleInWorkingState' -and $Data -eq '0'
    }
    $LASTEXITCODE | Should -Be 0
  }

  It 'Skips devices whose power management is already disabled' {
    $usbState.PowerMgmt[0].Enable = $false

    & $scriptPath

    Should -Invoke Set-CimInstance -Times 0
    Should -Invoke Set-RegistryValue -Times 0
  }

  It 'Ignores power entries with no matching PnP device' {
    $usbState.Devices = @([pscustomobject]@{ Name = 'Other'; PNPDeviceID = 'USB\VID_FFFF&PID_0000\X' })

    & $scriptPath

    Should -Invoke Set-CimInstance -Times 0
  }

  It 'Treats regex metacharacters in PNPDeviceID literally' {
    # Unescaped, '.' would match the 'X' in the instance name and disable the wrong device.
    $usbState.Devices = @([pscustomobject]@{ Name = 'Dot'; PNPDeviceID = 'USB\VID.1' })
    $usbState.PowerMgmt = @([pscustomobject]@{ InstanceName = 'USB\VIDX1_0'; Enable = $true })

    & $scriptPath

    Should -Invoke Set-CimInstance -Times 0
  }

  It 'Warns and exits 1 when a device cannot be updated' {
    Mock Set-CimInstance { throw 'not supported' }

    & $scriptPath

    Should -Invoke Write-Warning -ParameterFilter { $Message -like '*`[FAILED`]*Mouse*' }
    Should -Invoke Set-RegistryValue -Times 0
    $LASTEXITCODE | Should -Be 1
  }

  It 'Disables wake for each armed device and ignores the NONE placeholder' {
    $usbState.WakeArmed = @('HID Keyboard', 'NONE', '')

    & $scriptPath

    Should -Invoke powercfg -Times 1 -Exactly -ParameterFilter { $args[0] -eq '-devicedisablewake' }
    Should -Invoke powercfg -Times 1 -Exactly -ParameterFilter {
      $args[0] -eq '-devicedisablewake' -and $args[1] -eq 'HID Keyboard'
    }
  }

  It 'Makes no changes under -WhatIf' {
    $usbState.WakeArmed = @('HID Keyboard')

    & $scriptPath -WhatIf

    Should -Invoke Set-CimInstance -Times 0
    Should -Invoke Set-RegistryValue -Times 0
    Should -Invoke powercfg -Times 0 -ParameterFilter { $args[0] -eq '-devicedisablewake' }
  }

  It 'Stops before changing anything when the PnP query fails' {
    Mock Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_PnPEntity' } { throw 'WMI down' }

    # Write-Error under $ErrorActionPreference = 'Stop' terminates before the script's 'exit 1'.
    { & $scriptPath } | Should -Throw '*Failed to query Win32_PnPEntity*'
    Should -Invoke Set-CimInstance -Times 0
  }
}
