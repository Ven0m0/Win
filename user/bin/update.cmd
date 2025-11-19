@echo off
cd /d %~dp0

winget upgrade -h -r -u --accept-package-agreements --accept-source-agreements  --include-unknown --force --purge --disable-interactivity --nowarn --no-proxy
scoop update -a
choco upgrade all -y
pip freeze > requirements.txt
pip install -r requirements.txt --upgrade
exit
