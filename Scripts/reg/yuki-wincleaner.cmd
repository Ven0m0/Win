@echo off
color 0e
:: Remove all temporary files.
del /f /s /q %tmp%\*.*
del /f /s /q %temp%\*.*
del /f /s /q %systemdrive%\*.tmp
del /f /s /q %systemdrive%\*._mp
del /f /s /q %windir%\temp\*.*
del /f /s /q %AppData%\temp\*.*
del /f /s /q %HomePath%\AppData\LocalLow\Temp\*.*

:: Remove log, trace, old and backup files.
del /f /s /q %systemdrive%\*.log
del /f /s /q %systemdrive%\*.old
del /f /s /q C:\*.old
del /f /s /q %systemdrive%\*.trace
del /f /s /q %windir%\*.bak

:: Remove restored files created by an checkdisk utility.
del /f /s /q %systemdrive%\*.chk

:: Remove old content from recycle bin.
del /f /s /q %systemdrive%\recycled\*.*

:: Remove powercfg energy report.
del /f /s /q %windir%\system32\energy-report.html

:: Remove extracted, not needed files of driver installators.
del /f /s /q %systemdrive%\AMD\*.*
del /f /s /q %systemdrive%\NVIDIA\*.*
del /f /s /q %systemdrive%\INTEL\*.*

:: Remove files of already downloaded windows updates.
del /f /s /q %windir%\SoftwareDistribution\Download
DISM /CleanUp-Wim
Dism /Cleanup-Mountpoints
:: Remove event logs.
wevtutil.exe cl Application
wevtutil.exe cl System
exit