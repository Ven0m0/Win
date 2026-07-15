# Plan: YouTube Music Playlist Downloader (`Scripts/invoke-ytdlp-download.ps1`)

## Goal

Create a CLI-parameter-only PowerShell script that downloads YouTube music playlists (or individual videos) as high-quality FLAC files using yt-dlp, suitable for burning to CD for car radios.

## Design Decisions (Confirmed)

| Decision | Choice |
|---|---|
| Interaction mode | CLI parameters only (no menus/prompts) |
| Default output | `$HOME\Music\yt-dlp` |
| Download archive | None (no archive tracking) |
| URL types | Both playlists and individual videos |
| Dependency check | Verify yt-dlp + ffmpeg on PATH; warn and exit if missing |
| Cookies support | Optional `-CookiesFromBrowser` parameter |
| Audio format | FLAC (yt-dlp `-x --audio-format flac`) |
| Naming | `%(playlist_index)03d - %(title)s.%(ext)s` |

## Parameters

```
-Position 0, ValueFromPipeline, string[] Url        # Required. One or more URLs
-string OutputDirectory                              # Default: $HOME\Music\yt-dlp   Alias: -OutDir
-string CookiesFromBrowser                           # Optional: browser name for --cookies-from-browser
-string OutputTemplate                               # Default: "%(playlist_index)03d - %(title)s.%(ext)s"
-switch PassThrough                                  # Also emit download info objects to pipeline
```

No `-AudioFormat` / `-AudioQuality` params to keep it focused; add only if requested later.

## Script Structure

Follow the repo conventions from `AGENTS.md` (`lowercase-with-dashes.ps1` naming) and `powershell.md` rules:

1. `#Requires -Version 5.1` header
2. Comment-based help (SYNOPSIS, DESCRIPTION, PARAMETER, EXAMPLE, NOTES)
3. `[CmdletBinding()]` (no `SupportsShouldProcess` — reads/destructive writes are yt-dlp's domain, not the script's)
4. `param(...)` block
5. `$ErrorActionPreference = 'Stop'`
6. Dot-source `Common.ps1` from `$PSScriptRoot`
7. Helper function: `Test-Dependency` — checks `yt-dlp` and `ffmpeg` via `Get-Command`
8. Helper function: `Get-YtdlpCommand` — builds argument list from parameters
9. Helper function: `Invoke-YtdlpDownload` — calls yt-dlp with streaming output
10. `begin { Clear-Log }`
11. `process { Test-Dependency; Invoke-YtdlpDownload for each URL }`
12. `end { Write summary to host }`

## yt-dlp Argument Construction

```powershell
$args = @(
    '-x'                                            # extract audio
    '--audio-format', 'flac'
    '--audio-quality', '0'                          # best quality
    '--embed-metadata'
    '--embed-thumbnail'
    '--parse-metadata', '%(playlist_index)s:%(track_number)s'
    '-o', $OutputTemplate
    '--no-playlist'                                 # if single video, don't try playlist
    $Url
)
if ($CookiesFromBrowser) {
    $args = @('--cookies-from-browser', $CookiesFromBrowser) + $args
}
# Also add --concurrent-fragments 3 for speed? yt-dlp default is 1.
```

## Dependency Check

```powershell
foreach ($cmd in @('yt-dlp', 'ffmpeg')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Warning "$cmd not found on PATH. Install via: winget install $cmd  (or scoop install $cmd)"
        exit 1
    }
}
```

## Output Organization

Files land at `$OutputDirectory\<playlist-title>\` (yt-dlp's default behavior with `-o` using playlist_index). Single videos without a playlist go into `$OutputDirectory\` flat.

## Output Template Handling

The default template uses `%(playlist_index)03d`. For single videos (no playlist), yt-dlp substitutes `NA`, producing filenames like `NA - Title.flac`. If this is undesirable, we could auto-detect — but yt-dlp's `--no-playlist` flag already handles the single-video case correctly, and `NA` will appear for standalone videos. **Accept this as-is** for now; it's a cosmetic artifact, not a bug.

## Edge Cases

| Case | Behavior |
|---|---|
| Missing yt-dlp | Write-Warning, exit 1 |
| Missing ffmpeg | Write-Warning, exit 1 |
| No URLs provided | Write error message, show help via `Get-Help`, exit 1 |
| Network failure | yt-dlp reports error, script passes exit code through |
| Age-restricted video | User passes `-CookiesFromBrowser`; without it, yt-dlp may fail |
| Output dir doesn't exist | Created automatically (yt-dlp creates dirs) |
| URL is dead/unavailable | yt-dlp exit code != 0; script reports which URL failed and continues with next |

## Validation

1. `Invoke-ScriptAnalyzer -Path Scripts\invoke-ytdlp-download.ps1 -Settings PSScriptAnalyzerSettings.psd1`
2. Manual dry-run: `.\invoke-ytdlp-download.ps1 -Url "https://youtube.com/playlist?list=..." -WhatIf` (add a -WhatIf passthrough to yt-dlp)
3. Verify output files are valid FLAC: `ffprobe <file>` or ` mediainfo <file>`
4. Test with single video URL and playlist URL

## Out of Scope (First Iteration)

- Download archive / resume support
- Embedding into `packages.psd1` (yt-dlp already tracked via scoop in `shell-setup.ps1`)
- Concurrent downloads or `-N` threading
- `--limit-rate` / bandwidth throttling
- Config file support
- Spotify or other platform support
- CD-burning automation

## Implementation Order

1. Create `Scripts\invoke-ytdlp-download.ps1` with full parameter block and comment-based help
2. Implement `Test-Dependency` helper
3. Implement arg construction and `Invoke-YtdlpDownload`
4. Wire up `begin/process/end` blocks with logging and summary
5. Run ScriptAnalyzer and fix any violations
