#Requires -Version 5.1

<#
.SYNOPSIS
    Batch-optimize images and re-encode videos to H.265/Opus.
.DESCRIPTION
    Intended to run after Scripts\dedupe-media.ps1 has removed duplicates.
    When -MaxDimension is set, oversized JPEG/WEBP/PNG/AVIF images are
    downscaled first (longer side capped, aspect ratio kept, never upscaled),
    so the per-format compression passes below run on the smaller result.
    Images are compressed in place:
      - PNG      -> oxipng, lossless, batched. No backup is taken (lossless,
        and oxipng refuses to grow a file without --force).
      - JPEG     -> jpegoptim -m<ImageQuality>, batched. Lossy, so the
        original is copied into -BackupPath first. Metadata (EXIF date, GPS,
        orientation) is preserved unless -StripMetadata is passed.
      - WEBP     -> cwebp -q<ImageQuality>, lossy, backed up first. The result
        is kept only when smaller (see -Force).
      - GIF      -> gifsicle -O3 -b, lossless. Skipped with a warning when
        gifsicle is not available.
      - BMP/TIFF -> converted to PNG with ffmpeg and then run through the
        oxipng batch; the original is moved into -BackupPath because the
        extension changes.
      - HEIC/HEIF are left untouched and reported: they are already
        HEVC-compressed, so a re-encode costs quality for almost no bytes.
    Videos are re-encoded to H.265 MP4 (10-bit, hvc1 tag, faststart,
    web-optimized) with stereo Opus audio, using NVENC when the GPU offers it
    and libx265 otherwise (see -Encoder). x265 is tuned for SSIM at CRF 28,
    preset slow, with a 2-5s closed GOP so the result stays seekable/
    streamable at any framerate up to 60fps. ffzap wraps ffmpeg so
    -ThreadCount videos encode concurrently instead of one at a time. Sources
    already encoded as HEVC or AV1 are skipped, as are files already named
    "*.h265.<ext>". -Denoise and -MaxVideoDimension are optional, off by
    default: they are the actual lever for shrinking already-compressed
    mobile clips, but are lossy, so they are opt-in rather than applied to a
    photo archive by default.
    An encode is only accepted when ffmpeg exits 0, the output exists, is
    non-empty, and is readable by ffprobe. If the result is not smaller than
    the source (common for already-compressed clips without -Denoise/
    -MaxVideoDimension), the source is kept and the file is counted as "no
    gain" rather than an error. On success the source is moved into
    -BackupPath (unless -KeepOriginals), so the folder actually shrinks. On
    any failure the partial output is deleted and the source is left
    untouched.
    Nextcloud/Syncthing metadata directories, sync journals, and partial
    transfers are skipped by both passes.
    Missing tools (oxipng, jpegoptim, cwebp, gifsicle) are installed via
    winget on first use and degrade to a warning when unavailable; ffmpeg and
    ffprobe are required.
.PARAMETER Path
    Folder to scan recursively. If omitted, a folder picker dialog opens.
.PARAMETER Help
    Show this help and exit. Aliased to -h; a literal "-h", "--help", or "/?"
    typed as the first argument is also recognized.
.PARAMETER BackupPath
    Folder that originals are mirrored into before lossy or destructive work.
    Defaults to "$env:USERPROFILE\Pictures\optimize-media-bak". Must not sit inside -Path: a
    backup inside a synced folder is uploaded and doubles server storage.
.PARAMETER SkipImages
    Skip the image compression pass.
.PARAMETER SkipVideo
    Skip the video re-encode pass.
.PARAMETER ImageQuality
    JPEG/WEBP quality factor, 0 (worst) to 100 (best). Default 90. PNG and GIF
    are always lossless regardless of this value.
.PARAMETER OxipngLevel
    oxipng optimization level, 0 (fastest) to 6 (slowest). Default 6; lossless
    either way, level 6 just spends more time finding a smaller result.
.PARAMETER MaxDimension
    Cap the longer side of JPEG/WEBP/PNG/AVIF images to this many pixels
    before compressing, preserving aspect ratio and never upscaling. Default
    0 disables resizing. Requires ImageMagick (installed via winget on first
    use). GIF and HEIC/HEIF are excluded (animation risk; HEIC is already
    left untouched, see above).
.PARAMETER StripMetadata
    Pass -s to jpegoptim, discarding EXIF, GPS, and orientation. Off by
    default because that is silent data loss on a photo library.
.PARAMETER ConvertToWebp
    Convert JPEG and PNG to WebP instead of compressing them in their source
    format. JPEG uses cwebp -q<ImageQuality> -m 6 -af -sharp_yuv (lossy,
    -sharp_yuv avoids chroma bleed on edges/text). PNG uses cwebp -lossless
    -z 9 (no further quality loss). Both keep all metadata (EXIF, GPS, ICC,
    XMP). The result replaces the source only when smaller (see -Force); on
    success the original is moved into -BackupPath, since the extension
    changes. GIF, WEBP, AVIF, and HEIC/HEIF are unaffected.
.PARAMETER VideoQuality
    Quality target: libx265 crf, or the NVENC constant-quality value. 0
    (best/largest) to 51 (worst/smallest). Default 28. NVENC's -cq at the
    same number is visibly softer than x265's -crf; there is no separate
    knob for that.
.PARAMETER AudioBitrate
    Opus audio bitrate. Default 128k.
.PARAMETER Encoder
    Auto (default; NVENC when ffmpeg reports hevc_nvenc, else x265), NVENC, or
    x265.
.PARAMETER Denoise
    Apply hqdn3d before encoding. Helps already-compressed mobile clips
    actually shrink; lossy, off by default.
.PARAMETER MaxVideoDimension
    Cap the longer side of the video to this many pixels before encoding,
    preserving aspect ratio and never upscaling. Default 0 disables. Lossy,
    off by default.
.PARAMETER ThreadCount
    Number of videos ffzap encodes concurrently. Default 4. ffzap is used as an
    ffmpeg wrapper for the video pass so multiple files encode in parallel
    instead of one at a time.
.PARAMETER KeepOriginals
    Keep the source video in place after a successful encode instead of moving
    it into -BackupPath. The folder will not shrink.
.PARAMETER Force
    Keep optimized images even if not smaller than the original, overwrite
    existing video outputs, and re-encode videos that are already HEVC or AV1.
.EXAMPLE
    .\optimize-media.ps1 -Path 'D:\Pictures'
    Compress images and re-encode videos, mirroring originals into
    "$env:USERPROFILE\Pictures\optimize-media-bak".
