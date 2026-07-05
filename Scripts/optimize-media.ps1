#Requires -Version 5.1

<#
.SYNOPSIS
    Batch-optimize images and re-encode videos to H.265/Opus.
.DESCRIPTION
    Images (png/jpg/jpeg/webp) are compressed in place:
      - PNG  -> oxipng, lossless. Original is kept unless the result is
        smaller (oxipng's default behavior; see -Force).
      - JPEG -> jpegoptim -m<ImageQuality>. Original is kept unless the
        result is smaller (jpegoptim's default behavior; see -Force).
      - WEBP -> cwebp -q<ImageQuality>. Result size is compared manually and
        the original is kept unless the result is smaller (see -Force).
    Videos are re-encoded to H.265 MKV with stereo Opus audio, preferring
    hevc_nvenc for speed and falling back to libx265 on the CPU. Files
    already named "*.h265.mkv" are treated as prior output and skipped as
    sources. Automatically prefers ffzap for parallel encoding when
    available; falls back to sequential ffmpeg.
    Progress for both passes is shown via Write-Progress.
.PARAMETER Path
    Folder to scan recursively. If omitted, a folder picker dialog opens.
.PARAMETER Help
    Show this help and exit. Aliased to -h; a literal "-h", "--help", or "/?"
    typed as the first argument is also recognized.
.PARAMETER SkipImages
    Skip the image compression pass.
.PARAMETER SkipVideo
    Skip the video re-encode pass.
.PARAMETER ImageQuality
    JPEG/WEBP quality factor, 0 (worst) to 100 (best). Default 90. PNG is
    always lossless regardless of this value.
.PARAMETER VideoEncoder
    Auto (default, prefers hevc_nvenc when an NVIDIA GPU is detected), NVENC,
    or CPU (libx265).
.PARAMETER VideoQuality
    Constant-quality factor for the video encoder (cq for NVENC, crf for
    libx265), 0 (best/largest) to 51 (worst/smallest). Default 23.
.PARAMETER AudioBitrate
    Opus audio bitrate. Default 96k.
.PARAMETER VideoTool
    Auto (default, prefers ffzap when available), FFmpeg, or FFzap.
.PARAMETER Threads
    Parallel jobs passed to ffzap (default: 4). Ignored when using ffmpeg.
.PARAMETER Force
    Keep optimized images even if not smaller than the original, and
    overwrite existing video outputs.
.EXAMPLE
    .\optimize-media.ps1 -Path 'D:\Pictures'
.EXAMPLE
    .\optimize-media.ps1 -Path 'D:\Videos' -SkipImages -VideoEncoder CPU
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
    [switch]$SkipImages,
    [switch]$SkipVideo,
    [ValidateRange(0, 100)]
    [int]$ImageQuality = 90,
    [ValidateSet('Auto', 'NVENC', 'CPU')]
    [string]$VideoEncoder = 'Auto',
    [ValidateRange(0, 51)]
    [int]$VideoQuality = 23,
    [string]$AudioBitrate = '96k',
    [ValidateSet('Auto', 'FFmpeg', 'FFzap')]
    [string]$VideoTool = 'Auto',
    [int]$Threads = 4,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

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


function Select-FolderDialog {
    [CmdletBinding()]
    [OutputType([string])]
    <#
    .SYNOPSIS
        Prompts for a folder via a Windows folder picker dialog.
    #>
    param()
    process {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'Select the folder to optimize'
        $dialog.ShowNewFolderButton = $false
        try {
            if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
                throw 'No folder selected.'
            }
            $dialog.SelectedPath
        }
        finally {
            $dialog.Dispose()
        }
    }
}


function Resolve-Tool {
    [CmdletBinding()]
    [OutputType([string])]
    <#
    .SYNOPSIS
        Resolves an executable's full path from a list of candidate names.
    .PARAMETER Name
        Candidate executable names, tried in order.
    .PARAMETER Optional
        Return $null instead of throwing when no candidate is found.
    #>
    param(
        [Parameter(Mandatory)]
        [string[]]$Name,
        [switch]$Optional
    )
    process {
        foreach ($candidate in $Name) {
            $command = Get-Command -Name $candidate -CommandType Application -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($command) {
                $command.Source
                return
            }
        }
        if ($Optional) {
            return $null
        }
        throw "Required tool not found on PATH (looked for: $($Name -join ', ')). Install it with winget."
    }
}


function Write-Phase {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message)
    process {
        Write-Host ''
        Write-Host "==> $Message" -ForegroundColor Cyan
    }
}


function Resolve-VideoTool {
    [CmdletBinding()]
    [OutputType([string])]
    <#
    .SYNOPSIS
        Picks ffzap or ffmpeg based on preference and availability.
    #>
    param([string]$Preference = 'Auto')
    process {
        if ($Preference -eq 'FFzap' -or ($Preference -eq 'Auto' -and (Get-Command ffzap -ErrorAction SilentlyContinue))) {
            if (-not (Get-Command ffzap -ErrorAction SilentlyContinue)) {
                throw 'ffzap not found in PATH. Install it or use -VideoTool FFmpeg.'
            }
            return 'ffzap'
        }
        if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
            throw 'ffmpeg not found in PATH. Install via: winget install Gyan.FFmpeg.Shared'
        }
        return 'ffmpeg'
    }
}


