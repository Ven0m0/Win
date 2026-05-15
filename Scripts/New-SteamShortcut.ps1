#Requires -Version 5.1

<#
.SYNOPSIS
    Creates an optimized Steam desktop shortcut
.DESCRIPTION
    Creates a Steam shortcut with performance-focused launch arguments to reduce
    resource usage. Arguments disable friends UI, intro videos, Big Picture, and CEF features.
.PARAMETER SteamPath
    Custom Steam installation path. If not provided, auto-detected from registry.
.PARAMETER ShortcutName
    Name for the shortcut (default: "Steam (Optimized)")
.PARAMETER Desktop
    Create shortcut on desktop (default: true)
.PARAMETER DryRun
    Show what would be created without making changes
.EXAMPLE
    .\New-SteamShortcut.ps1
.EXAMPLE
    .\New-SteamShortcut.ps1 -ShortcutName "Steam Gaming" -DryRun
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SteamPath,
    [string]$ShortcutName = 'Steam (Optimized)',
    [switch]$Desktop = $true,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

function Get-SteamPath {
    if ($SteamPath) { return $SteamPath }
    try {
        $regPath = Get-ItemProperty 'HKLM:\Software\Wow6432Node\Valve\Steam' `
          -Name InstallPath -ErrorAction SilentlyContinue
        if ($regPath) { return $regPath.InstallPath }
    } catch { Write-Verbose "HKLM Steam lookup failed: $_" }
    try {
        $regPath = Get-ItemProperty 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction SilentlyContinue
        if ($regPath) { return $regPath.SteamPath }
    } catch { Write-Verbose "HKCU Steam lookup failed: $_" }
    return "${env:ProgramFiles(x86)}\Steam"
}

function New-Shortcut {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ShortcutPath,
        [string]$TargetPath,
        [string]$Arguments,
        [string]$Description,
        [string]$WorkingDirectory
    )

    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $TargetPath
    $Shortcut.Arguments = $Arguments
    $Shortcut.Description = $Description
    $Shortcut.WorkingDirectory = $WorkingDirectory
    $Shortcut.Save()
}

$steamPath = Get-SteamPath
$steamExe = Join-Path $steamPath "Steam.exe"

if (-not (Test-Path $steamExe)) {
    Write-Warning "Steam not found at: $steamExe"
    Write-Warning "Please verify the path or specify manually with -SteamPath"
    exit 1
}

# Performance-focused launch arguments
# -nofriendsui: Hide friends list and chat
# -nointro: Skip Steam intro movies
# -nobigpicture: Don't launch in Big Picture mode
# -cef-single-process: Run CEF in single process (reduces memory)
# -cef-disable-breakpad: Disable crashpad (minor CPU saving)
# -cef-disable-gpu-compositing: Disable GPU compositing in CEF
# -cef-disable-gpu: Disable GPU acceleration in CEF
# -cef-disable-js-logging: Disable JavaScript console logging
# -noconsole: Don't show console window
# +open steam://open/minigameslist: Open in mini mode
$launchArgs = "-nofriendsui -nointro -nobigpicture -cef-single-process -cef-disable-breakpad" + `
  " -cef-disable-gpu-compositing -cef-disable-gpu -cef-disable-js-logging -noconsole" + `
  " +open steam://open/minigameslist"

Write-Host "Steam Shortcut Creator" -ForegroundColor Cyan
Write-Host "Steam path: $steamPath"
Write-Host "Shortcut name: $ShortcutName"
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY RUN] Shortcut would be created at:" -ForegroundColor Yellow
    if ($Desktop) {
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        Write-Host "  $desktopPath\$ShortcutName.lnk"
    }
    Write-Host ""
    Write-Host "Target: $steamExe"
    Write-Host "Arguments: $launchArgs"
    return
}

if ($Desktop) {
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktopPath "$ShortcutName.lnk"

    if ($PSCmdlet.ShouldProcess($shortcutPath, "Create Steam shortcut")) {
        New-Shortcut -ShortcutPath $shortcutPath `
            -TargetPath $steamExe `
            -Arguments $launchArgs `
            -Description "Steam (Optimized) - Performance-focused launch" `
            -WorkingDirectory $steamPath
        Write-Host "Shortcut created: $shortcutPath" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