.EXAMPLE
    .\optimize-media.ps1 -Path 'D:\Nextcloud\Photos' -BackupPath 'E:\media-bak' -Encoder x265
    Force CPU encoding and keep the backups off the synced volume entirely.
.EXAMPLE
    .\optimize-media.ps1 -Path 'D:\Pictures' -MaxDimension 1920
    Downscale oversized stills to 1920px on the longer side, then compress.
.EXAMPLE
    .\optimize-media.ps1 -Path 'D:\Pictures' -SkipVideo -ConvertToWebp -ImageQuality 82
    Convert JPEG/PNG to WebP at quality 82, skipping the video pass.
.EXAMPLE
    .\optimize-media.ps1 -Help
    Show full help and exit.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param (
    [Parameter(Position = 0)]
    [string]$Path,
    [Alias('h')]
    [switch]$Help,
    [string]$BackupPath = (Join-Path -Path $env:USERPROFILE -ChildPath 'Pictures\optimize-media-bak'),
    [switch]$SkipImages,
    [switch]$SkipVideo,
    [ValidateRange(0, 100)]
    [int]$ImageQuality = 90,
    [ValidateRange(0, 6)]
    [int]$OxipngLevel = 6,
    [ValidateRange(0, 20000)]
    [int]$MaxDimension = 0,
    [switch]$StripMetadata,
    [switch]$ConvertToWebp,
    [ValidateRange(0, 51)]
    [int]$VideoQuality = 28,
    [string]$AudioBitrate = '128k',
    [ValidateSet('Auto', 'NVENC', 'x265')]
    [string]$Encoder = 'Auto',
    [switch]$Denoise,
    [ValidateRange(0, 20000)]
    [int]$MaxVideoDimension = 0,
    [ValidateRange(1, 32)]
    [int]$ThreadCount = 4,
    [switch]$KeepOriginals,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Common.ps1"

# PowerShell has no native double-dash flag syntax, so a literal "--help" or
# "-h" typed by habit lands in the positional -Path argument instead of
# binding to a parameter; check for it explicitly alongside -Help/-h.
if ($Help -or $Path -in @('-h', '--help', '/?')) {
    $width = 120
    try {
        $width = $Host.UI.RawUI.WindowSize.Width
    }
    catch {
        Write-Verbose "Could not determine console width; using default of $width."
    }
    (Get-Help -Full -Name $PSCommandPath | Out-String -Width $width).TrimEnd() -replace '(\r?\n[ \t]*){3,}', "`n`n"
    return
}

$videoExtensions = @('mp4', 'mkv', 'avi', 'mov', 'webm', 'm4v', 'wmv', 'flv', 'mpg', 'mpeg', 'ts', 'm2ts')
$imageExtensions = @('png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'tif', 'tiff', 'heic', 'heif', 'avif')

# Nextcloud/Syncthing metadata, sync journals, and partial transfers. Optimizing a
# version history or a half-transferred file corrupts what the sync client expects.
$excludeRegex = '(?i)[\\/](files_versions|files_trashbin|\.nextcloud|\.stfolder|\.stversions|' +
    '\.thumbnails|thumbnails|\.cache)[\\/]|[\\/]\.sync_[^\\/]*\.db$|[\\/]Thumbs\.db$|\.(part|partial)$'

# How many paths to hand a single oxipng/jpegoptim invocation. Both accept many files
# per run; ~200 keeps the command line well under the Windows 32k limit.
$batchSize = 200

# libx265 tuning, applied to the x265 path only (hevc_nvenc rejects -x265-params and
# -preset slow). -tune ssim (set at the call site) sets aq-mode=2 and psy-rd/psy-rdoq=0;
# ffmpeg applies -tune before -x265-params and lets the latter override, so this list must
# not re-specify any psy-oriented option or it silently cancels the tune. What remains is
# policy (closed 2-5s GOP for seeking/streaming at up to 60fps) plus tune-neutral
# compression gains layered on top of -preset slow's own table.
$x265Params = 'open-gop=0:min-keyint=24:bframes=8:ref=5:rc-lookahead=40'


function Get-MediaFile {
    <#
    .SYNOPSIS
        Streams files under a folder whose extension is in the given set.
    .DESCRIPTION
        Uses Directory.EnumerateFiles so nothing is materialized up front, and skips
        sync metadata via $excludeRegex. Get-ChildItem -Recurse | Where-Object builds
        a FileInfo for every file in the tree first, which is the slow part at
        library scale.
    .PARAMETER TargetPath
        Folder to scan recursively.
    .PARAMETER Extension
        Extensions to keep, with or without a leading dot.
    .EXAMPLE
        Get-MediaFile -TargetPath 'D:\Pictures' -Extension 'png', 'jpg'
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][string[]]$Extension
    )
    process {
        $wanted = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($ext in $Extension) {
            $null = $wanted.Add('.' + $ext.TrimStart('.'))
        }
        $enumerated = [System.IO.Directory]::EnumerateFiles($TargetPath, '*',
            [System.IO.SearchOption]::AllDirectories)
        foreach ($file in $enumerated) {
            if (-not $wanted.Contains([System.IO.Path]::GetExtension($file))) { continue }
            if ($file -match $excludeRegex) { continue }
            [System.IO.FileInfo]::new($file)
        }
    }
}


function Backup-MediaFile {
    <#
    .SYNOPSIS
        Mirrors a file into the backup folder at its relative subpath.
    .PARAMETER FullName
        File to back up.
    .PARAMETER TargetPath
        Root of the scan, used to compute the relative subpath.
    .PARAMETER BackupPath
        Root of the backup mirror.
    .PARAMETER Move
        Move the file instead of copying it (used after a validated video encode
        and after a format conversion, where the original is no longer wanted).
    .EXAMPLE
        Backup-MediaFile -FullName $file.FullName -TargetPath $root -BackupPath $bak
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][string]$FullName,
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][string]$BackupPath,
        [switch]$Move
    )
    process {
        $relative = $FullName.Substring($TargetPath.Length).TrimStart('\', '/')
        $destination = Join-Path -Path $BackupPath -ChildPath $relative
        $verb = if ($Move) { 'Move original into backup' } else { 'Back up original' }
        if ((-not $Move) -and (Test-Path -LiteralPath $destination)) { return $true }
        if (-not $PSCmdlet.ShouldProcess($destination, $verb)) { return $false }
        Ensure-Directory -Path (Split-Path -Parent $destination)
        if ($Move) {
            Move-Item -LiteralPath $FullName -Destination $destination -Force
        }
        else {
            Copy-Item -LiteralPath $FullName -Destination $destination
        }
        $true
    }
}


