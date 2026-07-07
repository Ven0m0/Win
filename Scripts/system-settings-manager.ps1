#Requires -Version 5.1
#Requires -RunAsAdministrator

# system-settings-manager.ps1 - Unified System Settings Manager
# Combines performance settings, keyboard shortcuts, NVIDIA GPU settings,
# MSI mode, EDID overrides, and gaming display optimizations
# Replaces: settings.ps1, keyboard-shortcuts.ps1, nvidia-settings.ps1,
#           edid-manager.ps1, gaming-display.ps1, msi-mode.ps1, gpu-display-manager.ps1

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

. "$PSScriptRoot\Common.ps1"


#region Performance Settings
function Set-PerformanceSetting {
    <#
  .SYNOPSIS
      Applies optimized performance settings for gaming
  #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Clear-Host
    Write-Host "Applying Performance Settings..." -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  [*] Disabling hibernate..." -ForegroundColor Gray
    $null = powercfg /hibernate off 2>&1
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled" `
        -Type REG_DWORD -Data "0"
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabledDefault" `
        -Type REG_DWORD -Data "0"

    Write-Host "  [*] Disabling lock option..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" `
        -Name "ShowLockOption" -Type REG_DWORD -Data "0"

    Write-Host "  [*] Disabling sleep option..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" `
        -Name "ShowSleepOption" -Type REG_DWORD -Data "0"

    Write-Host "  [*] Disabling fast boot..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" `
        -Type REG_DWORD -Data "0"

    Write-Host "  [*] Disabling power throttling..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" `
        -Type REG_DWORD -Data "1"

    Write-Host "  [*] Enabling USB overclock compatibility..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy" -Name "WHQLSettings" `
        -Type REG_DWORD -Data "1"

    Write-Host "  [*] Disabling raw mouse throttling..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKCU\Control Panel\Mouse" -Name "RawMouseThrottleEnabled" -Type REG_DWORD -Data "0"

    Write-Host "  [*] Optimizing network adapter..." -ForegroundColor Gray
    Disable-NetAdapterBinding -Name "*" -ComponentID ms_server -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "Performance settings applied." -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: Some settings require a system restart to take effect." -ForegroundColor Yellow
}

function Restore-DefaultPerformanceSetting {
    <#
  .SYNOPSIS
      Restores default Windows performance settings
  #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Clear-Host
    Write-Host "Restoring Default Performance Settings..." -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  [*] Enabling hibernate..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled" `
        -Type REG_DWORD -Data "1"
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabledDefault" `
        -Type REG_DWORD -Data "1"

    Write-Host "  [*] Enabling lock option..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" `
        -Name "ShowLockOption" -Type REG_DWORD -Data "1"

    Write-Host "  [*] Enabling sleep option..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" `
        -Name "ShowSleepOption" -Type REG_DWORD -Data "1"

    Write-Host "  [*] Enabling fast boot..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" `
        -Type REG_DWORD -Data "1"

    Write-Host "  [*] Removing power throttling override..." -ForegroundColor Gray
    Remove-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff"

    Write-Host "  [*] Restoring USB settings..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy" -Name "WHQLSettings" `
        -Type REG_DWORD -Data "0"

    Write-Host "  [*] Re-enabling raw mouse throttling..." -ForegroundColor Gray
    Remove-RegistryValue -Path "HKCU\Control Panel\Mouse" -Name "RawMouseThrottleEnabled"

    Write-Host "  [*] Restoring network adapter..." -ForegroundColor Gray
    Enable-NetAdapterBinding -Name "*" -ComponentID ms_server -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "Default performance settings restored." -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: Some settings require a system restart to take effect." -ForegroundColor Yellow
}
#endregion