function Resolve-VideoEncoderArgument {
    [CmdletBinding()]
    [OutputType([string[]])]
    <#
    .SYNOPSIS
        Returns the ffmpeg video-codec arguments for the chosen encoder.
    .PARAMETER Encoder
        Auto, NVENC, or CPU.
    .PARAMETER Quality
        Constant-quality factor (cq for NVENC, crf for libx265).
    #>
    param(
        [string]$Encoder = 'Auto',
        [Parameter(Mandatory)][int]$Quality
    )
    process {
        $useNvenc = switch ($Encoder) {
            'NVENC' { $true }
            'CPU' { $false }
            default { [bool](Get-Command nvidia-smi -ErrorAction SilentlyContinue) }
        }
        if ($useNvenc) {
            Write-Host 'Video encoder : hevc_nvenc (GPU)' -ForegroundColor Cyan
            return @('-c:v', 'hevc_nvenc', '-preset', 'p5', '-cq', "$Quality", '-b:v', '0')
        }
        Write-Host 'Video encoder : libx265 (CPU)' -ForegroundColor Cyan
        return @('-c:v', 'libx265', '-preset', 'medium', '-crf', "$Quality")
    }
}


function Invoke-ImagePass {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([long])]
    <#
    .SYNOPSIS
        Compresses PNG/JPEG/WEBP files in place and returns bytes saved.
    .PARAMETER TargetPath
        Folder to scan recursively.
    .PARAMETER Quality
        JPEG/WEBP quality factor.
    .PARAMETER Force
        Keep the optimized result even if not smaller than the original.
    #>
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][int]$Quality,
        [bool]$Force
    )
    process {
        $oxipng = Resolve-Tool -Name 'oxipng' -Optional
        $jpegoptim = Resolve-Tool -Name 'jpegoptim' -Optional
        $cwebp = Resolve-Tool -Name 'cwebp' -Optional

        if (-not ($oxipng -or $jpegoptim -or $cwebp)) {
            Write-Warning 'No image optimizer found on PATH (oxipng/jpegoptim/cwebp); skipping image pass.'
            return 0L
        }

        $files = @(Get-ChildItem -Path $TargetPath -Recurse -File -Include '*.png', '*.jpg', '*.jpeg', '*.webp')
        if ($files.Count -eq 0) {
            Write-Host 'No image files found.' -ForegroundColor Yellow
            return 0L
        }

        Write-Phase "Optimizing $($files.Count) image(s) in $TargetPath"

        [long]$saved = 0
        $i = 0
        foreach ($file in $files) {
            $i++
            Write-Progress -Activity 'Optimizing images' -Status "$($file.Name) ($i/$($files.Count))" `
                -PercentComplete (($i / $files.Count) * 100)

            $before = $file.Length
            $ext = $file.Extension.ToLowerInvariant()

            switch ($ext) {
                '.png' {
                    if (-not $oxipng) { Write-Verbose "Skipping $($file.Name): oxipng not found."; continue }
                    if (-not $PSCmdlet.ShouldProcess($file.FullName, 'Optimize PNG (oxipng)')) { continue }
                    $cliArgs = @('-o', 'max', '--strip', 'safe')
                    if ($Force) { $cliArgs += '--force' }
                    $cliArgs += $file.FullName
                    & $oxipng @cliArgs 2>&1 | ForEach-Object { Write-Verbose $_ }
                }
                { $_ -in '.jpg', '.jpeg' } {
                    if (-not $jpegoptim) { Write-Verbose "Skipping $($file.Name): jpegoptim not found."; continue }
                    if (-not $PSCmdlet.ShouldProcess($file.FullName, 'Optimize JPEG (jpegoptim)')) { continue }
                    $cliArgs = @('-s', "-m$Quality")
                    if ($Force) { $cliArgs += '-f' }
                    $cliArgs += $file.FullName
                    & $jpegoptim @cliArgs 2>&1 | ForEach-Object { Write-Verbose $_ }
                }
                '.webp' {
                    if (-not $cwebp) { Write-Verbose "Skipping $($file.Name): cwebp not found."; continue }
                    if (-not $PSCmdlet.ShouldProcess($file.FullName, 'Optimize WEBP (cwebp)')) { continue }
                    $tmp = "$($file.FullName).tmp.webp"
                    & $cwebp -quiet -q $Quality $file.FullName -o $tmp 2>&1 | ForEach-Object { Write-Verbose $_ }
                    if (Test-Path -LiteralPath $tmp) {
                        $tmpSize = (Get-Item -LiteralPath $tmp).Length
                        if ($Force -or $tmpSize -lt $before) {
                            Move-Item -LiteralPath $tmp -Destination $file.FullName -Force
                        }
                        else {
                            Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
                        }
                    }
                }
            }

            $after = (Get-Item -LiteralPath $file.FullName -ErrorAction SilentlyContinue).Length
            if ($after -and $after -lt $before) {
                $saved += ($before - $after)
            }
        }
        Write-Progress -Activity 'Optimizing images' -Completed
        return $saved
    }
}


function Invoke-VideoPass {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([int])]
    <#
    .SYNOPSIS
        Re-encodes video files to H.265/Opus MKV and returns the failure count.
    .PARAMETER TargetPath
        Folder to scan recursively.
    .PARAMETER Tool
        'ffzap' or 'ffmpeg'.
    .PARAMETER EncoderArgs
        ffmpeg video-codec arguments from Resolve-VideoEncoderArgument.
    .PARAMETER AudioBitrate
        Opus audio bitrate.
    .PARAMETER Threads
        Parallel jobs passed to ffzap.
    .PARAMETER Force
        Overwrite existing output files.
    #>
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][string]$Tool,
        [Parameter(Mandatory)][string[]]$EncoderArgs,
        [Parameter(Mandatory)][string]$AudioBitrate,
        [Parameter(Mandatory)][int]$Threads,
        [bool]$Force
    )
    process {
        $files = @(Get-ChildItem -Path $TargetPath -Recurse -File | Where-Object {
                ($videoExtensions -contains $_.Extension.TrimStart('.').ToLowerInvariant()) -and
                ($_.Name -notmatch '\.h265\.mkv$')
            })

        if ($files.Count -eq 0) {
            Write-Host 'No video files found.' -ForegroundColor Yellow
            return 0
        }

        Write-Phase "Re-encoding $($files.Count) video(s) in $TargetPath ($Tool)"

        $errors = 0
        $i = 0
        foreach ($file in $files) {
            $i++
            Write-Progress -Activity 'Re-encoding videos' -Status "$($file.Name) ($i/$($files.Count))" `
                -PercentComplete (($i / $files.Count) * 100)

            $output = Join-Path $file.DirectoryName "$($file.BaseName).h265.mkv"

            $existingOutput = Get-Item -LiteralPath $output -ErrorAction SilentlyContinue
            if ($existingOutput -and -not $Force) {
                if ($existingOutput.Length -gt 0) {
                    Write-Verbose "Skipping $($file.Name): output exists (use -Force to overwrite)"
                    continue
                }
                Write-Verbose "Retrying $($file.Name): existing output is empty (prior failure)"
            }

            if (-not $PSCmdlet.ShouldProcess($file.Name, 'Re-encode to H.265/Opus')) { continue }

            if ($Tool -eq 'ffzap') {
                # ffzap writes its status text to stdout, which PowerShell would otherwise fold into
                # this function's captured return value; route it through Write-Host instead.
                $ffArgs = ($EncoderArgs + @('-c:a', 'libopus', '-b:a', $AudioBitrate, '-ac', '2')) -join ' '
                & ffzap -t $Threads --overwrite --eta -i $file.FullName -f $ffArgs -o $output |
                    ForEach-Object { Write-Host $_ }
            }
            else {
                # ffmpeg writes its console output to stderr, which never enters the success stream,
                # so it must stay unredirected here: 2>&1 combined with $ErrorActionPreference = 'Stop'
                # would turn ffmpeg's normal stderr banner into a terminating error.
                $overwriteFlag = if ($Force) { '-y' } else { '-n' }
                & ffmpeg $overwriteFlag -i $file.FullName @EncoderArgs -c:a libopus -b:a $AudioBitrate -ac 2 $output
            }

            $outputOk = ($LASTEXITCODE -eq 0) -and (Test-Path -LiteralPath $output) -and
                ((Get-Item -LiteralPath $output).Length -gt 0)
            if (-not $outputOk) {
                Write-Warning "  [FAIL] $($file.Name)"
                $errors++
            }
            else {
                Write-Host "  [ OK ] $($file.BaseName).h265.mkv" -ForegroundColor Green
            }
        }
        Write-Progress -Activity 'Re-encoding videos' -Completed
        return $errors
    }
}


