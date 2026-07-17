#Requires -Version 5.1

<#
.SYNOPSIS
    Downloads YouTube music as FLAC using yt-dlp for CD burning.
.DESCRIPTION
    Downloads YouTube playlists or individual videos as high-quality audio files using
    yt-dlp with embedded metadata and thumbnail. Defaults to MP3; use -Format flac for
    lossless output (e.g. for burning audio CDs). Requires yt-dlp and ffmpeg on PATH.
    Each download is placed in a subfolder named after the playlist or video title,
    sanitized to lowercase with underscores replacing spaces and special characters removed.
.PARAMETER Url
    One or more YouTube playlist or video URLs. Accepts pipeline input.
.PARAMETER OutputDirectory
    Base directory under which a sanitized playlist/video subfolder is created.
    Default: $env:USERPROFILE\Music
.PARAMETER Format
    Audio format to extract: mp3 (default) or flac.
.PARAMETER SponsorBlockCategories
    SponsorBlock categories to strip from audio (sponsor, intro, outro, selfpromo,
    preview, filler, interaction, music_offtopic, poi_highlight, all). Default: all.
.PARAMETER NoSponsorBlock
    Disable SponsorBlock segment removal entirely.
.PARAMETER CookiesFromBrowser
    Browser to extract cookies from for age-restricted content (chrome, firefox,
    edge, helium, etc.). Validated against a test request before downloading; if
    invalid, the run continues without cookies.
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
    Requires yt-dlp and ffmpeg on PATH.
    Install via: winget install yt-dlp  or  scoop install yt-dlp ffmpeg
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
    [string[]]$Url,

    [Alias('OutDir')]
    [string]$OutputDirectory = (Join-Path -Path $env:USERPROFILE -ChildPath 'Music'),

    [ValidateSet('mp3', 'flac')]
    [string]$Format = 'mp3',

    [ValidateSet('sponsor', 'intro', 'outro', 'selfpromo', 'preview', 'filler',
        'interaction', 'music_offtopic', 'poi_highlight', 'all')]
    [string[]]$SponsorBlockCategories = @('all'),

    [switch]$NoSponsorBlock,

    [string]$CookiesFromBrowser,

    [string]$OutputTemplate = '%(playlist_index)03d - %(title)s.%(ext)s',

    [switch]$PassThrough
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Common.ps1"

# Guard: verify required external tools
$missingDeps = @()
foreach ($cmd in 'yt-dlp', 'ffmpeg') {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        $missingDeps += $cmd
    }
}
if ($missingDeps.Count -gt 0) {
    Write-Warning ("Missing required dependencies: $($missingDeps -join ', ')`n" +
        "Install via winget: winget install $($missingDeps -join ' ')`n" +
        '(or scoop install) and ensure each is on PATH.')
    exit 1
}

Add-Log -Text 'YouTube Music Downloader started'

# Resolve cookie args once and verify they actually authenticate before downloading
$cookieArgs = @()
if ($CookiesFromBrowser) {
    Add-Log -Text "Cookies from browser: $CookiesFromBrowser"
    if ($CookiesFromBrowser -eq 'helium') {
        $heliumCookiePath = "$env:LOCALAPPDATA\Helium\User Data\Default\Cookies"
        if ((Test-Path -LiteralPath $heliumCookiePath) -and (Get-Item -LiteralPath $heliumCookiePath).Length -gt 0) {
            $cookieArgs = @('--cookies', $heliumCookiePath)
        } else {
            Write-Warning "Helium cookies not found or empty at: $heliumCookiePath"
        }
    } else {
        $cookieArgs = @('--cookies-from-browser', $CookiesFromBrowser)
    }

    if ($cookieArgs.Count -gt 0) {
        Write-Verbose "Validating cookies against: $($Url[0])"
        $null = & yt-dlp @cookieArgs --simulate --skip-download --no-warnings --quiet $Url[0] 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Cookies from '$CookiesFromBrowser' failed validation (exit $LASTEXITCODE) - continuing without cookies"
            Add-Log -Text "Cookie validation FAILED for: $CookiesFromBrowser"
            $cookieArgs = @()
        } else {
            Add-Log -Text 'Cookie validation succeeded'
        }
    }
}

$sponsorBlockArgs = @()
if (-not $NoSponsorBlock) {
    $sponsorBlockArgs = @('--sponsorblock-remove', ($SponsorBlockCategories -join ','))
}

$results = [System.Collections.Generic.List[PSObject]]::new()

foreach ($u in $Url) {
    # Resolve folder name from content title
    Add-Log -Text "Resolving title for: $u"
    $rawTitle = & yt-dlp @cookieArgs --print playlist_title $u 2>$null
    if (-not $rawTitle) {
        $rawTitle = & yt-dlp @cookieArgs --print title $u 2>$null
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

    $ytArgs = $cookieArgs + @(
        '-x'
        '--audio-format', $Format
        '--audio-quality', '0'
        '--embed-metadata'
        '--embed-thumbnail'
        '--parse-metadata', '%(playlist_index)s:%(track_number)s'
        '-o', $OutputTemplate
        '-P', $outDir
        '--ignore-errors'
    ) + $sponsorBlockArgs

    $ytArgs += $u

    $label = $u
    if ($label.Length -gt 70) {
        $label = $label.Substring(0, 67) + '...'
    }

    if ($PSCmdlet.ShouldProcess($label, "Download FLAC to $outDir")) {
        Write-Verbose "Running: yt-dlp $($ytArgs -join ' ')"
        Add-Log -Text "Starting: $u"

        & yt-dlp @ytArgs 2>&1
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
