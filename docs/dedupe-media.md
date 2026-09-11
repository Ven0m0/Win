# dedupe-media.ps1

Deduplicates images and videos in a folder, exact matches first, fuzzy last:

1. **fclones** — removes byte-for-byte identical duplicates (fast, exact, **permanent**).
2. **czkawka** — duplicate-file hash pass, opt-in via `-IncludeDup`.
3. **czkawka** — finds perceptually similar images (fuzzy).
4. **czkawka** — finds perceptually similar videos (fuzzy, slowest).
5. **czkawka** — removes zero-byte media files.

The czkawka duplicate-file pass is off by default: fclones already found every
byte-identical file in pass 1, faster, so running it again is a second full-tree hash for
no additional matches. `-IncludeDup` re-enables it.

Runs in preview mode by default; nothing is deleted until you pass `-Apply`. Only the
fclones exact-duplicate pass deletes permanently (files are byte-identical). Every czkawka
pass — dup, image, video, empty-files — moves matches to the Recycle Bin instead, so a
wrong match is recoverable. The Recycle Bin has a per-volume size cap, though: a large
czkawka pass can push older recycled items out permanently, so "recoverable" only holds up
to that cap.

In each similar-file or duplicate-file group the newest file is kept (czkawka delete
method `AEN`). Both fclones passes and all czkawka passes skip Nextcloud/Syncthing
metadata, version history, trash bins, and partial-transfer files by default
(`files_versions`, `files_trashbin`, `.nextcloud*`, `.stfolder`, `.stversions`,
`.thumbnails`, `Thumbs.db`, `.cache`, `*.part`, `*.partial`); `-Exclude` appends more glob
patterns to that list.

fclones is installed automatically via scoop, czkawka via winget, if either is missing —
czkawka is resolved lazily, so no install happens if every czkawka pass is skipped and
`-IncludeDup` is not set.

**Run this before `optimize-media.ps1`** — deduping first means the compression/re-encode
pass never touches a file that is about to be deleted anyway.

## Usage

Preview duplicates without deleting anything:

```powershell
.\Scripts\dedupe-media.ps1 -Path "$env:USERPROFILE\Pictures"
```

Remove exact duplicates and send fuzzy matches to the Recycle Bin:

```powershell
.\Scripts\dedupe-media.ps1 -Path "$env:USERPROFILE\Pictures" -Apply
```

Show full help and exit:

```powershell
.\Scripts\dedupe-media.ps1 -Help
```

## Parameters

| Parameter | Default | Notes |
| --- | --- | --- |
| `-Path` | folder picker dialog | Folder to scan recursively |
| `-Help` / `-h` | off | Show help and exit; also recognizes literal `-h`, `--help`, `/?` as the first positional arg |
| `-Apply` | off | Perform deletions; without it the script only previews |
| `-Force` | off | Skip the confirmation prompt when used with `-Apply` |
| `-SkipExact` | off | Skip the fclones exact-duplicate pass |
| `-IncludeDup` | off | Run the czkawka duplicate-file hash pass (redundant with fclones pass 1 by default) |
| `-Exclude` | `@()` | Extra glob patterns matched against the full path, appended to the built-in Nextcloud/sync-metadata list |
| `-SkipImages` | off | Skip the czkawka similar-image pass |
| `-SkipVideos` | off | Skip the czkawka similar-video pass (slowest pass) |
| `-SkipEmptyFiles` | off | Skip the czkawka empty-file pass |
| `-ImageDifference` | `5` | czkawka max image difference, 0 (identical) to 40 (loose) |
| `-VideoTolerance` | `10` | czkawka max video difference, 0 (identical) to 20 (loose) |
| `-VideoWindowCount` | `8` | Temporal windows czkawka samples per video, 1-20; higher means more ffmpeg decoding (the video pass's dominant cost) |
| `-MatchRotated` | off | Also match mirrored/90-degree-rotated image variants (`--geometric-invariance mirror-flip-rotate90`); roughly 3x the image-pass work |
| `-CheckAudio` | off | Also compare videos by audio fingerprint, not just visual frames; very resource-intensive |

Supports `-WhatIf` / `-Confirm` (`SupportsShouldProcess`, `ConfirmImpact = 'High'`).

## Notes

- The dup/image/video passes use Lanczos3 image resampling (highest-quality hashing input)
  and include files below czkawka's default minimum size, so small media is no longer
  silently skipped.
- fclones, czkawka, and any ffmpeg process czkawka spawns for the video pass all run at
  Above Normal CPU priority.
- Preview totals may double-count exact duplicates when `-IncludeDup` is set: fclones only
  simulates removal in a dry run, so the czkawka dup pass still sees and reports the same
  files.

Full parameter and example docs: `Get-Help .\Scripts\dedupe-media.ps1 -Full`.
