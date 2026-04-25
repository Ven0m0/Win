#!/usr/bin/env pwsh
﻿#Requires -Version 5.1
#Requires -RunAsAdministrator

winget install --id Git.Git --source winget -h
winget install --id Microsoft.PowerShell --source winget -h
winget install -h Microsoft.WindowsTerminal Microsoft.AppInstaller
winget install -h Chocolatey.Chocolatey topgrade-rs.topgrade OpenJS.NodeJS Schniz.fnm Oven-sh.Bun Python.Python.3.13 astral-sh.uv jdx.mise
winget install -h Microsoft.DirectX Gyan.FFmpeg aria2.aria2 7zip.7zip KhronosGroup.VulkanRT Microsoft.OpenCLGLVulkanCompatibilityPack

winget install -h abbodi1406.vcredist Microsoft.VCLibs.14 Microsoft.VCLibs.Desktop.14 Microsoft.WindowsAppRuntime.1.8
winget install -h Microsoft.DotNet.Framework.Runtime Microsoft.DotNet.DesktopRuntime.5 Microsoft.DotNet.DesktopRuntime.6 Microsoft.DotNet.DesktopRuntime.7 Microsoft.DotNet.DesktopRuntime.8 Microsoft.DotNet.DesktopRuntime.9 Microsoft.DotNet.DesktopRuntime.10

winget install -h Oracle.JavaRuntimeEnvironment EclipseAdoptium.Temurin.25.JRE

scoop config aria2-enabled true

dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
dism /online /enable-feature /featurename:LegacyComponents /all /norestart
dism /online /enable-feature /featurename:DirectPlay /all /norestart

Install-Module PSWindowsUpdate
Import-Module PSWindowsUpdate
Install-WindowsUpdate -AcceptAll

schtasks /create /tn "post-reboot" /sc onlogon /rl highest /tr "powershell -ExecutionPolicy Bypass -File C:\setup\stage2.ps1"

topgrade -y

sfc /scannow; dism /online /cleanup-image /restoreHealth
shutdown /r /t 0
