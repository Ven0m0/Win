If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit
}

$Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + " (Administrator)"
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.PrivateData.ProgressBackgroundColor = "Black"
$Host.PrivateData.ProgressForegroundColor = "White"
Clear-Host

Write-Host "1. MSI Mode: On (Recommended)"
Write-Host "2. MSI Mode: Off"

while ($true) {
    $choice = Read-Host " "
    if ($choice -match '^[1-2]$') {
        switch ($choice) {
            1 { $msiValue = "1"; break }
            2 { $msiValue = "0"; break }
        }

        Clear-Host

        # Get all GPU driver IDs
        $gpuDevices = Get-PnpDevice -Class Display

        # Set MSI mode for all GPUs
        foreach ($gpu in $gpuDevices) {
            $instanceID = $gpu.InstanceId
            $regPath = "HKLM\SYSTEM\ControlSet001\Enum\$instanceID\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            $null = reg add $regPath /v "MSISupported" /t REG_DWORD /d $msiValue /f 2>&1
        }

        # Display MSI mode status for all GPUs
        Write-Host "MSI Mode Status:" -ForegroundColor Cyan
        Write-Host ""
        foreach ($gpu in $gpuDevices) {
            $instanceID = $gpu.InstanceId
            $regPath = "Registry::HKLM\SYSTEM\ControlSet001\Enum\$instanceID\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            try {
                $msiSupported = Get-ItemProperty -Path $regPath -Name "MSISupported" -ErrorAction Stop
                Write-Host "$instanceID" -ForegroundColor Yellow
                Write-Host "MSISupported: $($msiSupported.MSISupported)" -ForegroundColor Green
            }
            catch {
                Write-Host "$instanceID" -ForegroundColor Yellow
                Write-Host "MSISupported: Not found or error accessing the registry." -ForegroundColor Red
            }
            Write-Host ""
        }

        Write-Host "Restart to apply changes..." -ForegroundColor Cyan
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
    else {
        Write-Host "Invalid input. Please select a valid option (1-2)." -ForegroundColor Red
    }
}