#region Explorer / Visual Effects Settings
function Set-ExplorerPerformanceSetting {
    <#
  .SYNOPSIS
      Trims Start menu ads/suggestions and reduces visual-effects overhead
  #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Clear-Host
    Write-Host "Applying Explorer / Visual Effects Settings..." -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  [*] Disabling Start menu ads and suggestions..." -ForegroundColor Gray
    $cdm = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    foreach ($name in 'SoftLandingEnabled', 'SystemPaneSuggestionsEnabled', 'SilentInstalledAppsEnabled',
        'RotatingLockScreenEnabled', 'RotatingLockScreenOverlayEnabled') {
        Set-RegistryValue -Path $cdm -Name $name -Type REG_DWORD -Data "0"
    }
    Set-RegistryValue -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" `
        -Name "DisableWindowsSpotlightFeatures" -Type REG_DWORD -Data "1"

    Write-Host "  [*] Reducing visual-effects overhead..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
        -Name "VisualFXSetting" -Type REG_DWORD -Data "3"
    Set-RegistryValue -Path "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -Name "TaskbarAnimations" -Type REG_DWORD -Data "0"
    Set-RegistryValue -Path "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -Name "ListviewShadow" -Type REG_DWORD -Data "0"
    Set-RegistryValue -Path "HKCU\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Type REG_SZ -Data "0"
    Set-RegistryValue -Path "HKCU\Control Panel\Desktop" -Name "MenuShowDelay" -Type REG_SZ -Data "0"

    Write-Host ""
    Write-Host "Explorer settings applied." -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: Some settings require signing out or a restart to take effect." -ForegroundColor Yellow
}

function Restore-DefaultExplorerSetting {
    <#
  .SYNOPSIS
      Restores default Start menu suggestions and visual-effects settings
  #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Clear-Host
    Write-Host "Restoring Default Explorer Settings..." -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  [*] Restoring Start menu suggestions..." -ForegroundColor Gray
    $cdm = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    foreach ($name in 'SoftLandingEnabled', 'SystemPaneSuggestionsEnabled', 'SilentInstalledAppsEnabled',
        'RotatingLockScreenEnabled', 'RotatingLockScreenOverlayEnabled') {
        Remove-RegistryValue -Path $cdm -Name $name
    }
    Remove-RegistryValue -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsSpotlightFeatures"

    Write-Host "  [*] Restoring visual effects..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
        -Name "VisualFXSetting" -Type REG_DWORD -Data "0"
    Remove-RegistryValue -Path "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations"
    Remove-RegistryValue -Path "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewShadow"
    Set-RegistryValue -Path "HKCU\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Type REG_SZ -Data "1"
    Set-RegistryValue -Path "HKCU\Control Panel\Desktop" -Name "MenuShowDelay" -Type REG_SZ -Data "400"

    Write-Host ""
    Write-Host "Default Explorer settings restored." -ForegroundColor Green
}
#endregion


#region Keyboard Shortcuts
function Disable-KeyboardShortcut {
    <#
  .SYNOPSIS
      Disables all keyboard shortcuts for gaming
  #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Clear-Host
    Write-Host "Keyboard Shortcuts: Off" -ForegroundColor Red
    Write-Host ""
    Write-Host "  - Disables all keyboard shortcuts" -ForegroundColor Red
    Write-Host "  - Prevents tabbing out of games" -ForegroundColor Red
    Write-Host "  - Cut/copy/paste will still function" -ForegroundColor Red
    Write-Host "  - ESC key rebound to =" -ForegroundColor Red
    Write-Host ""
    Wait-ForKeyPress
    Clear-Host

    if (-not $PSCmdlet.ShouldProcess('keyboard shortcuts and scancode map', 'Disable')) { return }

    Set-RegistryValue -Path "HKLM\SYSTEM\ControlSet001\Services\hidserv" -Name "Start" -Type REG_DWORD -Data "4"
    Set-RegistryValue -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
        -Name "NoWinKeys" -Type REG_DWORD -Data "1"
    Set-RegistryValue -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -Name "DisabledHotkeys" -Type REG_DWORD -Data "1"
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout" -Name "Scancode Map" `
        -Type REG_BINARY -Data "00000000000000000700000000005be000005ce000003800000038e00000010001000d0000000000"

    Clear-Host
    Write-Host "Keyboard shortcuts disabled." -ForegroundColor Green
}

function Enable-KeyboardShortcut {
    <#
  .SYNOPSIS
      Restores default keyboard shortcuts
  #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Clear-Host

    if (-not $PSCmdlet.ShouldProcess('keyboard shortcuts and scancode map', 'Enable')) { return }

    Set-RegistryValue -Path "HKLM\SYSTEM\ControlSet001\Services\hidserv" -Name "Start" -Type REG_DWORD -Data "3"
    Remove-RegistryValue -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoWinKeys"
    Remove-RegistryValue -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "DisabledHotkeys"
    Remove-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout" -Name "Scancode Map"

    Clear-Host
    Write-Host "Keyboard shortcuts restored to default." -ForegroundColor Green
}
#endregion