function Invoke-BatchTool {
    <#
    .SYNOPSIS
        Runs a file-list tool over the given paths in chunks, returning bytes saved.
    .PARAMETER Tool
        Executable path.
    .PARAMETER ToolArgument
        Arguments placed before the file paths.
    .PARAMETER FilePath
        Files to process in place.
    .PARAMETER Activity
        Write-Progress activity label.
    .EXAMPLE
        Invoke-BatchTool -Tool $oxipng -ToolArgument @('-o', '4') -FilePath $pngs -Activity 'PNG'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([long])]
    param(
        [Parameter(Mandatory)][string]$Tool,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ToolArgument,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$FilePath,
        [Parameter(Mandatory)][string]$Activity
    )
    process {
        [long]$saved = 0
        if ($FilePath.Count -eq 0) { return $saved }

        for ($offset = 0; $offset -lt $FilePath.Count; $offset += $batchSize) {
            $chunk = @($FilePath[$offset..([Math]::Min($offset + $batchSize, $FilePath.Count) - 1)])
            $done = $offset + $chunk.Count
            Write-Progress -Activity $Activity -Status "$done/$($FilePath.Count)" `
                -PercentComplete (($done / $FilePath.Count) * 100)
            if (-not $PSCmdlet.ShouldProcess("$($chunk.Count) file(s)", $Activity)) { continue }

            [long]$before = 0
            foreach ($file in $chunk) {
                $item = Get-Item -LiteralPath $file -ErrorAction SilentlyContinue
                if ($item) { $before += $item.Length }
            }
            # Route the tool's stdout through Write-Host: left in the success stream it
            # would be folded into this function's return value. stderr stays unredirected
            # on purpose - 2>&1 under $ErrorActionPreference = 'Stop' turns a native tool's
            # normal stderr chatter into a terminating NativeCommandError on PowerShell 5.1.
            & $Tool @ToolArgument @chunk | ForEach-Object { Write-Host $_ }
            [long]$after = 0
            foreach ($file in $chunk) {
                $item = Get-Item -LiteralPath $file -ErrorAction SilentlyContinue
                if ($item) { $after += $item.Length }
            }
            if ($after -lt $before) { $saved += ($before - $after) }
        }
        Write-Progress -Activity $Activity -Completed
        $saved
    }
}


function Invoke-ResizePass {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([long])]
    <#
    .SYNOPSIS
        Downscales oversized raster images in place and returns bytes saved.
    .DESCRIPTION
        Caps the longer side at -MaxDimension using ImageMagick's "WxH>"
        geometry: aspect ratio kept, never upscales, no explicit -quality so
        JPEG reuses its own source quantization tables. Runs before the
        per-format compression passes so they work on the smaller result.
    .PARAMETER FilePath
        Candidate image paths (JPEG/WEBP/PNG/AVIF).
    .PARAMETER MaxDimension
        Cap for the longer side, in pixels.
    .PARAMETER Magick
        ImageMagick "magick" executable path.
    .PARAMETER TargetPath
        Folder scanned, used to compute the backup mirror's relative subpath.
    .PARAMETER BackupPath
        Folder that originals are mirrored into before resizing.
    .EXAMPLE
        Invoke-ResizePass -FilePath $paths -MaxDimension 1920 -Magick $magick `
            -TargetPath $root -BackupPath $bak
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$FilePath,
        [Parameter(Mandatory)][int]$MaxDimension,
        [Parameter(Mandatory)][string]$Magick,
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][string]$BackupPath
    )
    process {
        [long]$saved = 0
        if ($FilePath.Count -eq 0) { return $saved }

        # Batched "%i\t%w\t%h" identify calls, not one process per file: -ping skips the
        # pixel decode, and %i echoes the path exactly as passed so tab-splitting the
        # output can't be confused by paths containing spaces.
        $oversized = [System.Collections.Generic.List[string]]::new()
        for ($offset = 0; $offset -lt $FilePath.Count; $offset += $batchSize) {
            $chunk = @($FilePath[$offset..([Math]::Min($offset + $batchSize, $FilePath.Count) - 1)])
            $done = $offset + $chunk.Count
            Write-Progress -Activity 'Scanning image dimensions' -Status "$done/$($FilePath.Count)" `
                -PercentComplete (($done / $FilePath.Count) * 100)
            $lines = & $Magick identify -ping -format "%i`t%w`t%h`n" -- @chunk
            foreach ($line in $lines) {
                $parts = $line -split "`t"
                if ($parts.Count -lt 3) { continue }
                if ([int]$parts[1] -gt $MaxDimension -or [int]$parts[2] -gt $MaxDimension) {
                    $oversized.Add($parts[0])
                }
            }
        }
        Write-Progress -Activity 'Scanning image dimensions' -Completed
        if ($oversized.Count -eq 0) { return $saved }

        Write-Info "$($oversized.Count) image(s) exceed ${MaxDimension}px on the long side; resizing."
        $toResize = [System.Collections.Generic.List[string]]::new()
        foreach ($file in $oversized) {
            # Resizing is lossy regardless of format, so even a normally-lossless PNG
            # needs the pre-resize original backed up.
            if (Backup-MediaFile -FullName $file -TargetPath $TargetPath -BackupPath $BackupPath) {
                $toResize.Add($file)
            }
        }
        $saved += Invoke-BatchTool -Tool $Magick `
            -ToolArgument @('mogrify', '-resize', "${MaxDimension}x${MaxDimension}>") `
            -FilePath $toResize.ToArray() -Activity 'Resizing images'
        $saved
    }
}


