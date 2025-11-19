@echo off
::Check Administrator Privileges
dism >nul 2>&1 || (echo ^<Run the Script in Administrator^> && pause>nul && cls&exit)
echo info: add to context-menu
reg add "HKCR\Directory\Background\shell\nvcpl" /v "MUIVerb" /t reg_sz /d "Nvidia Control Panel (Portable)" /f >nul
reg add "HKCR\Directory\Background\shell\nvcpl" /v "Icon" /t reg_sz /d "%~dp0nvcpl.exe,6" /f >nul
reg add "HKCR\Directory\Background\shell\nvcpl\command" /ve /d "\"C:\Windows\System32\WScript.exe\" \"%~dp0Nvidia Control Panel.vbs\"" /f >nul
pause