#region Security Hardening
function Set-SecurityHardening {
    <#
  .SYNOPSIS
      Applies network/credential security hardening tweaks
  .PARAMETER IncludeOptInExtra
      Also apply opt-in extras that trade compatibility for security:
      SMB AES-256 cipher preference and disabling default admin shares
  #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$IncludeOptInExtra
    )

    Clear-Host
    Write-Host "Applying Security Hardening..." -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  [*] Disabling SMB1..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" `
        -Type REG_DWORD -Data "0"

    Write-Host "  [*] Enforcing SMB signing..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\System\CurrentControlSet\Services\LanmanWorkstation\Parameters" `
        -Name "RequireSecuritySignature" -Type REG_DWORD -Data "1"
    Set-RegistryValue -Path "HKLM\System\CurrentControlSet\Services\LanmanWorkstation\Parameters" `
        -Name "EnableSecuritySignature" -Type REG_DWORD -Data "1"
    Set-RegistryValue -Path "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" `
        -Name "RequireSecuritySignature" -Type REG_DWORD -Data "1"
    Set-RegistryValue -Path "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" `
        -Name "EnableSecuritySignature" -Type REG_DWORD -Data "1"

    Write-Host "  [*] Disabling WPAD..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad" `
        -Name "WpadOverride" -Type REG_DWORD -Data "1"

    Write-Host "  [*] Disabling LLMNR..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\Software\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" `
        -Type REG_DWORD -Data "0"

    Write-Host "  [*] Disabling WDigest cleartext credential caching..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\System\CurrentControlSet\Control\SecurityProviders\Wdigest" `
        -Name "UseLogonCredential" -Type REG_DWORD -Data "0"

    if ($IncludeOptInExtra) {
        Write-Host "  [*] Preferring SMB AES-256 ciphers..." -ForegroundColor Gray
        Set-RegistryValue -Path "HKLM\System\CurrentControlSet\Services\LanmanWorkstation\Parameters" `
            -Name "CipherSuiteOrder" -Type REG_MULTI_SZ -Data "AES_256_GCM\0AES_256_CCM"
        Set-RegistryValue -Path "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" `
            -Name "CipherSuiteOrder" -Type REG_MULTI_SZ -Data "AES_256_GCM\0AES_256_CCM"

        Write-Host "  [*] Disabling default admin shares..." -ForegroundColor Gray
        Set-RegistryValue -Path "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" `
            -Name "AutoShareServer" -Type REG_DWORD -Data "0"
        Set-RegistryValue -Path "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" `
            -Name "AutoShareWks" -Type REG_DWORD -Data "0"
    }

    Write-Host ""
    Write-Host "Security hardening applied." -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: SMB1/signing changes require a restart to take effect." -ForegroundColor Yellow
}

function Restore-DefaultSecurityHardening {
    <#
  .SYNOPSIS
      Restores default network/credential security settings
  #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Clear-Host
    Write-Host "Restoring Default Security Settings..." -ForegroundColor Cyan
    Write-Host ""

    Remove-RegistryValue -Path "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1"
    Remove-RegistryValue -Path "HKLM\System\CurrentControlSet\Services\LanmanWorkstation\Parameters" `
        -Name "RequireSecuritySignature"
    Remove-RegistryValue -Path "HKLM\System\CurrentControlSet\Services\LanmanWorkstation\Parameters" `
        -Name "EnableSecuritySignature"
    Remove-RegistryValue -Path "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" `
        -Name "RequireSecuritySignature"
    Remove-RegistryValue -Path "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" `
        -Name "EnableSecuritySignature"
    Remove-RegistryValue -Path "HKLM\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad" `
        -Name "WpadOverride"
    Remove-RegistryValue -Path "HKLM\Software\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast"
    Remove-RegistryValue -Path "HKLM\System\CurrentControlSet\Control\SecurityProviders\Wdigest" `
        -Name "UseLogonCredential"
    Remove-RegistryValue -Path "HKLM\System\CurrentControlSet\Services\LanmanWorkstation\Parameters" `
        -Name "CipherSuiteOrder"
    Remove-RegistryValue -Path "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" `
        -Name "CipherSuiteOrder"
    Remove-RegistryValue -Path "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" -Name "AutoShareServer"
    Remove-RegistryValue -Path "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" -Name "AutoShareWks"

    Write-Host ""
    Write-Host "Default security settings restored." -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: Some settings require a restart to take effect." -ForegroundColor Yellow
}
#endregion


#region System Tweaks
function Set-SystemTweak {
    <#
  .SYNOPSIS
      Applies miscellaneous QoL and Windows 11 feature tweaks
  #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Clear-Host
    Write-Host "Applying System Tweaks..." -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  [*] Disabling reserved storage..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" `
        -Name "ShippedWithReserves" -Type REG_DWORD -Data "0"

    Write-Host "  [*] Enabling full powerdown after shutdown..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" `
        -Name "PowerdownAfterShutdown" -Type REG_DWORD -Data "1"

    Write-Host "  [*] Enabling NumLock on startup..." -ForegroundColor Gray
    Set-RegistryValue -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" -Name "InitialKeyboardIndicators" `
        -Type REG_SZ -Data "2147483650"

    Write-Host "  [*] Disabling drive autorun..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
        -Name "NoDriveTypeAutoRun" -Type REG_DWORD -Data "255"

    Write-Host "  [*] Skipping app relaunch after update reboot..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "RestartApps" `
        -Type REG_DWORD -Data "0"

    Write-Host "  [*] Fixing multi-monitor cursor deadzone jumping..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKCU\Control Panel\Cursors" -Name "CursorDeadzoneJumpingSetting" `
        -Type REG_DWORD -Data "0"

    Write-Host "  [*] Enabling scroll-inactive-window-under-cursor..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKCU\Control Panel\Desktop" -Name "MouseWheelRouting" -Type REG_DWORD -Data "0"

    $osVersion = [Environment]::OSVersion.Version
    if ($osVersion.Major -eq 10 -and $osVersion.Build -ge 26100) {
        Write-Host "  [*] Enabling Windows 11 sudo command..." -ForegroundColor Gray
        Set-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo" -Name "Enabled" `
            -Type REG_DWORD -Data "1"
    } else {
        Write-Verbose "Skipping sudo enable: requires Windows 11 24H2 (build 26100) or later"
    }

    Write-Host ""
    Write-Host "System tweaks applied." -ForegroundColor Green
}

