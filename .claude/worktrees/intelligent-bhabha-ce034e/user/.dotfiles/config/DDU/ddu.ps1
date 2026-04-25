

reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\DriverSearching" /v "SearchOrderConfig" /t REG_DWORD /d "0" /f | Out-Null
# toggle safe mode
cmd /c "bcdedit /set {current} safeboot minimal >nul 2>&1"
# restart
shutdown -r -t 00
