#Requires -Version 5.1

<#
.SYNOPSIS
    Sanitizes filenames under a folder for portable storage on a Nextcloud/btrfs server.
.DESCRIPTION
    Renames files and directories to a lowercase, ASCII-safe form using the shared
    ConvertTo-SafeFileName helper (strips diacritics, replaces spaces and special
    characters with underscores). Runs depth-first so child paths are never orphaned
    by a parent rename, resolves name collisions by appending _1, _2, ..., and
    truncates names over btrfs's 255-byte limit.
    A leading dot is not preserved (ConvertTo-SafeFileName trims it), so .gitignore
    becomes gitignore - expected for a media/document sync target, not meant for
    folders containing dotfiles.
    Runs in preview mode by default; nothing is renamed until you pass -Apply.
.PARAMETER Path
    Folder to scan recursively.
.PARAMETER Apply
    Perform renames. Without it, the script only previews what would change.
.PARAMETER FilesOnly
    Skip renaming directories; only sanitize file names.
.EXAMPLE
    .\sanitize-filenames.ps1 -Path 'D:\NextcloudSync'
    Preview renames without changing anything.
.EXAMPLE
    .\sanitize-filenames.ps1 -Path 'D:\NextcloudSync' -Apply
    Rename files and folders in place.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [switch]$Apply,

    [switch]$FilesOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Common.ps1"

if (-not $Apply) {
    $WhatIfPreference = $true
}

if (-not (Test-Path -LiteralPath $Path)) {
    throw "Path not found: $Path"
}

# btrfs filename limit is 255 bytes; ASCII-only output after sanitization means chars == bytes.
$maxNameLength = 255

function Resolve-UniqueName {
    <#
    .SYNOPSIS
        Appends _1, _2, ... to a candidate name until it doesn't collide in a directory.
    .PARAMETER Directory
        Parent directory the name will live in.
    .PARAMETER Name
        Candidate sanitized name (with extension).
    .PARAMETER OriginalFullName
        Full path of the item being renamed, excluded from the collision check.
    .PARAMETER ClaimedPath
        Set of target paths already handed out this run (preview mode never actually
        renames anything, so the filesystem alone under-reports collisions between two
        sources that sanitize to the same name).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$OriginalFullName,
        # PowerShell treats a Mandatory collection param as unbound when Count is 0 unless
        # AllowEmptyCollection is present - the very first call always passes an empty set.
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.HashSet[string]]$ClaimedPath
    )
    process {
        $base = [IO.Path]::GetFileNameWithoutExtension($Name)
        $ext = [IO.Path]::GetExtension($Name)
        $candidate = $Name
        $suffix = 0
        $candidatePath = Join-Path $Directory $candidate
        while (((Test-Path -LiteralPath $candidatePath) -or $ClaimedPath.Contains($candidatePath)) -and
            ($candidatePath -ne $OriginalFullName)) {
            $suffix++
            $candidate = "${base}_$suffix$ext"
            $candidatePath = Join-Path $Directory $candidate
        }
        $ClaimedPath.Add($candidatePath) | Out-Null
        $candidate
    }
}

$items = Get-ChildItem -LiteralPath $Path -Recurse -Force
if ($FilesOnly) { $items = $items | Where-Object { -not $_.PSIsContainer } }

# Depth-first: rename children before their parent so already-collected FullName
# values for descendants don't go stale when an ancestor directory is renamed.
$items = $items | Sort-Object -Property @{ Expression = { ($_.FullName -split '\\').Count } } -Descending

$renamed = 0
$skipped = 0
$collided = 0
$failed = 0
$claimedPath = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

foreach ($item in $items) {
    $directory = Split-Path -Parent $item.FullName
    $new = (ConvertTo-SafeFileName -Name $item.Name).ToLowerInvariant()

    if ($new.Length -gt $maxNameLength) {
        $ext = [IO.Path]::GetExtension($new)
        if ($ext.Length -ge $maxNameLength) {
            # Extension alone already fills (or exceeds) the limit; truncate the whole name
            # instead of passing a negative length to Substring.
            $new = $new.Substring(0, $maxNameLength)
        }
        else {
            $base = [IO.Path]::GetFileNameWithoutExtension($new)
            $base = $base.Substring(0, $maxNameLength - $ext.Length)
            $new = "$base$ext"
        }
    }

    if ($new -ceq $item.Name) {
        $skipped++
        continue
    }

    $unique = Resolve-UniqueName -Directory $directory -Name $new -OriginalFullName $item.FullName `
        -ClaimedPath $claimedPath
    if ($unique -ne $new) {
        Write-Warn "Collision: '$($item.Name)' -> '$new' already exists, using '$unique' instead."
        $collided++
        $new = $unique
    }

    try {
        if ($PSCmdlet.ShouldProcess($item.FullName, "Rename to '$new'")) {
            Rename-Item -LiteralPath $item.FullName -NewName $new
            Write-Info "'$($item.Name)' -> '$new'"
            $renamed++
        }
    }
    catch {
        $err = $_
        Write-Warn "Failed to rename '$($item.FullName)': $($err.Exception.Message)"
        $failed++
    }
}

Write-Header 'SANITIZE SUMMARY'
Write-ColorOutput "  Renamed:   $renamed" -ForegroundColor Green
Write-ColorOutput "  Skipped:   $skipped (already safe)" -ForegroundColor White
Write-ColorOutput "  Collided:  $collided (suffixed)" -ForegroundColor Yellow
Write-ColorOutput "  Failed:    $failed" -ForegroundColor Red

if (-not $Apply) {
    Write-ColorOutput "`nPreview only - re-run with -Apply to rename." -ForegroundColor Cyan
}
