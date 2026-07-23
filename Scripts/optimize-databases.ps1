#Requires -Version 5.1

<#
.SYNOPSIS
    VACUUM SQLite databases for Legcord, Floorp, and Helium to reclaim disk space.
.DESCRIPTION
    Detects SQLite databases by file magic header (not filename), so it works
    across Chromium-style extensionless files (Cookies, History, Web Data) and
    Firefox-style *.sqlite files without a hardcoded per-app file list.

    Closes each app first if running (VACUUM requires an unlocked database),
    vacuums every SQLite file under its profile directory, and reports bytes
    reclaimed. Apps are not relaunched after closing.
.PARAMETER App
    Which app(s) to process. Defaults to All.
.EXAMPLE
    .\Optimize-AppDatabases.ps1
.EXAMPLE
    .\Optimize-AppDatabases.ps1 -App Floorp -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Legcord', 'Floorp', 'Helium', 'All')]
    [string[]]$App = 'All'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Common.ps1"

if (-not (Get-Command sqlite3 -ErrorAction SilentlyContinue)) {
    throw "sqlite3 not found on PATH. Install it (e.g. 'winget install SQLite.SQLite') and retry."
}

$targets = @(
    @{ Name = 'Legcord'; Dir = "$env:APPDATA\Legcord"; Proc = 'Legcord' }
    @{ Name = 'Floorp'; Dir = "$env:APPDATA\Floorp"; Proc = 'floorp' }
    @{ Name = 'Helium'; Dir = "$env:LOCALAPPDATA\imput\Helium\User Data"; Proc = 'helium' }
)
if ($App -notcontains 'All') {
    $targets = $targets | Where-Object { $App -contains $_.Name }
}

# First 16 bytes of every SQLite 3 database file.
$sqliteMagic = [byte[]](83, 81, 76, 105, 116, 101, 32, 102, 111, 114, 109, 97, 116, 32, 51, 0)

function Test-SqliteFile {
    param([string]$Path)
    try {
        $buf = New-Object byte[] 16
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            if ($stream.Read($buf, 0, 16) -lt 16) { return $false }
        }
        finally { $stream.Dispose() }
        for ($i = 0; $i -lt 16; $i++) {
            if ($buf[$i] -ne $sqliteMagic[$i]) { return $false }
        }
        return $true
    }
    catch { return $false }
}

foreach ($target in $targets) {
    if (-not (Test-Path -LiteralPath $target.Dir)) {
        Write-Verbose "$($target.Name) skipped (not installed at $($target.Dir))"
        continue
    }

    $proc = Get-Process -Name $target.Proc -ErrorAction SilentlyContinue
    if ($proc) {
        if ($PSCmdlet.ShouldProcess($target.Name, 'Stop process to unlock databases')) {
            $proc | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
    }

    $dbFiles = Get-ChildItem -LiteralPath $target.Dir -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { Test-SqliteFile -Path $_.FullName }

    if (-not $dbFiles) {
        Write-ColorOutput "$($target.Name): no SQLite databases found" -ForegroundColor DarkGray
        continue
    }

    $reclaimed = 0
    $vacuumed = 0
    foreach ($db in $dbFiles) {
        if (-not $PSCmdlet.ShouldProcess($db.FullName, 'VACUUM')) { continue }
        $before = $db.Length
        & sqlite3 $db.FullName 'VACUUM;' 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "  Failed to vacuum $($db.Name) (locked or corrupt) - skipped"
            continue
        }
        $after = (Get-Item -LiteralPath $db.FullName).Length
        $reclaimed += ($before - $after)
        $vacuumed++
    }

    Write-ColorOutput "$($target.Name): vacuumed $vacuumed database(s), reclaimed $([math]::Round($reclaimed / 1KB, 1)) KB" -ForegroundColor Green
}