function Invoke-WebpConvertPass {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([long])]
    <#
    .SYNOPSIS
        Converts images to WebP, replacing the source, and returns bytes saved.
    .DESCRIPTION
        cwebp handles one file per invocation. JPEG sources use a lossy
        -q<Quality> pass with -sharp_yuv (avoids chroma bleed on edges/text);
        PNG sources use -lossless -z 9, since a lossy re-encode of an
        already-lossless source is the wrong tradeoff. The extension
        changes, so on success the source is moved into -BackupPath rather
        than replaced in place.

        cwebp's own -metadata all silently keeps only the ICC profile on
        Windows builds ("only ICC profile extraction is currently supported
        on this platform") and drops EXIF/XMP - so EXIF (capture date, GPS,
        orientation) is copied in separately afterward with exiftool
        -TagsFromFile, when exiftool is available. Without exiftool, the
        WebP keeps ICC only and a warning is written once.
    .PARAMETER FilePath
        Candidate image paths (JPEG or PNG, per -Lossless).
    .PARAMETER Quality
        cwebp quality factor, used only when -Lossless is $false.
    .PARAMETER Lossless
        $true for PNG (-lossless -z 9), $false for JPEG (-q<Quality>).
    .PARAMETER Cwebp
        cwebp executable path.
    .PARAMETER Exiftool
        exiftool executable path, or $null/empty to skip EXIF/XMP copying.
    .PARAMETER TargetPath
        Folder scanned, used to compute the backup mirror's relative subpath.
    .PARAMETER BackupPath
        Folder that originals are mirrored into before conversion.
    .PARAMETER Force
        Keep the WebP result even if not smaller than the source.
    .EXAMPLE
        Invoke-WebpConvertPass -FilePath $jpegs -Quality 82 -Lossless $false `
            -Cwebp $cwebp -Exiftool $exiftool -TargetPath $root -BackupPath $bak
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$FilePath,
        [Parameter(Mandatory)][int]$Quality,
        [Parameter(Mandatory)][bool]$Lossless,
        [Parameter(Mandatory)][string]$Cwebp,
        [AllowEmptyString()][string]$Exiftool,
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][string]$BackupPath,
        [bool]$Force
    )
    process {
        [long]$saved = 0
        if ($FilePath.Count -eq 0) { return $saved }

        $cwebpArgs = if ($Lossless) { @('-lossless', '-z', '9') } else { @('-q', "$Quality", '-af', '-sharp_yuv') }
        $cwebpArgs += @('-metadata', 'all', '-mt', '-quiet')

        # ponytail: one process per file, -m 6 -af is slow - a runspace pool is the upgrade
        # path if a multi-thousand-file library makes this pass a bottleneck.
        $i = 0
        foreach ($path in $FilePath) {
            $i++
            if ($i % 25 -eq 0 -or $i -eq $FilePath.Count) {
                Write-Progress -Activity 'Converting to WebP' -Status "$i/$($FilePath.Count)" `
                    -PercentComplete (($i / $FilePath.Count) * 100)
            }
            $file = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
            if (-not $file) { continue }
            $output = Join-Path -Path $file.DirectoryName -ChildPath "$($file.BaseName).webp"
            if ((Test-Path -LiteralPath $output) -and -not $Force) {
                Write-Verbose "Skipping $($file.Name): $output already exists."
                continue
            }
            if (-not $PSCmdlet.ShouldProcess($file.FullName, 'Convert to WebP (cwebp)')) { continue }

            $before = $file.Length
            $tmp = "$output.tmp"
            & $Cwebp @cwebpArgs $file.FullName -o $tmp
            $tmpItem = Get-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
            if (-not $tmpItem -or $tmpItem.Length -eq 0) {
                Write-Warning "  [FAIL] convert $($file.Name)"
                if ($tmpItem) { Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue }
                continue
            }
            if (-not $Force -and $tmpItem.Length -ge $before) {
                Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
                continue
            }

            # cwebp -metadata all keeps only the ICC profile on Windows; copy EXIF/XMP
            # (capture date, GPS, orientation) in separately so the archive doesn't lose them.
            if ($Exiftool) {
                & $Exiftool -TagsFromFile $file.FullName -exif:all -xmp:all -iptc:all `
                    -overwrite_original -quiet -m $tmp
                $tmpItem = Get-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
            }

            Move-Item -LiteralPath $tmp -Destination $output -Force
            if (Backup-MediaFile -FullName $file.FullName -TargetPath $TargetPath -BackupPath $BackupPath -Move) {
                $saved += $before
            }
            $saved -= $tmpItem.Length
        }
        Write-Progress -Activity 'Converting to WebP' -Completed
        $saved
    }
}


function Invoke-ImagePass {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([long])]
    <#
    .SYNOPSIS
        Compresses images in place and returns bytes saved.
    .PARAMETER TargetPath
        Folder to scan recursively.
    .PARAMETER Quality
        JPEG/WEBP quality factor.
    .PARAMETER OxipngLevel
        oxipng optimization level.
    .PARAMETER MaxDimension
        Cap for the longer side, in pixels. 0 disables resizing.
    .PARAMETER BackupPath
        Folder to mirror originals into before lossy or destructive work.
    .PARAMETER Ffmpeg
        ffmpeg path, used for the BMP/TIFF to PNG conversion.
    .PARAMETER StripMetadata
        Let jpegoptim discard EXIF/GPS/orientation.
    .PARAMETER ConvertToWebp
        Convert JPEG/PNG to WebP instead of compressing them in place; see
        the script-level -ConvertToWebp help for the flags used.
    .PARAMETER Force
        Keep the optimized result even if not smaller than the original.
    #>
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][int]$Quality,
        [Parameter(Mandatory)][int]$OxipngLevel,
        [Parameter(Mandatory)][int]$MaxDimension,
        [Parameter(Mandatory)][string]$BackupPath,
        [Parameter(Mandatory)][string]$Ffmpeg,
        [bool]$StripMetadata,
        [bool]$ConvertToWebp,
        [bool]$Force
    )
    process {
        $files = @(Get-MediaFile -TargetPath $TargetPath -Extension $imageExtensions)
        if ($files.Count -eq 0) {
            Write-Host 'No image files found.' -ForegroundColor Yellow
            return 0L
        }

        $byKind = @{}
        foreach ($file in $files) {
            $kind = switch ($file.Extension.ToLowerInvariant()) {
                '.png' { 'png' }
                '.jpg' { 'jpeg' }
                '.jpeg' { 'jpeg' }
                '.webp' { 'webp' }
                '.gif' { 'gif' }
                '.bmp' { 'convert' }
                '.tif' { 'convert' }
                '.tiff' { 'convert' }
                '.avif' { 'avif' }
                default { 'heic' }
            }
            if (-not $byKind.ContainsKey($kind)) {
                $byKind[$kind] = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
            }
            $byKind[$kind].Add($file)
        }

        Write-Phase "Optimizing $($files.Count) image(s) in $TargetPath"

        if ($byKind.ContainsKey('heic')) {
            [long]$heicBytes = 0
            foreach ($file in $byKind['heic']) { $heicBytes += $file.Length }
            Write-Info ("$($byKind['heic'].Count) HEIC/HEIF file(s) left untouched " +
                "($(Format-Size $heicBytes)): already HEVC-compressed.")
        }

        if ($byKind.ContainsKey('avif')) {
            [long]$avifBytes = 0
            foreach ($file in $byKind['avif']) { $avifBytes += $file.Length }
            Write-Info ("$($byKind['avif'].Count) AVIF file(s) resized only if oversized " +
                "($(Format-Size $avifBytes)): no AVIF re-encoder wired up here.")
        }

        [long]$saved = 0
        $pngPaths = [System.Collections.Generic.List[string]]::new()
        if ($byKind.ContainsKey('png')) {
            foreach ($file in $byKind['png']) { $pngPaths.Add($file.FullName) }
        }

        # BMP/TIFF first: the PNGs they produce join the oxipng batch below.
        if ($byKind.ContainsKey('convert')) {
            $convertible = $byKind['convert']
            $i = 0
            foreach ($file in $convertible) {
                $i++
                if ($i % 25 -eq 0 -or $i -eq $convertible.Count) {
                    Write-Progress -Activity 'Converting BMP/TIFF to PNG' -Status "$i/$($convertible.Count)" `
                        -PercentComplete (($i / $convertible.Count) * 100)
                }
                $output = Join-Path -Path $file.DirectoryName -ChildPath "$($file.BaseName).png"
                if ((Test-Path -LiteralPath $output) -and -not $Force) {
                    Write-Verbose "Skipping $($file.Name): $output already exists."
                    continue
                }
                if (-not $PSCmdlet.ShouldProcess($file.FullName, 'Convert to PNG (ffmpeg)')) { continue }
                $before = $file.Length
                & $Ffmpeg -y -loglevel error -i $file.FullName $output
                $outputItem = Get-Item -LiteralPath $output -ErrorAction SilentlyContinue
                if ($LASTEXITCODE -ne 0 -or -not $outputItem -or $outputItem.Length -eq 0) {
                    Write-Warning "  [FAIL] convert $($file.Name)"
                    if ($outputItem) { Remove-Item -LiteralPath $output -ErrorAction SilentlyContinue }
                    continue
                }
                # The extension changes, so the source is not replaced in place: move it out.
                if (Backup-MediaFile -FullName $file.FullName -TargetPath $TargetPath -BackupPath $BackupPath -Move) {
                    $saved += $before
                }
                $saved -= $outputItem.Length
                $pngPaths.Add($output)
            }
            Write-Progress -Activity 'Converting BMP/TIFF to PNG' -Completed
        }

        if ($MaxDimension -gt 0) {
            $magick = Resolve-OrInstallTool -Name 'magick' -WingetId 'ImageMagick.ImageMagick' -Optional
            if (-not $magick) {
                Write-Warning 'ImageMagick (magick) not found; skipping resize pass.'
            }
            else {
                $resizeCandidates = [System.Collections.Generic.List[string]]::new()
                foreach ($kind in 'jpeg', 'webp', 'avif') {
                    if ($byKind.ContainsKey($kind)) {
                        foreach ($file in $byKind[$kind]) { $resizeCandidates.Add($file.FullName) }
                    }
                }
                foreach ($path in $pngPaths) { $resizeCandidates.Add($path) }
                $saved += Invoke-ResizePass -FilePath $resizeCandidates.ToArray() -MaxDimension $MaxDimension `
                    -Magick $magick -TargetPath $TargetPath -BackupPath $BackupPath
            }
        }

        if ($ConvertToWebp) {
            $cwebpConvert = Resolve-OrInstallTool -Name 'cwebp' -WingetId 'Google.Libwebp' -Optional
            if (-not $cwebpConvert) {
                Write-Warning 'cwebp not found; JPEG/PNG files left unconverted.'
            }
            else {
                $exiftool = Resolve-OrInstallTool -Name 'exiftool' -WingetId 'OliverBetz.ExifTool' -Optional
                if (-not $exiftool) {
                    Write-Warning ('exiftool not found; WebP output keeps only the ICC profile - ' +
                        'EXIF (capture date, GPS, orientation) and XMP will be lost.')
                }
                $saved += Invoke-WebpConvertPass -FilePath $pngPaths.ToArray() -Quality $Quality -Lossless $true `
                    -Cwebp $cwebpConvert -Exiftool $exiftool -TargetPath $TargetPath -BackupPath $BackupPath -Force:$Force
                if ($byKind.ContainsKey('jpeg')) {
                    $jpegPaths = @($byKind['jpeg'] | ForEach-Object { $_.FullName })
                    $saved += Invoke-WebpConvertPass -FilePath $jpegPaths -Quality $Quality -Lossless $false `
                        -Cwebp $cwebpConvert -Exiftool $exiftool -TargetPath $TargetPath -BackupPath $BackupPath `
                        -Force:$Force
                }
            }
        }
        else {
            $oxipng = Resolve-OrInstallTool -Name 'oxipng' -WingetId 'Shssoichiro.Oxipng' -Optional
            if ($pngPaths.Count -gt 0) {
                if (-not $oxipng) {
                    Write-Warning 'oxipng not found; PNG files left uncompressed.'
                }
                else {
                    # Lossless, and oxipng will not grow a file without --force, so no backup.
                    $oxipngArgs = @('-o', "$OxipngLevel", '--strip', 'safe')
                    if ($Force) { $oxipngArgs += '--force' }
                    $saved += Invoke-BatchTool -Tool $oxipng -ToolArgument $oxipngArgs `
                        -FilePath $pngPaths.ToArray() -Activity 'Optimizing PNG'
                }
            }

            if ($byKind.ContainsKey('jpeg')) {
                $jpegoptim = Resolve-OrInstallTool -Name 'jpegoptim' -WingetId 'TimoKokkonen.Jpegoptim' -Optional
                if (-not $jpegoptim) {
                    Write-Warning 'jpegoptim not found; JPEG files left uncompressed.'
                }
                else {
                    $jpegPaths = [System.Collections.Generic.List[string]]::new()
                    foreach ($file in $byKind['jpeg']) {
                        # -m<quality> is lossy, so the original goes to the backup mirror first.
                        if (Backup-MediaFile -FullName $file.FullName -TargetPath $TargetPath -BackupPath $BackupPath) {
                            $jpegPaths.Add($file.FullName)
                        }
                    }
                    $jpegoptimArgs = @("-m$Quality")
                    if ($StripMetadata) { $jpegoptimArgs += '-s' }
                    if ($Force) { $jpegoptimArgs += '-f' }
                    $saved += Invoke-BatchTool -Tool $jpegoptim -ToolArgument $jpegoptimArgs `
                        -FilePath $jpegPaths.ToArray() -Activity 'Optimizing JPEG'
                }
            }
        }

        if ($byKind.ContainsKey('gif')) {
            # gifsicle is in neither the winget community repo nor scoop's main bucket, so
            # there is no -WingetId to give: it installs only if the scoop extras bucket is
            # already present, and otherwise degrades to a warning.
            $gifsicle = Resolve-OrInstallTool -Name 'gifsicle' -ScoopPackage 'extras/gifsicle' -Optional
            if (-not $gifsicle) {
                Write-Warning ('gifsicle not found; GIF files left uncompressed. ' +
                    'Install with: scoop bucket add extras; scoop install gifsicle')
            }
            else {
                # -O3 -b is lossless and rewrites in place, so no backup is needed.
                $gifPaths = [System.Collections.Generic.List[string]]::new()
                foreach ($file in $byKind['gif']) { $gifPaths.Add($file.FullName) }
                $saved += Invoke-BatchTool -Tool $gifsicle -ToolArgument @('-O3', '-b') `
                    -FilePath $gifPaths.ToArray() -Activity 'Optimizing GIF'
            }
        }

        if ($byKind.ContainsKey('webp') -and -not $ConvertToWebp) {
            # Skipped under -ConvertToWebp: re-compressing existing WebP at -ImageQuality would be
            # pure generation loss when WebP is already the target format.
            $cwebp = Resolve-OrInstallTool -Name 'cwebp' -WingetId 'Google.Libwebp' -Optional
            if (-not $cwebp) {
                Write-Warning 'cwebp not found; WEBP files left uncompressed.'
            }
            else {
                # cwebp handles one file per invocation, so this pass stays a loop.
                $webpFiles = $byKind['webp']
                $i = 0
                foreach ($file in $webpFiles) {
                    $i++
                    if ($i % 25 -eq 0 -or $i -eq $webpFiles.Count) {
                        Write-Progress -Activity 'Optimizing WEBP' -Status "$i/$($webpFiles.Count)" `
                            -PercentComplete (($i / $webpFiles.Count) * 100)
                    }
                    if (-not $PSCmdlet.ShouldProcess($file.FullName, 'Optimize WEBP (cwebp)')) { continue }
                    if (-not (Backup-MediaFile -FullName $file.FullName -TargetPath $TargetPath -BackupPath $BackupPath)) {
                        continue
                    }
                    $before = $file.Length
                    $tmp = "$($file.FullName).tmp.webp"
                    & $cwebp -quiet -q $Quality $file.FullName -o $tmp
                    $tmpItem = Get-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
                    if (-not $tmpItem) { continue }
                    if ($Force -or $tmpItem.Length -lt $before) {
                        Move-Item -LiteralPath $tmp -Destination $file.FullName -Force
                        if ($tmpItem.Length -lt $before) { $saved += ($before - $tmpItem.Length) }
                    }
                    else {
                        Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
                    }
                }
                Write-Progress -Activity 'Optimizing WEBP' -Completed
            }
        }

        $saved
    }
}


