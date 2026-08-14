#Requires -Version 5.1

<#
.SYNOPSIS
    Downloads YouTube or Spotify music as FLAC/MP3 for CD burning.
.DESCRIPTION
    Downloads YouTube playlists/videos via yt-dlp, or Spotify tracks/playlists/albums via
    spotdl, as high-quality audio files with embedded metadata and thumbnail. Source is
    auto-detected from each URL (open.spotify.com -> spotdl, everything else -> yt-dlp).
    Defaults to MP3; use -Format flac for lossless output (e.g. for burning audio CDs).
    Requires yt-dlp and ffmpeg on PATH for YouTube URLs; spotdl and ffmpeg on PATH for
    Spotify URLs. Each download is placed in a subfolder named after the playlist or
    video/track title, sanitized to lowercase with underscores replacing spaces and
    special characters removed.
.PARAMETER Url
    One or more YouTube or Spotify (open.spotify.com) playlist/video/track/album URLs.
    Accepts pipeline input.
.PARAMETER OutputDirectory
    Base directory under which a sanitized playlist/video subfolder is created.
    Default: $env:USERPROFILE\Music
.PARAMETER Format
    Audio format to extract: mp3 (default) or flac.
.PARAMETER SponsorBlockCategories
    SponsorBlock categories to strip from audio (sponsor, intro, outro, selfpromo, filler,
    interaction, music_offtopic, all). Default: all except intro (intro often cuts a song's
    musical start, not just the channel intro).
.PARAMETER NoSponsorBlock
    Disable SponsorBlock segment removal entirely.
.PARAMETER CookiesFromBrowser
    Browser to extract cookies from for age-restricted content (chrome, firefox,
    edge, helium, etc.). Validated against a test request before downloading; if
    invalid, the run continues without cookies. Only used as a fallback when
    -CookiesFile is not found. For helium, requires the browser to be closed.
.PARAMETER CookiesFile
    Path to a Netscape-format cookies.txt (e.g. exported via the "Get cookies.txt
    LOCALLY" browser extension). Defaults to $env:USERPROFILE\Downloads\cookies.txt
    and is used automatically whenever that file exists - no flag required. Takes
    precedence over -CookiesFromBrowser and works even while the source browser
    is running.
.PARAMETER OutputTemplate
    yt-dlp output template string within the subfolder.
    Default: %(playlist_index)03d - %(title)s.%(ext)s
.PARAMETER PassThrough
    Emit download result objects to the pipeline for further processing.
.EXAMPLE
    .\invoke-ytdlp-download.ps1 -Url "https://youtube.com/playlist?list=PL..."
.EXAMPLE
    .\invoke-ytdlp-download.ps1 -Url "https://youtube.com/playlist?list=PL..." -Format flac
.EXAMPLE
    .\invoke-ytdlp-download.ps1 -Url "https://youtube.com/watch?v=..." -OutDir "D:\Music"
.EXAMPLE
    .\invoke-ytdlp-download.ps1 -Url "https://..." -CookiesFromBrowser helium
.EXAMPLE
    Get-Content urls.txt | .\invoke-ytdlp-download.ps1 -PassThrough
.NOTES
    Requires yt-dlp and ffmpeg on PATH for YouTube URLs; spotdl for Spotify URLs.
    Install via: winget install yt-dlp  or  scoop install yt-dlp ffmpeg
    Install spotdl via: pip install spotdl  (also requires ffmpeg on PATH)
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
    [string[]]$Url,

    [Alias('OutDir')]
    [string]$OutputDirectory = (Join-Path -Path $env:USERPROFILE -ChildPath 'Music'),

    [ValidateSet('mp3', 'flac')]
    [string]$Format = 'mp3',

    [ValidateSet('sponsor', 'intro', 'outro', 'selfpromo', 'filler',
        'interaction', 'music_offtopic', 'all')]
    [string[]]$SponsorBlockCategories = @('sponsor', 'outro', 'selfpromo', 'filler', 'interaction', 'music_offtopic'),

    [switch]$NoSponsorBlock,

    [string]$CookiesFromBrowser,

    # Netscape-format cookies.txt (e.g. exported via "Get cookies.txt LOCALLY").
    # Used automatically when present; works even while the browser is running.
    [string]$CookiesFile = (Join-Path -Path $env:USERPROFILE -ChildPath 'Downloads\cookies.txt'),

    [string]$OutputTemplate = '%(playlist_index)03d - %(title)s.%(ext)s',

    [switch]$PassThrough
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Common.ps1"

# Guard: verify required external tools (spotdl only required when a Spotify URL is present)
$requiredDeps = @('yt-dlp', 'ffmpeg')
if ($Url -match 'open\.spotify\.com') {
    $requiredDeps += 'spotdl'
}
$missingDeps = @()
foreach ($cmd in $requiredDeps) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        $missingDeps += $cmd
    }
}
if ($missingDeps.Count -gt 0) {
    Write-Warning "Missing required dependencies: $($missingDeps -join ', ') - installing"

    if ($missingDeps -contains 'spotdl') {
        if ($PSCmdlet.ShouldProcess('spotdl', 'Install via uv pip')) {
            & uv pip install spotdl
        }
    }

    $wingetPackages = @{
        'yt-dlp' = @('yt-dlp.yt-dlp', 'yt-dlp.FFmpeg')
        'ffmpeg' = @('Gyan.FFmpeg')
    }
    $wingetIds = $missingDeps | Where-Object { $wingetPackages.ContainsKey($_) } |
        ForEach-Object { $wingetPackages[$_] } | Select-Object -Unique
    foreach ($id in $wingetIds) {
        if ($PSCmdlet.ShouldProcess($id, 'Install via winget')) {
            & winget install --id $id -h --accept-package-agreements --accept-source-agreements `
                --disable-interactivity --nowarn
        }
    }

    $stillMissing = @()
    foreach ($cmd in $requiredDeps) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            $stillMissing += $cmd
        }
    }
    if ($stillMissing.Count -gt 0) {
        Write-Warning ("Still missing after install attempt: $($stillMissing -join ', ')`n" +
            'Ensure each is on PATH (may require restarting the shell).')
        exit 1
    }
}

