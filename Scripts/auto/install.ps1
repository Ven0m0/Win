

winget install --id Git.Git -e --silent


scoop install aria2
scoop config aria2-enabled true

dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

schtasks /create /tn "post-reboot" /sc onlogon /rl highest /tr "powershell -ExecutionPolicy Bypass -File C:\setup\stage2.ps1"

shutdown /r /t 0
