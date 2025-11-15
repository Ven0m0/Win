If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit
}

$Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + " (Administrator)"
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.PrivateData.ProgressBackgroundColor = "Black"
$Host.PrivateData.ProgressForegroundColor = "White"
Clear-Host

Write-Host "1. Network Adapter: Only Allow IPv4"
Write-Host "2. Network Adapter: Default"

while ($true) {
    $choice = Read-Host " "
    if ($choice -match '^[1-2]$') {
        switch ($choice) {
            1 {
                Clear-Host

                # Disable hibernate
                powercfg /hibernate off
                $null = reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "HibernateEnabled" /t REG_DWORD /d "0" /f 2>&1
                $null = reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "HibernateEnabledDefault" /t REG_DWORD /d "0" /f 2>&1

                # Disable lock
                $null = reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" /v "ShowLockOption" /t REG_DWORD /d "0" /f 2>&1

                # Disable sleep
                $null = reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" /v "ShowSleepOption" /t REG_DWORD /d "0" /f 2>&1

                # Disable fast boot
                $null = reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v "HiberbootEnabled" /t REG_DWORD /d "0" /f 2>&1

                # Disable power throttling
                $null = reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" /v "PowerThrottlingOff" /t REG_DWORD /d "1" /f 2>&1

                # USB overclock with secure boot
                $null = reg add "HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy" /v "WHQLSettings" /t REG_DWORD /d "1" /f 2>&1

                # Disable raw mouse throttling
                $null = reg add "HKCU\Control Panel\Mouse" /v "RawMouseThrottleEnabled" /t REG_DWORD /d "0" /f 2>&1

                Write-Host "Network Adapter" -ForegroundColor Cyan
                $ProgressPreference = 'SilentlyContinue'
                Disable-NetAdapterBinding -Name "*" -ComponentID ms_server -ErrorAction SilentlyContinue

                Write-Host "Settings applied successfully!" -ForegroundColor Green
                exit
            }
        }
    }
    else {
        Write-Host "Invalid input. Please select a valid option (1-2)." -ForegroundColor Red
    }
}
