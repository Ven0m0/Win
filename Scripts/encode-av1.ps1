#Requires -Version 5.1
<#
.SYNOPSIS
    Batch-encodes MP4 files to AV1/Opus MKV.
.DESCRIPTION
    Processes all MP4 files in the target directory using SVT-AV1 and libopus.
    Automatically prefers ffzap for parallel processing when available; falls
    back to sequential ffmpeg.
.PARAMETER Path
    Directory containing MP4 files. Defaults to the current directory.
.PARAMETER Encoder
    Force a specific encoder: Auto (default), FFmpeg, or FFzap.
.PARAMETER Threads
    Parallel jobs passed to ffzap (default: 4). Ignored when using ffmpeg.
.PARAMETER Force
    Overwrite existing output files. By default, existing outputs are skipped.
.EXAMPLE
    .\encode-av1.ps1
.EXAMPLE
    .\encode-av1.ps1 -Path "D:\Videos" -Encoder FFzap -Threads 8
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path = $PWD,
    [ValidateSet('Auto', 'FFmpeg', 'FFzap')]
    [string]$Encoder = 'Auto',
    [int]$Threads = 4,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$svtParams = 'tbr=4000:tune=0:film-grain=8:enable-variance-boost=1:tile-columns=0:tile-rows=0:scd=1'

function Resolve-Encoder {
    [OutputType([string])]
    param([string]$EncoderPref = 'Auto')
    if ($EncoderPref -eq 'FFzap' -or ($EncoderPref -eq 'Auto' -and (Get-Command ffzap -ErrorAction SilentlyContinue))) {
        if (-not (Get-Command ffzap -ErrorAction SilentlyContinue)) {
            throw 'ffzap not found in PATH. Install it or use -Encoder FFmpeg.'
        }
        return 'ffzap'
    }
    if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
        throw 'ffmpeg not found in PATH. Install via: winget install Gyan.FFmpeg.Shared'
    }
    return 'ffmpeg'
}

$tool = Resolve-Encoder -EncoderPref $Encoder
Write-Host "Encoder : $tool" -ForegroundColor Cyan

$files = Get-ChildItem -Path $Path -Filter '*.mp4'
if ($files.Count -eq 0) {
    Write-Host 'No MP4 files found.' -ForegroundColor Yellow
    exit 0
}

Write-Host "Files   : $($files.Count)" -ForegroundColor Cyan
Write-Host ''

$errors = 0
foreach ($file in $files) {
    $output = Join-Path $file.DirectoryName "$($file.BaseName).mkv"

    if ((Test-Path $output) -and -not $Force) {
        Write-Host "  [SKIP] $($file.Name) - output exists (use -Force to overwrite)" -ForegroundColor Gray
        continue
    }

    if (-not $PSCmdlet.ShouldProcess($file.Name, 'Encode to AV1')) { continue }

    Write-Host "  [....] $($file.Name)" -ForegroundColor Gray

    if ($tool -eq 'ffzap') {
        $ffArgs = "-c:v libsvtav1 -preset 1 -b:v 4000k -svtav1-params `"$svtParams`" -c:a libopus -compression_level 10 -b:a 64k -vbr on"
        & ffzap -t $Threads --overwrite --eta -i $file.FullName -f $ffArgs -o $output
    }
    else {
        $overwriteFlag = if ($Force) { @('-y') } else { @('-n') }
        & ffmpeg @overwriteFlag -i $file.FullName `
            -c:v libsvtav1 -preset 1 -b:v 4000k -svtav1-params $svtParams `
            -c:a libopus -compression_level 10 -b:a 64k -vbr on `
            $output
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "  [FAIL] $($file.Name)"
        $errors++
    }
    else {
        Write-Host "  [ OK ] $($file.BaseName).mkv" -ForegroundColor Green
    }
}

Write-Host ''
if ($errors -gt 0) {
    Write-Host "$errors file(s) failed." -ForegroundColor Red
    exit 1
}
else {
    Write-Host 'Done.' -ForegroundColor Green
}