function Resolve-HevcEncoder {
    <#
    .SYNOPSIS
        Picks the H.265 encoder, probing ffmpeg for hevc_nvenc when set to Auto.
    .PARAMETER Ffmpeg
        ffmpeg path.
    .PARAMETER Preference
        Auto, NVENC, or x265.
    .EXAMPLE
        Resolve-HevcEncoder -Ffmpeg $ffmpeg -Preference 'Auto'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Ffmpeg,
        [Parameter(Mandatory)][ValidateSet('Auto', 'NVENC', 'x265')][string]$Preference
    )
    process {
        if ($Preference -ne 'Auto') { return $Preference }
        # ffmpeg writes the encoder list to stdout, so this needs no stderr redirect.
        $encoders = @(& $Ffmpeg -hide_banner -encoders)
        if ($encoders -match 'hevc_nvenc') { 'NVENC' } else { 'x265' }
    }
}


function Invoke-VideoPass {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    <#
    .SYNOPSIS
        Re-encodes videos to H.265/Opus MP4, replacing validated sources.
    .DESCRIPTION
        Builds the list of candidates (skipping already-HEVC/AV1 sources and
        existing non-empty outputs), hands the whole batch to ffzap so
        -ThreadCount files encode concurrently, then validates each output
        (exists, non-empty, smaller than source, readable by ffprobe) before
        moving the source into the backup mirror.
    .PARAMETER TargetPath
        Folder to scan recursively.
    .PARAMETER Ffmpeg
        ffmpeg path. Its folder is added to PATH for this process so ffzap,
        which shells out to "ffmpeg" by name, can find it.
    .PARAMETER Ffprobe
        ffprobe path, used for the source codec check and output validation.
    .PARAMETER Ffzap
        ffzap path, used as the ffmpeg wrapper that parallelizes the encode.
    .PARAMETER EncoderArgs
        Video-codec arguments for the selected encoder.
    .PARAMETER VideoFilterArgs
        Optional -vf argument pair (denoise/scale). Empty array when neither
        -Denoise nor -MaxVideoDimension is requested.
    .PARAMETER VideoProfile
        Object with Suffix (output filename suffix, e.g. ".h265.mp4") and
        MuxArgs (container-specific mux flags, e.g. -movflags +faststart).
    .PARAMETER AudioBitrate
        Opus audio bitrate.
    .PARAMETER ThreadCount
        Number of files ffzap encodes concurrently.
    .PARAMETER BackupPath
        Folder that validated sources are moved into.
    .PARAMETER KeepOriginals
        Leave the source in place instead of moving it into the backup mirror.
    .PARAMETER Force
        Overwrite existing outputs and re-encode HEVC/AV1 sources.
    #>
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][string]$Ffmpeg,
        [Parameter(Mandatory)][string]$Ffprobe,
        [Parameter(Mandatory)][string]$Ffzap,
        [Parameter(Mandatory)][string[]]$EncoderArgs,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$VideoFilterArgs,
        [Parameter(Mandatory)][PSCustomObject]$VideoProfile,
        [Parameter(Mandatory)][string]$AudioBitrate,
        [Parameter(Mandatory)][int]$ThreadCount,
        [Parameter(Mandatory)][string]$BackupPath,
        [bool]$KeepOriginals,
        [bool]$Force
    )
    process {
        $files = @(Get-MediaFile -TargetPath $TargetPath -Extension $videoExtensions |
                Where-Object { $_.Name -notmatch '(?i)\.(h265|av1|vp9)\.[^.]+$' })

        $result = [PSCustomObject]@{ Encoded = 0; Skipped = 0; Errors = 0; NoGain = 0; Reclaimed = 0L }
        if ($files.Count -eq 0) {
            Write-Host 'No video files found.' -ForegroundColor Yellow
            return $result
        }

        Write-Phase "Re-encoding $($files.Count) video(s) in $TargetPath"

        # Phase A: decide which files actually need encoding.
        $batch = [System.Collections.Generic.List[PSCustomObject]]::new()
        $i = 0
        foreach ($file in $files) {
            $i++
            if ($i % 25 -eq 0 -or $i -eq $files.Count) {
                Write-Progress -Activity 'Scanning video codecs' -Status "$i/$($files.Count)" `
                    -PercentComplete (($i / $files.Count) * 100)
            }

            # Re-encoding HEVC/AV1 costs quality and usually saves nothing.
            $codec = (& $Ffprobe -v error -select_streams v:0 -show_entries stream=codec_name `
                    -of default=noprint_wrappers=1:nokey=1 $file.FullName | Select-Object -First 1)
            if (-not $Force -and $codec -in 'hevc', 'av1') {
                Write-Verbose "Skipping $($file.Name): already $codec."
                $result.Skipped++
                continue
            }

            $output = Join-Path -Path $file.DirectoryName -ChildPath "$($file.BaseName)$($VideoProfile.Suffix)"
            $existingOutput = Get-Item -LiteralPath $output -ErrorAction SilentlyContinue
            if ($existingOutput -and $existingOutput.Length -gt 0 -and -not $Force) {
                Write-Verbose "Skipping $($file.Name): output exists (use -Force to overwrite)"
                $result.Skipped++
                continue
            }

            $batch.Add([PSCustomObject]@{ Source = $file.FullName; Output = $output; Length = $file.Length })
        }
        Write-Progress -Activity 'Scanning video codecs' -Completed

        if ($batch.Count -eq 0) {
            Write-Progress -Activity 'Re-encoding videos' -Completed
            return $result
        }
        if (-not $PSCmdlet.ShouldProcess("$($batch.Count) video(s)", 'Re-encode to H.265/Opus')) {
            return $result
        }

        # Phase B: one ffzap call for the whole batch. ffzap shells out to "ffmpeg" by name.
        $ffmpegDir = Split-Path -Parent $Ffmpeg
        if ($env:PATH -notlike "*$ffmpegDir*") { $env:PATH = "$ffmpegDir;$env:PATH" }

        $listFile = [System.IO.Path]::GetTempFileName()
        try {
            # WriteAllLines is UTF-8 without BOM; Set-Content -Encoding UTF8 on PS 5.1 prepends
            # a BOM that ffzap would read as part of the first path.
            [System.IO.File]::WriteAllLines($listFile, [string[]]$batch.Source)
            # -nostdin: ffzap runs -ThreadCount ffmpegs at once, and without it they contend
            # for stdin and can block on an interactive prompt. -sn drops subtitle streams,
            # which the mp4 muxer can otherwise fail on. Overwrite/-y is left to ffzap's own
            # --overwrite flag below rather than hardcoded, so -Force still gates it.
            $ffmpegOptions = (@('-hide_banner', '-nostdin', '-loglevel', 'error', '-sn') +
                $EncoderArgs + $VideoFilterArgs +
                @('-c:a', 'libopus', '-b:a', $AudioBitrate, '-ac', '2') +
                $VideoProfile.MuxArgs) -join ' '
            # {{dir}} expands without a trailing separator, so one must be added explicitly.
            $ffzapArgs = @(
                '--file-list', $listFile, '-t', "$ThreadCount", '--eta',
                '-f', $ffmpegOptions, '-o', "{{dir}}\{{name}}$($VideoProfile.Suffix)"
            )
            if ($Force) { $ffzapArgs += '--overwrite' }
            # Route stdout through Write-Host: left in the success stream, ffzap's per-file
            # progress lines would be folded into this function's PSCustomObject return value.
            & $Ffzap @ffzapArgs | ForEach-Object { Write-Host $_ }
        }
        finally {
            Remove-Item -LiteralPath $listFile -ErrorAction SilentlyContinue
        }

        # Phase C: validate each output and back up the source on success.
        $i = 0
        foreach ($item in $batch) {
            $i++
            if ($i % 25 -eq 0 -or $i -eq $batch.Count) {
                Write-Progress -Activity 'Validating encoded videos' -Status "$i/$($batch.Count)" `
                    -PercentComplete (($i / $batch.Count) * 100)
            }

            $outputItem = Get-Item -LiteralPath $item.Output -ErrorAction SilentlyContinue
            $outputReadable = $false
            if ($outputItem -and $outputItem.Length -gt 0) {
                # A file ffprobe cannot read is not a replacement, however large it is.
                $null = & $Ffprobe -v error -select_streams v:0 -show_entries stream=codec_name `
                    -of default=noprint_wrappers=1:nokey=1 $item.Output
                $outputReadable = ($LASTEXITCODE -eq 0)
            }

            if (-not $outputReadable) {
                Write-Warning "  [FAIL] ($i/$($batch.Count)) $(Split-Path -Leaf $item.Source)"
                if ($outputItem) { Remove-Item -LiteralPath $item.Output -ErrorAction SilentlyContinue }
                $result.Errors++
                continue
            }

            if ($outputItem.Length -ge $item.Length) {
                # Encode succeeded but gained nothing (already-compressed source) - keep the original.
                Write-Verbose "  [ NO GAIN ] ($i/$($batch.Count)) $(Split-Path -Leaf $item.Source)"
                Remove-Item -LiteralPath $item.Output -ErrorAction SilentlyContinue
                $result.NoGain++
                continue
            }

            $result.Encoded++
            $outputName = Split-Path -Leaf $item.Output
            if ($KeepOriginals) {
                Write-Host "  [ OK ] ($i/$($batch.Count)) $outputName (original kept)" -ForegroundColor Green
                continue
            }
            if (Backup-MediaFile -FullName $item.Source -TargetPath $TargetPath -BackupPath $BackupPath -Move) {
                $result.Reclaimed += ($item.Length - $outputItem.Length)
                Write-Host "  [ OK ] ($i/$($batch.Count)) $outputName" -ForegroundColor Green
            }
        }
        Write-Progress -Activity 'Validating encoded videos' -Completed
        $result
    }
}


