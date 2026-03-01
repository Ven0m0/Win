<#
.SYNOPSIS
    Cleans Spotify cache, supporting custom storage locations.

.DESCRIPTION
    By default, Spotify stores its cache in $env:LOCALAPPDATA\Spotify.
    However, users can move it by modifying the "%AppData%\Spotify\prefs" file and
    adding a storage.location entry. This script parses the prefs file and cleans
    the cache from the custom location if it exists, falling back to the default
    location otherwise.
#>

$ErrorActionPreference = "Stop"

$prefsFile = Join-Path $env:APPDATA "Spotify\prefs"
$cacheLocations = [System.Collections.Generic.List[string]]::new()

# Check for custom storage location
if (Test-Path $prefsFile) {
    $match = Select-String -Path $prefsFile -Pattern '^storage\.location="(.*?)"' -Quiet -ErrorAction SilentlyContinue
    if ($match) {
        $fullMatch = Select-String -Path $prefsFile -Pattern '^storage\.location="(.*?)"'
        $customPath = $fullMatch.Matches.Groups[1].Value.Replace("\\", "\")

        if ($customPath -and (Test-Path $customPath)) {
            Write-Verbose "Found custom Spotify storage location: $customPath"
            $cacheLocations.Add($customPath)
        }
    }
}

# Add default cache location if custom wasn't found or as a fallback just in case
$defaultCache = Join-Path $env:LOCALAPPDATA "Spotify"
if ($cacheLocations.Count -eq 0 -and (Test-Path $defaultCache)) {
    Write-Verbose "Using default Spotify cache location: $defaultCache"
    $cacheLocations.Add($defaultCache)
}

foreach ($location in $cacheLocations) {
    $storagePath = Join-Path $location "Storage\*"
    $browserPath = Join-Path $location "Browser\*"

    Write-Host "Cleaning Spotify cache at $location..."

    if (Test-Path (Join-Path $location "Storage")) {
        Remove-Item -Path $storagePath -Recurse -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path (Join-Path $location "Browser")) {
        Remove-Item -Path $browserPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    # old_* items (files or folders) can be anywhere in the root
    Get-ChildItem -Path $location -Filter "old_*" -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "Cleaned Spotify cache at $location."
}
