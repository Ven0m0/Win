#!/usr/bin/env pwsh
﻿#Requires -Version 5.1
#Requires -RunAsAdministrator

wsl --install -d Ubuntu
wsl --set-default-version 2
winget install Microsoft.WSL Canonical.Ubuntu Bostrot.WSLManager
