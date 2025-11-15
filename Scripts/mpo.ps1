If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit
}

$Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + " (Administrator)"
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.PrivateData.ProgressBackgroundColor = "Black"
$Host.PrivateData.ProgressForegroundColor = "White"
Clear-Host

Write-Host "Multiplane Overlay & Optimizations For Windowed Games:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. On"
Write-Host "2. Off"
Write-Host "3. Default"
Write-Host ""

while ($true) {
    $choice = Read-Host "Select option (1-3)"
    if ($choice -match '^[1-3]$') {
        Clear-Host

        switch ($choice) {
            1 {
                # Enable multiplane overlay
                $null = reg delete "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v "OverlayTestMode" /f 2>&1

                # Enable optimizations for windowed games
                $null = reg add "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" /v "DirectXUserGlobalSettings" /t REG_SZ /d "VRROptimizeEnable=0;SwapEffectUpgradeEnable=1;" /f 2>&1

                Write-Host "Multiplane Overlay: Enabled" -ForegroundColor Green
                Write-Host "Windowed Game Optimizations: Enabled" -ForegroundColor Green
            }
            2 {
                # Disable multiplane overlay
                $null = reg add "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v "OverlayTestMode" /t REG_DWORD /d "5" /f 2>&1

                # Disable optimizations for windowed games
                $null = reg add "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" /v "DirectXUserGlobalSettings" /t REG_SZ /d "VRROptimizeEnable=0;SwapEffectUpgradeEnable=0;" /f 2>&1

                Write-Host "Multiplane Overlay: Disabled" -ForegroundColor Yellow
                Write-Host "Windowed Game Optimizations: Disabled" -ForegroundColor Yellow
            }
            3 {
                # Enable multiplane overlay (default)
                $null = reg delete "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v "OverlayTestMode" /f 2>&1

                # Disable optimizations for windowed games
                $null = reg add "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" /v "DirectXUserGlobalSettings" /t REG_SZ /d "VRROptimizeEnable=0;SwapEffectUpgradeEnable=0;" /f 2>&1

                Write-Host "Multiplane Overlay: Default (Enabled)" -ForegroundColor Cyan
                Write-Host "Windowed Game Optimizations: Disabled" -ForegroundColor Cyan
            }
        }

        Write-Host ""
        Write-Host "Restart to apply changes..." -ForegroundColor Cyan
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
    else {
        Write-Host "Invalid input. Please select a valid option (1-3)." -ForegroundColor Red
    }
}
