# invoke-ytdlp-download.ps1

Downloads YouTube playlists or videos as audio (MP3 default, FLAC for CD burning) via yt-dlp,
with embedded metadata/thumbnail and SponsorBlock segment removal. Each download lands in a
subfolder named after the playlist/video title (lowercased, spaces to underscores, specials
stripped).

Requires `yt-dlp` and `ffmpeg` on PATH:

```powershell
winget install yt-dlp ffmpeg
```

## Usage

Basic playlist download (defaults to MP3, `$env:USERPROFILE\Music`):

```powershell
.\Scripts\invoke-ytdlp-download.ps1 -Url "https://youtube.com/playlist?list=PL..."
```

FLAC output to a custom directory:

```powershell
.\Scripts\invoke-ytdlp-download.ps1 -Url "https://youtube.com/watch?v=..." -Format flac -OutDir "D:\Music"
```

Age-restricted content via browser cookies:

```powershell
.\Scripts\invoke-ytdlp-download.ps1 -Url "https://..." -CookiesFromBrowser helium
```

Batch from a file, collecting result objects:

```powershell
Get-Content urls.txt | .\Scripts\invoke-ytdlp-download.ps1 -PassThrough
```

## Parameters

| Parameter | Default | Notes |
| --- | --- | --- |
| `-Url` | (mandatory) | One or more playlist/video URLs; pipeline input accepted |
| `-OutputDirectory` / `-OutDir` | `$env:USERPROFILE\Music` | Base dir; sanitized subfolder created per item |
| `-Format` | `mp3` | `mp3` or `flac` |
| `-SponsorBlockCategories` | `all` | Categories to strip; see script help for full set |
| `-NoSponsorBlock` | off | Disables SponsorBlock entirely |
| `-CookiesFromBrowser` | none | Fallback cookie source (chrome, firefox, edge, helium, ...) |
| `-CookiesFile` | `$env:USERPROFILE\Downloads\cookies.txt` | Used automatically when present; takes precedence over `-CookiesFromBrowser`, works even while the source browser is running |
| `-OutputTemplate` | `%(playlist_index)03d - %(title)s.%(ext)s` | yt-dlp output template within the subfolder |
| `-PassThrough` | off | Emit result objects to the pipeline |

Supports `-WhatIf` / `-Confirm` (`SupportsShouldProcess`).

Full parameter and example docs: `Get-Help .\Scripts\invoke-ytdlp-download.ps1 -Full`.