if (-not $PSBoundParameters.ContainsKey('Path')) {
    $Path = Select-FolderDialog -Description 'Select the folder to optimize'
}

$resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
    throw "Path is not a folder: $resolvedPath"
}

# Resolved without requiring existence: the mirror is created lazily, per file, so that
# a -WhatIf run and a run that touches nothing both leave no empty folder behind.
if ([System.IO.Path]::IsPathRooted($BackupPath)) {
    $resolvedBackupPath = [System.IO.Path]::GetFullPath($BackupPath)
}
else {
    $resolvedBackupPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PWD.Path -ChildPath $BackupPath))
}
$scanRoot = $resolvedPath.TrimEnd('\', '/')
if ($resolvedBackupPath.TrimEnd('\', '/') -eq $scanRoot -or
    $resolvedBackupPath.StartsWith($scanRoot + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase)) {
    throw ("BackupPath '$resolvedBackupPath' is inside the scanned folder '$resolvedPath'. " +
        'In a synced folder (Nextcloud, OneDrive) the backups would be uploaded too, doubling ' +
        'server storage instead of shrinking it. Pass -BackupPath outside the scanned tree.')
}

$ffmpeg = Resolve-OrInstallTool -Name 'ffmpeg' -WingetId 'Gyan.FFmpeg.Shared'

$bytesSaved = 0L
$videoResult = [PSCustomObject]@{ Encoded = 0; Skipped = 0; Errors = 0; NoGain = 0; Reclaimed = 0L }

if (-not $SkipImages) {
    $bytesSaved = Invoke-ImagePass -TargetPath $resolvedPath -Quality $ImageQuality -OxipngLevel $OxipngLevel `
        -MaxDimension $MaxDimension -BackupPath $resolvedBackupPath -Ffmpeg $ffmpeg `
        -StripMetadata:$StripMetadata -ConvertToWebp:$ConvertToWebp -Force:$Force
}

if (-not $SkipVideo) {
    $ffprobe = Resolve-OrInstallTool -Name 'ffprobe' -WingetId 'Gyan.FFmpeg.Shared'
    $ffzap = Resolve-OrInstallTool -Name 'ffzap' -WingetId 'CodeF0x.ffzap'
    $selectedEncoder = Resolve-HevcEncoder -Ffmpeg $ffmpeg -Preference $Encoder
    Write-Info "Video encoder: $selectedEncoder"
    # hevc -> mp4 today; an av1/vp9 encoder path would add entries here (.av1.mkv / .vp9.mkv,
    # mkv takes no -movflags) rather than touching Invoke-VideoPass's naming/mux logic.
    $videoProfile = [PSCustomObject]@{
        Suffix  = '.h265.mp4'
        MuxArgs = @('-movflags', '+faststart')
    }
    # -g 120 (both encoders): a GOP short enough to stay seekable/streamable at any
    # framerate up to 60fps (2.0s @60fps, 4.0s @30fps, 5.0s @24fps) from one shared value.
    if ($selectedEncoder -eq 'NVENC') {
        # hevc_nvenc has no ssim tune (only hq/ll/ull/lossless) and rejects -x265-params.
        $encoderArgs = @(
            '-c:v', 'hevc_nvenc', '-preset', 'p6', '-tune', 'hq', '-rc', 'vbr',
            '-cq', "$VideoQuality", '-b:v', '0', '-pix_fmt', 'p010le', '-tag:v', 'hvc1', '-g', '120'
        )
    }
    else {
        $encoderArgs = @(
            '-c:v', 'libx265', '-preset', 'slow', '-tune', 'ssim', '-crf', "$VideoQuality",
            '-pix_fmt', 'yuv420p10le', '-tag:v', 'hvc1', '-g', '120', '-x265-params', $x265Params
        )
    }

    # Lossy and off by default: the actual lever for shrinking already-compressed mobile
    # clips, but not something to apply to a photo archive without asking.
    $videoFilters = [System.Collections.Generic.List[string]]::new()
    if ($Denoise) { $videoFilters.Add('hqdn3d=1.5:1.5:6:6') }
    if ($MaxVideoDimension -gt 0) {
        $m = $MaxVideoDimension
        $videoFilters.Add("scale=w='if(gte(iw,ih),min($m,iw),-2)':h='if(gte(iw,ih),-2,min($m,ih))'")
    }
    # @() as the sole output of an if/else branch unravels to $null, not an empty array -
    # start from @() and only append, so the "no filters" case stays a real empty array.
    $videoFilterArgs = @()
    if ($videoFilters.Count -gt 0) { $videoFilterArgs = @('-vf', ($videoFilters -join ',')) }

    $videoResult = Invoke-VideoPass -TargetPath $resolvedPath -Ffmpeg $ffmpeg -Ffprobe $ffprobe -Ffzap $ffzap `
        -EncoderArgs $encoderArgs -VideoFilterArgs $videoFilterArgs -VideoProfile $videoProfile `
        -AudioBitrate $AudioBitrate -ThreadCount $ThreadCount `
        -BackupPath $resolvedBackupPath -KeepOriginals:$KeepOriginals -Force:$Force
}

Write-Host ''
if (-not $SkipImages) {
    Write-Host "Image space saved: $(Format-Size $bytesSaved)" -ForegroundColor Green
}
if (-not $SkipVideo) {
    Write-Host ("Videos: $($videoResult.Encoded) encoded, $($videoResult.Skipped) skipped, " +
        "$($videoResult.NoGain) no gain (kept original), $($videoResult.Errors) failed.") -ForegroundColor Green
    if ($KeepOriginals) {
        Write-Host 'Originals kept in place (-KeepOriginals); no video space reclaimed.' -ForegroundColor DarkGray
    }
    else {
        Write-Host "Video space reclaimed: $(Format-Size $videoResult.Reclaimed)" -ForegroundColor Green
    }
    if ($videoResult.Errors -gt 0) {
        Write-Host "$($videoResult.Errors) video file(s) failed to encode." -ForegroundColor Red
    }
}
Write-Host "Originals are in: $resolvedBackupPath" -ForegroundColor DarkGray

Write-Host ''
Write-Host 'Optimization complete.' -ForegroundColor Green

if ($videoResult.Errors -gt 0) {
    exit 1
}
