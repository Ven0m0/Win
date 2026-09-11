# optimize-media.ps1

Batch-compresses images and re-encodes videos to H.265/Opus. **Intended to run after
`Scripts\dedupe-media.ps1`** has removed duplicates, so the compression/re-encode work
never touches a file that was about to be deleted.

## Image handling

Images are compressed in place, per format:

| Format | Tool | Mode | Backup |
| --- | --- | --- | --- |
| PNG | oxipng | Lossless, batched | None — lossless, and oxipng refuses to grow a file without `-Force` |
| JPEG | jpegoptim `-m<ImageQuality>` | Lossy, batched | Yes, copied to `-BackupPath` first |
| WEBP | cwebp `-q<ImageQuality>` | Lossy | Yes; result kept only when smaller (unless `-Force`) |
| GIF | gifsicle `-O3 -b` | Lossless | None; skipped with a warning if gifsicle is unavailable |
| BMP/TIFF | ffmpeg → PNG, then oxipng batch | Format conversion | Original moved to `-BackupPath` (extension changes) |
| HEIC/HEIF | none | Untouched, reported | — already HEVC-compressed; a re-encode costs quality for almost no bytes |

JPEG metadata (EXIF date, GPS, orientation) is preserved unless `-StripMetadata` is passed.

## Video handling

Videos are re-encoded to H.265 MP4 (10-bit, `hvc1` tag, faststart) with stereo Opus audio,
using NVENC when the GPU/ffmpeg offers `hevc_nvenc` and libx265 otherwise (`-Encoder`).
Sources already encoded as HEVC or AV1 are skipped, as are files already named
`*.h265.mp4`.

An encode is accepted only when: ffmpeg exits 0, the output exists, is non-empty, is
readable by ffprobe, and is smaller than the source. On success the source is moved into
`-BackupPath` (unless `-KeepOriginals`), so the folder actually shrinks. On any failure the
partial output is deleted and the source is left untouched.

Nextcloud/Syncthing metadata directories, sync journals, and partial transfers are skipped
by both passes.

## BackupPath constraint

`-BackupPath` (default `$env:USERPROFILE\Pictures\optimize-media-bak`) must sit outside the
scanned `-Path` — validated at runtime, and the script throws if it's inside. A backup
inside a synced folder (Nextcloud, OneDrive) gets uploaded too, doubling server storage
instead of shrinking it.

## Prerequisites

- `ffmpeg`/`ffprobe` — required, installed via winget (`Gyan.FFmpeg.Shared`) if missing.
- `oxipng`, `jpegoptim`, `cwebp`, `gifsicle` — optional; installed via winget/scoop on
  first use, degrade to a warning (format left uncompressed) if unavailable.

```powershell
winget install Gyan.FFmpeg.Shared
```

## Usage

Compress images and re-encode videos, mirroring originals into
`$env:USERPROFILE\Pictures\optimize-media-bak`:

```powershell
.\Scripts\optimize-media.ps1 -Path "$env:USERPROFILE\Pictures"
```

Force CPU encoding and keep the backups off the synced volume entirely:

```powershell
.\Scripts\optimize-media.ps1 -Path 'D:\Nextcloud\Photos' -BackupPath 'E:\media-bak' -Encoder x265
```

Show full help and exit:

```powershell
.\Scripts\optimize-media.ps1 -Help
```

## Parameters

| Parameter | Default | Notes |
| --- | --- | --- |
| `-Path` | folder picker dialog | Folder to scan recursively |
| `-Help` / `-h` | off | Show help and exit; also recognizes literal `-h`, `--help`, `/?` as the first positional arg |
| `-BackupPath` | `$env:USERPROFILE\Pictures\optimize-media-bak` | Must not sit inside `-Path` |
| `-SkipImages` | off | Skip the image compression pass |
| `-SkipVideo` | off | Skip the video re-encode pass |
| `-ImageQuality` | `90` | JPEG/WEBP quality factor, 0 (worst) to 100 (best); PNG/GIF are always lossless |
| `-OxipngLevel` | `4` | oxipng optimization level, 0 (fastest) to 6 (slowest); level 6 costs several times the runtime for a fraction of a percent |
| `-StripMetadata` | off | Passes `-s` to jpegoptim, discarding EXIF/GPS/orientation — off by default (silent data loss on a photo library) |
| `-VideoQuality` | `24` | libx265 crf, or the NVENC constant-quality value; 0 (best/largest) to 51 (worst/smallest) |
| `-AudioBitrate` | `128k` | Opus audio bitrate |
| `-Encoder` | `Auto` | `Auto` (NVENC when ffmpeg reports `hevc_nvenc`, else x265), `NVENC`, or `x265` |
| `-KeepOriginals` | off | Keep the source video in place after a successful encode instead of moving it to `-BackupPath`; folder will not shrink |
| `-Force` | off | Keep optimized images even if not smaller than the original, overwrite existing video outputs, and re-encode videos already HEVC/AV1 |

Supports `-WhatIf` / `-Confirm` (`SupportsShouldProcess`, `ConfirmImpact = 'Medium'`).

Full parameter and example docs: `Get-Help .\Scripts\optimize-media.ps1 -Full`.
