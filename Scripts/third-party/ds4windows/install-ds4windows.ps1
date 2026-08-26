#Requires -Version 5.1

<#
.SYNOPSIS
    Installs DS4Windows, with Desktop/Start Menu/Startup shortcuts.
.DESCRIPTION
    DS4Windows has no winget package. Resolves the latest official binary
    release from GitHub (ds4windowsapp/DS4Windows), downloads and extracts
    it to the user's Documents folder, then creates a shortcut to
    DS4Windows.exe on the Desktop, in the Start Menu, and in the Startup
    folder.
.EXAMPLE
    Scripts\ds4windows\install-ds4windows.ps1
#>

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\Common.ps1')

Install-GitHubRelease -Repository 'ds4windowsapp/DS4Windows' `
    -AssetPattern 'DS4Windows.*.zip' `
    -Name 'DS4Windows' `
    -InstallType Zip `
    -DestinationPath "$([Environment]::GetFolderPath('MyDocuments'))\DS4Windows" `
    -ExecutableName 'win-x64\DS4Windows.exe' `
    -ShortcutName 'DS4Windows'
