@echo off
::Check Administrator Privileges
dism >nul 2>&1 || (echo ^<Run the Script in Administrator^> && pause>nul && cls&exit)
echo info: del to context-menu
reg delete "HKCR\Directory\Background\shell\nvcpl" /f
pause

