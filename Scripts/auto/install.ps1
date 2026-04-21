#!/usr/bin/env pwsh
﻿#Requires -Version 5.1
#Requires -RunAsAdministrator

winget install --id Git.Git -e -h
winget insatall -h abbodi1406.vcredist 
winget install -h Microsoft.DotNet.Framework.Runtime Microsoft.DotNet.DesktopRuntime.5 Microsoft.DotNet.DesktopRuntime.6 Microsoft.DotNet.DesktopRuntime.7 Microsoft.DotNet.DesktopRuntime.8 Microsoft.DotNet.DesktopRuntime.9 \
  Microsoft.DotNet.DesktopRuntime.10

scoop install aria2
scoop config aria2-enabled true

dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

schtasks /create /tn "post-reboot" /sc onlogon /rl highest /tr "powershell -ExecutionPolicy Bypass -File C:\setup\stage2.ps1"


sfc /scannow; dism /online /cleanup-image /restoreHealth
shutdown /r /t 0