function Restore-DefaultSystemTweak {
    <#
  .SYNOPSIS
      Restores default values for the miscellaneous system tweaks
  #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Clear-Host
    Write-Host "Restoring Default System Tweaks..." -ForegroundColor Cyan
    Write-Host ""

    Remove-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" -Name "ShippedWithReserves"
    Remove-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "PowerdownAfterShutdown"
    Remove-RegistryValue -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" -Name "InitialKeyboardIndicators"
    Remove-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun"
    Remove-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "RestartApps"
    Remove-RegistryValue -Path "HKCU\Control Panel\Cursors" -Name "CursorDeadzoneJumpingSetting"
    Remove-RegistryValue -Path "HKCU\Control Panel\Desktop" -Name "MouseWheelRouting"
    Remove-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo" -Name "Enabled"

    Write-Host ""
    Write-Host "Default system tweaks restored." -ForegroundColor Green
}
#endregion


#region NVIDIA GPU Settings
function Set-P0State {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Value)

    if ($PSCmdlet.ShouldProcess("NVIDIA GPU registry", "Set DisableDynamicPstate = $Value")) {
        $null = Set-NvidiaGpuRegistryValue -Name "DisableDynamicPstate" -Type REG_DWORD -Data $Value
    }

    Clear-Host
    Show-NvidiaGpuSetting -Setting "P0State"
}

function Set-HDCP {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Value)

    if ($PSCmdlet.ShouldProcess("NVIDIA GPU registry", "Set RMHdcpKeyglobZero = $Value")) {
        $null = Set-NvidiaGpuRegistryValue -Name "RMHdcpKeyglobZero" -Type REG_DWORD -Data $Value
    }

    Clear-Host
    Show-NvidiaGpuSetting -Setting "HDCP"
}
#endregion


#region Menu System
function Show-PerformanceMenu {
    [CmdletBinding()]
    param()
    Show-Menu -Title "Performance Optimizations" -Options @(
        "Apply Performance Optimizations"
        "Restore Default Settings"
        "Back to Main Menu"
    )

    $choice = Get-MenuChoice -Min 1 -Max 3

    switch ($choice) {
        1 {
            Set-PerformanceSetting
            Wait-ForKeyPress -Message "Press Enter to continue..." -UseReadHost
        }
        2 {
            Restore-DefaultPerformanceSetting
            Wait-ForKeyPress -Message "Press Enter to continue..." -UseReadHost
        }
        3 { return }
    }
}

