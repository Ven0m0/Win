cd /d %~dp0
del /f /q "DeviceCleanup.exe"
del /f /q "DeviceCleanup.txt"
del /f /q "DriveCleanup.exe"
del /f /q "DriveCleanup.txt"
curl -L --output DeviceCleanup.zip https://www.uwe-sieber.de/files/DeviceCleanup_x64.zip
curl -L --output DriveCleanup.zip https://www.uwe-sieber.de/files/DriveCleanup.zip
timeout /t 1
tar -xf DeviceCleanup.zip
timeout /t 1
del /f /q "DeviceCleanup.zip"
del /f /q "DeviceCleanup.txt"
tar -xf DriveCleanup.zip
timeout /t 1
rmdir /s /q Win32
move /y "%~dp0x64\*" "%~dp0"
rmdir /s /q x64
del /f /q "DriveCleanup.zip"
del /f /q "DriveCleanup.txt"
exit