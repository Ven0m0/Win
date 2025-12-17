set Msi=%PROGRAMFILES(X86)%\MSI Afterburner
cd /d %Msi%
xcopy "%Msi%\Skins\MSIMystic.usf" "%Msi%\MSIMystic.usf" /Y /Q /i
xcopy "%Msi%\Skins\MSIWin11Dark.usf" "%Msi%\MSIWin11Dark.usf" /Y /Q /i
xcopy "%Msi%\Skins\defaultX.uxf" "%Msi%" /Y /Q /i
rmdir /s /q "Skins"
mkdir "Skins"
move /y "%Msi%\MSIMystic.usf" "Skins"
cd /d %Msi%
move /y %Msi%\defaultX.uxf" "Skins"
cd /d %Msi%
move /y %Msi%\MSIWin11Dark.usf" "Skins"
cd /d %Msi%
rmdir /s /q "Localization"
rmdir /s /q "Doc"
rmdir /s /q "SDK/Doc"
rmdir /s /q "%Appdata%\Microsoft\Windows\Start Menu\Programs\MSI Afterburner\SDK"
del /F /Q "%Appdata%\Microsoft\Windows\Start Menu\Programs\MSI Afterburner\ReadMe.lnk"
pause