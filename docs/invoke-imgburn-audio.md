# invoke-imgburn-audio.ps1

Burns a folder of audio files to CD via ImgBurn. Default mode transcodes every source file
(FLAC, WAV, MP3, WMA, OGG, AAC, M4A, APE, WV, AIFF, DFF, DSF) to Red Book CD-DA
(44.1kHz/16-bit/stereo PCM WAV) with ffmpeg, builds a CUE sheet, and burns an audio CD for
car radio compatibility. `-DataCd` instead transcodes to 320kbps MP3 and burns an
ISO9660+Joliet data disc for head units that read MP3 files directly.

Auto-detects the CD burner drive and ImgBurn install path. Erases rewritable media
automatically; fails if a finalized CD-R already has data.

Requires `ImgBurn` and `ffmpeg` on PATH:

```powershell
winget install LIGHTNINGUK.ImgBurn Gyan.FFmpeg
```

## Usage

Burn an audio CD (auto-detected drive, speed 8x, DAO):

```powershell
.\Scripts\invoke-imgburn-audio.ps1 -Path "$env:USERPROFILE\Music\my_playlist"
```

Specific drive and slower speed for better car radio compatibility:

```powershell
.\Scripts\invoke-imgburn-audio.ps1 -Path "D:\Music\playlist" -DriveLetter F -Speed 4
```

Eject and verify after burning:

```powershell
.\Scripts\invoke-imgburn-audio.ps1 -Path "D:\Music\playlist" -Eject -Verify
```

MP3 data disc for head units that read MP3s off a data CD:

```powershell
.\Scripts\invoke-imgburn-audio.ps1 -Path "D:\Music\playlist" -DataCd
```

## Parameters

| Parameter | Default | Notes |
| --- | --- | --- |
| `-Path` | (mandatory) | Directory of source audio files |
| `-DriveLetter` | auto-detected | CD/DVD burner drive letter (e.g. `E`) |
| `-Speed` | `8` | Write speed 1-48; lower speeds reduce errors |
| `-WriteType` | `DAO` | `DAO` or `SAO`; ignored with `-DataCd` |
| `-DataCd` | off | Burn ISO9660+Joliet MP3 data disc instead of Red Book audio CD |
| `-Eject` | off | Eject disc after burning |
| `-Verify` | off | Verify burned disc (adds ~10 min) |
| `-PassThrough` | off | Emit burn result objects to the pipeline |

Supports `-WhatIf` / `-Confirm` (`SupportsShouldProcess`).

## Notes

- ImgBurn does not decode audio — it burns exactly the bytes a CUE points at. This script
  transcodes every source file via ffmpeg before handing off to ImgBurn.
- `-DataCd` output MP3s are kept in a persistent `<Path>_mp3` folder next to the source for reuse.
- Always use CD-R media (not CD-RW) for car radio compatibility.

Full parameter and example docs: `Get-Help .\Scripts\invoke-imgburn-audio.ps1 -Full`.
