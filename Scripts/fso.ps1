If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit
}

$Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + " (Administrator)"
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.PrivateData.ProgressBackgroundColor = "Black"
$Host.PrivateData.ProgressForegroundColor = "White"
Clear-Host

Write-Host "Fullscreen Mode Selection:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Fullscreen Optimizations: FSO (Default)"
Write-Host "2. Fullscreen Exclusive: FSE"
Write-Host ""

while ($true) {
    $choice = Read-Host "Select option (1-2)"
    if ($choice -match '^[1-2]$') {
        Clear-Host

        switch ($choice) {
            1 {
                # Fullscreen optimizations (FSO)
                $null = reg add "HKCU\System\GameConfigStore" /v "GameDVR_DXGIHonorFSEWindowsCompatible" /t REG_DWORD /d "0" /f 2>&1
                $null = reg add "HKCU\System\GameConfigStore" /v "GameDVR_FSEBehaviorMode" /t REG_DWORD /d "0" /f 2>&1
                $null = reg delete "HKCU\System\GameConfigStore" /v "GameDVR_FSEBehavior" /f 2>&1
                $null = reg add "HKCU\System\GameConfigStore" /v "GameDVR_HonorUserFSEBehaviorMode" /t REG_DWORD /d "0" /f 2>&1

                Write-Host "Fullscreen Optimizations (FSO) enabled." -ForegroundColor Green
            }
            2 {
                # Fullscreen exclusive (FSE)
                $null = reg add "HKCU\System\GameConfigStore" /v "GameDVR_DXGIHonorFSEWindowsCompatible" /t REG_DWORD /d "1" /f 2>&1
                $null = reg add "HKCU\System\GameConfigStore" /v "GameDVR_FSEBehaviorMode" /t REG_DWORD /d "2" /f 2>&1
                $null = reg add "HKCU\System\GameConfigStore" /v "GameDVR_FSEBehavior" /t REG_DWORD /d "2" /f 2>&1
                $null = reg add "HKCU\System\GameConfigStore" /v "GameDVR_HonorUserFSEBehaviorMode" /t REG_DWORD /d "1" /f 2>&1

                Write-Host "Fullscreen Exclusive (FSE) enabled." -ForegroundColor Green
                Write-Host ""
                Write-Host "Additional steps may be required:" -ForegroundColor Yellow
                Write-Host "  1. Right-click game.exe"
                Write-Host "  2. Select Properties"
                Write-Host "  3. Go to Compatibility tab"
                Write-Host "  4. Check 'Disable fullscreen optimizations'"
                Write-Host "  5. Click Apply"
                Write-Host ""
                Write-Host "Note: DX12 engines do not support fullscreen exclusive mode." -ForegroundColor Cyan
            }
        }

        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Cyan
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
    else {
        Write-Host "Invalid input. Please select a valid option (1-2)." -ForegroundColor Red
    }
}
