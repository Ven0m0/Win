@echo off
cd /d %~dp0
for %%a in (*.mp4) do (
  ffzap -t 4 --overwrite --eta -i "%%a" -f "-c:v libsvtav1 -preset 1 -b:v 4000k ^
    -svtav1-params 'tbr=4000:tune=0:film-grain=8:enable-variance-boost=1:tile-columns=0:tile-rows=0:scd=1:film-grain=8' ^
    -c:a libopus -compression_level 10 -b:a 64k -vbr on" ^
    -o "%%~na.mkv"
)
pause
