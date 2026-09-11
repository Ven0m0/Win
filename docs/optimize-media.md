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

### `-ConvertToWebp`

Converts JPEG and PNG to WebP instead of compressing them in their source format, replacing
the oxipng/jpegoptim passes above (GIF/AVIF/HEIC behavior is unchanged; existing WEBP files
are left alone rather than re-compressed at `-ImageQuality`, since re-encoding an
already-WebP file is pure generation loss when WebP is the target).

| Source | cwebp flags | Mode |
| --- | --- | --- |
| JPEG | `-q<ImageQuality> -m 6 -af -sharp_yuv` | Lossy; `-sharp_yuv` avoids chroma bleed on edges/text |
| PNG | `-lossless -z 9` | Lossless; a lossy re-encode of a lossless source is the wrong tradeoff |

Both keep all metadata. cwebp's own `-metadata all` only embeds the ICC profile on Windows
builds ("only ICC profile extraction is currently supported on this platform") and silently
drops EXIF/XMP, so EXIF (capture date, GPS, orientation) and XMP are copied in separately
afterward with `exiftool -TagsFromFile`. Without exiftool the WebP keeps ICC only and a
warning is written. The `.webp` result replaces the source only when smaller (see `-Force`);
on success the original is moved into `-BackupPath`, since the extension changes.

## Video handling

Videos are re-encoded to H.265 MP4 (10-bit, `hvc1` tag, faststart, web-optimized) with
stereo Opus audio, using NVENC when the GPU/ffmpeg offers `hevc_nvenc` and libx265
otherwise (`-Encoder`). libx265 is tuned for SSIM at `-crf 28` / `-preset slow`, with a
closed 2-5s GOP (`-g 120`) so the output stays seekable and HTTP-range-streamable at any
framerate up to 60fps. NVENC has no SSIM tune and uses `-cq` at the same value, which reads
visibly softer than x265's `-crf` for the same number. Sources already encoded as HEVC,
AV1, or VP9 are skipped, as are files already named `*.h265.<ext>` (or a future `*.av1.mkv`
/ `*.vp9.mkv`).

`-Denoise` (adds `hqdn3d`) and `-MaxVideoDimension <px>` (caps the longer side, same
contract as the image `-MaxDimension`) are optional and off by default. They are the actual
lever for shrinking already-compressed mobile clips — see "no gain" below — but both are
lossy, so they are opt-in rather than applied to a photo archive automatically.

`ffzap` wraps ffmpeg for the video pass: candidates are collected first, then handed to a
single `ffzap` invocation so `-ThreadCount` files encode concurrently instead of one at a
time (`ffmpeg`/`ffprobe` still do the encoding and validation — ffzap is just the
scheduler).

An encode is accepted only when: the output exists, is non-empty, and is readable by
ffprobe. On success the source is moved into `-BackupPath` (unless `-KeepOriginals`), so
the folder actually shrinks. On any failure the partial output is deleted and the source is
left untouched.

If ffprobe reads the output fine but it is not smaller than the source (already
low-bitrate mobile clips, mainly), the source is kept and the file is counted as "no gain"
rather than "failed" - the encode worked, it just didn't help. Rerunning won't change the
result for these files.

Nextcloud/Syncthing metadata directories, sync journals, and partial transfers are skipped
by both passes.

## BackupPath constraint

`-BackupPath` (default `$env:USERPROFILE\Pictures\optimize-media-bak`) must sit outside the
scanned `-Path` — validated at runtime, and the script throws if it's inside. A backup
inside a synced folder (Nextcloud, OneDrive) gets uploaded too, doubling server storage
instead of shrinking it.

## Prerequisites

- `ffmpeg`/`ffprobe` — required, installed via winget (`Gyan.FFmpeg.Shared`) if missing.
- `ffzap` — required for the video pass, installed via winget (`CodeF0x.ffzap`) if missing.
- `oxipng`, `jpegoptim`, `cwebp`, `gifsicle` — optional; installed via winget/scoop on
  first use, degrade to a warning (format left uncompressed) if unavailable.
- `exiftool` — optional, only used by `-ConvertToWebp` to copy EXIF/XMP into the WebP
  output; installed via winget (`OliverBetz.ExifTool`) if missing. Without it the WebP
  keeps only the ICC profile.

```powershell
winget install Gyan.FFmpeg.Shared
winget install CodeF0x.ffzap
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
| `-OxipngLevel` | `6` | oxipng optimization level, 0 (fastest) to 6 (slowest); lossless either way, higher just spends more time |
| `-StripMetadata` | off | Passes `-s` to jpegoptim, discarding EXIF/GPS/orientation — off by default (silent data loss on a photo library) |
| `-ConvertToWebp` | off | Convert JPEG/PNG to WebP instead of compressing in place; see "ConvertToWebp" above |
| `-VideoQuality` | `28` | libx265 crf, or the NVENC constant-quality value; 0 (best/largest) to 51 (worst/smallest); NVENC's `-cq` reads softer than x265's `-crf` at the same number |
| `-AudioBitrate` | `128k` | Opus audio bitrate |
| `-Encoder` | `Auto` | `Auto` (NVENC when ffmpeg reports `hevc_nvenc`, else x265), `NVENC`, or `x265` |
| `-Denoise` | off | Apply `hqdn3d` before encoding; lossy, helps already-compressed clips shrink |
| `-MaxVideoDimension` | `0` (disabled) | Cap the longer side to this many pixels before encoding, aspect ratio kept, never upscaled; lossy |
| `-ThreadCount` | `4` | Number of videos ffzap encodes concurrently |
| `-KeepOriginals` | off | Keep the source video in place after a successful encode instead of moving it to `-BackupPath`; folder will not shrink |
| `-Force` | off | Keep optimized images even if not smaller than the original, overwrite existing video outputs, and re-encode videos already HEVC/AV1 |

Supports `-WhatIf` / `-Confirm` (`SupportsShouldProcess`, `ConfirmImpact = 'Medium'`).

Full parameter and example docs: `Get-Help .\Scripts\optimize-media.ps1 -Full`.
