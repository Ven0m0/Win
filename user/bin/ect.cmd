@echo off

cd /d %~dp0
ect.exe -9 -strip -progressive --strict --allfilters-c -recurse --pal_sort=30 %userprofile%\Pictures
pause