function Show-KeyboardMenu {
    [CmdletBinding()]
    param()
    Show-Menu -Title "Keyboard Shortcuts" -Options @(
        "Keyboard Shortcuts: Off"
        "Keyboard Shortcuts: Default"
        "Back to Main Menu"
    )

    $choice = Get-MenuChoice -Min 1 -Max 3

    switch ($choice) {
        1 {
            Disable-KeyboardShortcut
            Write-Host ""
            Show-RestartRequired
        }
        2 {
            Enable-KeyboardShortcut
            Write-Host ""
            Show-RestartRequired
        }
        3 { return }
    }
}

function Show-NvidiaMenu {
    [CmdletBinding()]
    param()
    while ($true) {
        $sigStatus = Get-NvidiaSignatureStatus
        $isSigEnabled = $sigStatus.GlobalOverride -and $sigStatus.ServiceOverride

        Show-Menu -Title "NVIDIA GPU Settings" -Options @(
            "P0 State (Highest Performance): On"
            "P0 State (Highest Performance): Default"
            "HDCP (Content Protection): Off"
            "HDCP (Content Protection): Default"
            "Driver Signature Override: $(if ($isSigEnabled) { 'Enabled' } else { 'Disabled' })"
            "XtremeG Custom Driver Installer"
            "View Current Settings"
            "Back to Main Menu"
        )

        $choice = Get-MenuChoice -Min 1 -Max 8

        switch ($choice) {
            1 { Set-P0State -Value "1"; Show-RestartRequired }
            2 { Set-P0State -Value "0"; Show-RestartRequired }
            3 { Set-HDCP -Value "1"; Show-RestartRequired }
            4 { Set-HDCP -Value "0"; Show-RestartRequired }
            5 {
                Set-NvidiaSignatureOverride -Enabled (-not $isSigEnabled)
                Show-RestartRequired
            }
            6 {
                $installerPath = "$PSScriptRoot\..\user\.dotfiles\config\nvidia\xtremeg-installer.ps1"
                if (Test-Path -Path $installerPath) {
                    $psArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$installerPath`""
                    Start-Process -FilePath powershell.exe -ArgumentList $psArgs -Verb RunAs
                }
                else {
                    Write-Warning "XtremeG Installer not found at: $installerPath"
                    Wait-ForKeyPress
                }
            }
            7 {
                Clear-Host
                Show-NvidiaGpuSetting
                $gStatus = if ($sigStatus.GlobalOverride) { 'Enabled' } else { 'Disabled' }
                $sStatus = if ($sigStatus.ServiceOverride) { 'Enabled' } else { 'Disabled' }
                Write-Host "Driver Signature Override - Global: $gStatus  Service: $sStatus" -ForegroundColor Cyan
                Wait-ForKeyPress -Message "Press any key to continue..." -UseReadHost
            }
            8 { return }
        }
    }
}

function Show-MSIMenu {
    [CmdletBinding()]
    param()
    Show-Menu -Title "MSI Mode Configuration" -Options @(
        "MSI Mode: On (Recommended)"
        "MSI Mode: Off"
        "Back to Main Menu"
    )

    $choice = Get-MenuChoice -Min 1 -Max 3

    switch ($choice) {
        1 { Set-MSIMode -Enable $true; Write-Host ""; Show-RestartRequired }
        2 { Set-MSIMode -Enable $false; Write-Host ""; Show-RestartRequired }
        3 { return }
    }
}

function Show-EDIDMenu {
    [CmdletBinding()]
    param()
    while ($true) {
        Show-Menu -Title "EDID Override Manager" -Options @(
            "Apply EDID Override (Fix stuttering)"
            "Remove EDID Override"
            "View Current Status"
            "Back to Main Menu"
        )

        $choice = Get-MenuChoice -Min 1 -Max 4
        Clear-Host

        switch ($choice) {
            1 { Set-EDIDOverride; Write-Host ""; Show-RestartRequired }
            2 { Remove-EDIDOverride; Write-Host ""; Show-RestartRequired }
            3 { Show-EDIDStatus; Wait-ForKeyPress -Message "Press Enter to continue..." -UseReadHost }
            4 { return }
        }
    }
}

function Show-GamingDisplayMenu {
    [CmdletBinding()]
    param()
    while ($true) {
        Show-Menu -Title "Gaming Display Optimizations" -Options @(
            "Fullscreen Optimizations: FSO (Default)"
            "Fullscreen Exclusive: FSE"
            "Multiplane Overlay: On"
            "Multiplane Overlay: Off"
            "Multiplane Overlay: Default"
            "View Current Settings"
            "Back to Main Menu"
        )

        $choice = Get-MenuChoice -Min 1 -Max 7

        switch ($choice) {
            1 { Set-FullscreenMode -Mode 'FSO'; Write-Host ""; Wait-ForKeyPress -Message "Press any key to continue..." }
            2 { Set-FullscreenMode -Mode 'FSE'; Write-Host ""; Wait-ForKeyPress -Message "Press any key to continue..." }
            3 { Set-MultiPlaneOverlay -Mode 'Enabled'; Write-Host ""; Show-RestartRequired }
            4 { Set-MultiPlaneOverlay -Mode 'Disabled'; Write-Host ""; Show-RestartRequired }
            5 { Set-MultiPlaneOverlay -Mode 'Default'; Write-Host ""; Show-RestartRequired }
            6 { Show-GamingDisplayStatus; Wait-ForKeyPress -Message "Press any key to continue..." }
            7 { return }
        }
    }
}

function Show-SecurityMenu {
    [CmdletBinding()]
    param()
    Show-Menu -Title "Security Hardening" -Options @(
        "Apply Security Hardening"
        "Apply Security Hardening (incl. opt-in SMB extras)"
        "Restore Default Settings"
        "Back to Main Menu"
    )

    $choice = Get-MenuChoice -Min 1 -Max 4

    switch ($choice) {
        1 {
            Set-SecurityHardening
            Wait-ForKeyPress -Message "Press Enter to continue..." -UseReadHost
        }
        2 {
            Set-SecurityHardening -IncludeOptInExtra
            Wait-ForKeyPress -Message "Press Enter to continue..." -UseReadHost
        }
        3 {
            Restore-DefaultSecurityHardening
            Wait-ForKeyPress -Message "Press Enter to continue..." -UseReadHost
        }
        4 { return }
    }
}

function Show-SystemTweaksMenu {
    [CmdletBinding()]
    param()
    Show-Menu -Title "System Tweaks" -Options @(
        "Apply System Tweaks"
        "Restore Default Settings"
        "Back to Main Menu"
    )

    $choice = Get-MenuChoice -Min 1 -Max 3

    switch ($choice) {
        1 {
            Set-SystemTweak
            Wait-ForKeyPress -Message "Press Enter to continue..." -UseReadHost
        }
        2 {
            Restore-DefaultSystemTweak
            Wait-ForKeyPress -Message "Press Enter to continue..." -UseReadHost
        }
        3 { return }
    }
}

function Show-ExplorerMenu {
    [CmdletBinding()]
    param()
    Show-Menu -Title "Explorer / Visual Effects" -Options @(
        "Apply Explorer Optimizations"
        "Restore Default Settings"
        "Back to Main Menu"
    )

    $choice = Get-MenuChoice -Min 1 -Max 3

    switch ($choice) {
        1 {
            Set-ExplorerPerformanceSetting
            Wait-ForKeyPress -Message "Press Enter to continue..." -UseReadHost
        }
        2 {
            Restore-DefaultExplorerSetting
            Wait-ForKeyPress -Message "Press Enter to continue..." -UseReadHost
        }
        3 { return }
    }
}

function Show-MainMenu {
    [CmdletBinding()]
    param()
    Show-Menu -Title "System Settings Manager - Select Category" -Options @(
        "Performance Optimizations"
        "Keyboard Shortcuts"
        "NVIDIA GPU Settings"
        "MSI Mode Configuration"
        "EDID Override Manager"
        "Gaming Display Optimizations"
        "Security Hardening"
        "System Tweaks"
        "Explorer / Visual Effects"
        "Exit"
    )
}
#endregion


function Start-SystemSettingsManager {
    [CmdletBinding()]
    param()

    Request-AdminElevation
    Initialize-ConsoleUI -Title "System Settings Manager (Administrator)"

    while ($true) {
        Show-MainMenu
        $choice = Get-MenuChoice -Min 1 -Max 10

        switch ($choice) {
            1 { Show-PerformanceMenu }
            2 { Show-KeyboardMenu }
            3 { Show-NvidiaMenu }
            4 { Show-MSIMenu }
            5 { Show-EDIDMenu }
            6 { Show-GamingDisplayMenu }
            7 { Show-SecurityMenu }
            8 { Show-SystemTweaksMenu }
            9 { Show-ExplorerMenu }
            10 { exit }
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-SystemSettingsManager
}