if (-not $PSBoundParameters.ContainsKey('Path')) {
    $Path = Select-FolderDialog
}

$resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
    throw "Path is not a folder: $resolvedPath"
}

$bytesSaved = 0L
$videoErrors = 0

if (-not $SkipImages) {
    $bytesSaved = Invoke-ImagePass -TargetPath $resolvedPath -Quality $ImageQuality -Force:$Force
}

if (-not $SkipVideo) {
    $tool = Resolve-VideoTool -Preference $VideoTool
    $encoderArgs = Resolve-VideoEncoderArgument -Encoder $VideoEncoder -Quality $VideoQuality
    $videoErrors = Invoke-VideoPass -TargetPath $resolvedPath -Tool $tool -EncoderArgs $encoderArgs `
        -AudioBitrate $AudioBitrate -Threads $Threads -Force:$Force
}

Write-Host ''
if (-not $SkipImages) {
    Write-Host "Image space saved: $(Format-Size $bytesSaved)" -ForegroundColor Green
}
if (-not $SkipVideo -and $videoErrors -gt 0) {
    Write-Host "$videoErrors video file(s) failed to encode." -ForegroundColor Red
}

Write-Host ''
Write-Host 'Optimization complete.' -ForegroundColor Green

if ($videoErrors -gt 0) {
    exit 1
}