Add-Log -Text 'YouTube Music Downloader started'

# Resolve cookie args once and verify they actually authenticate before downloading.
# A pre-exported cookies.txt takes precedence: it works even while the browser is
# running, unlike live extraction from a locked browser profile DB. -CookiesFromBrowser
# is only used as a fallback when no cookies.txt is found.
$cookieArgs = @()
$cookieSourceLabel = $CookiesFromBrowser
if ($CookiesFile -and (Test-Path -LiteralPath $CookiesFile) `
        -and (Get-Item -LiteralPath $CookiesFile).Length -gt 0) {
    Add-Log -Text "Cookies from file: $CookiesFile"
    $cookieArgs = @('--cookies', $CookiesFile)
    $cookieSourceLabel = $CookiesFile
} elseif ($CookiesFromBrowser) {
    Add-Log -Text "Cookies from browser: $CookiesFromBrowser"
    if ($CookiesFromBrowser -eq 'helium') {
        # yt-dlp has no native "helium" extractor and Helium's live cookie DB requires the
        # browser to be closed to read.
        Write-Warning "No cookies.txt found at: $CookiesFile - falling back to live browser extraction (close Helium first)"
        $heliumProfile = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'imput\Helium\User Data\Default'
        $cookieArgs = @('--cookies-from-browser', "chrome:$heliumProfile")
    } else {
        $cookieArgs = @('--cookies-from-browser', $CookiesFromBrowser)
    }
}

if ($cookieArgs.Count -gt 0) {
    Write-Verbose "Validating cookies against: $($Url[0])"
    # -playlist-items 1 bounds validation to the first entry: a full playlist -simulate
    # would fail (and wipe good cookies) if any single unrelated entry errors out.
    $null = & yt-dlp @cookieArgs --simulate --skip-download --no-warnings --quiet --playlist-items 1 $Url[0] 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Cookies from '$cookieSourceLabel' failed validation (exit $LASTEXITCODE) - continuing without cookies"
        Add-Log -Text "Cookie validation FAILED for: $cookieSourceLabel"
        $cookieArgs = @()
    } else {
        Add-Log -Text 'Cookie validation succeeded'
    }
}

$sponsorBlockArgs = @()
if (-not $NoSponsorBlock) {
    $sponsorBlockArgs = @('--sponsorblock-remove', ($SponsorBlockCategories -join ','))
}

$results = [System.Collections.Generic.List[PSObject]]::new()

foreach ($u in $Url) {
    $isSpotify = $u -match 'open\.spotify\.com'

    # Resolve folder name from content title
    Add-Log -Text "Resolving title for: $u"
    if ($isSpotify) {
        $metaFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "spotdl-$([guid]::NewGuid()).spotdl"
        try {
            $null = & spotdl save $u --save-file $metaFile 2>&1
            $rawTitle = $null
            if (Test-Path -LiteralPath $metaFile) {
                $meta = Get-Content -LiteralPath $metaFile -Raw | ConvertFrom-Json
                $first = if ($meta -is [array]) { $meta[0] } else { $meta }
                $rawTitle = if ($first.list_name) { $first.list_name } else { $first.name }
            }
        } finally {
            Remove-Item -LiteralPath $metaFile -ErrorAction SilentlyContinue
        }
    } else {
        $rawTitle = & yt-dlp @cookieArgs --print playlist_title $u 2>$null | Select-Object -First 1
        if (-not $rawTitle) {
            $rawTitle = & yt-dlp @cookieArgs --print title $u 2>$null | Select-Object -First 1
        }
    }
    if (-not $rawTitle) {
        Write-Warning "Could not resolve title for: $u"
        $rawTitle = 'Unknown'
    }

    # Sanitize to lowercase folder name: spaces -> underscores, strip specials
    $folderName = ($rawTitle.ToLowerInvariant() -replace '\s+', '_' -replace '[^a-z0-9_-]', '' -replace '_+', '_').Trim('_')
    if (-not $folderName) { $folderName = 'playlist' }

    $outDir = Join-Path -Path $OutputDirectory -ChildPath $folderName
    Ensure-Directory -Path $outDir

    Add-Log -Text "Output folder: $outDir"

    if ($isSpotify) {
        $exeName = 'spotdl'
        $downloadArgs = @(
            'download', $u
            '--format', $Format
            '--output', (Join-Path -Path $outDir -ChildPath '{track-number} - {title}.{output-ext}')
        )
    } else {
        $exeName = 'yt-dlp'
        $downloadArgs = $cookieArgs + @(
            '-x'
            '--audio-format', $Format
            '--audio-quality', '0'
            '--embed-metadata'
            '--embed-thumbnail'
            '--parse-metadata', '%(playlist_index)s:%(track_number)s'
            '-o', $OutputTemplate
            '-P', $outDir
            '--ignore-errors'
        ) + $sponsorBlockArgs + @($u)
    }

    $label = $u
    if ($label.Length -gt 70) {
        $label = $label.Substring(0, 67) + '...'
    }

    if ($PSCmdlet.ShouldProcess($label, "Download $Format to $outDir")) {
        Write-Verbose "Running: $exeName $($downloadArgs -join ' ')"
        Add-Log -Text "Starting: $u"

        & $exeName @downloadArgs 2>&1
        $ec = $LASTEXITCODE

        # Post-process: lowercase filenames, replace spaces with underscores, strip special chars
        if ($ec -eq 0 -and (Test-Path -LiteralPath $outDir)) {
            Get-ChildItem -LiteralPath $outDir -File | ForEach-Object {
                $newBase = $_.BaseName.ToLowerInvariant() -replace '\s+', '_' -replace '[^a-z0-9_-]', '' -replace '_+', '_'
                $newName = $newBase.TrimEnd('.') + $_.Extension.ToLowerInvariant()
                if ($_.Name -ne $newName) {
                    $null = Rename-Item -LiteralPath $_.FullName -NewName $newName -ErrorAction SilentlyContinue
                }
            }
        }

        if ($ec -eq 0) {
            Add-Log -Text "Completed: $u"
            if ($PassThrough) {
                $results.Add([PSCustomObject]@{
                    Url      = $u
                    Folder   = $folderName
                    OutDir   = $outDir
                    Status   = 'Completed'
                    ExitCode = $ec
                })
            }
        } else {
            Write-Warning "yt-dlp exited with code $ec for: $u"
            Add-Log -Text "FAILED (exit $ec): $u"
            if ($PassThrough) {
                $results.Add([PSCustomObject]@{
                    Url      = $u
                    Folder   = $folderName
                    Status   = "Failed (exit $ec)"
                    ExitCode = $ec
                })
            }
        }
    }
}

if ($PassThrough -and $results.Count -gt 0) {
    $results
}
