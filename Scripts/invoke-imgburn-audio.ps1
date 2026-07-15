#Requires -Version 5.1

<#
.SYNOPSIS
    Burns audio files from a directory to an audio CD using ImgBurn CLI.
.DESCRIPTION
    Decodes FLAC, WAV, MP3, and other audio formats to standard CD-DA (Red Book)
    and burns to a CD-R using ImgBurn. Designed for car radio compatibility.
    Auto-detects the CD burner drive and ImgBurn installation path.
    With -DataCd, instead transcodes to 320kbps MP3 and burns an ISO9660+Joliet
    data disc, for head units that read MP3 files directly off a data CD.
.PARAMETER Path
    Directory containing audio files to burn. Supports FLAC, WAV, MP3, and any
    other format ImgBurn can decode.
.PARAMETER DriveLetter
    CD/DVD burner drive letter (e.g., 'E'). Auto-detects if omitted.
.PARAMETER Speed
    Write speed for burning. Default: 8. Lower speeds (4-16) produce fewer errors
    and better car radio compatibility.
.PARAMETER WriteType
    Write mode: DAO (Disc-At-Once, best car compatibility) or SAO (Session-At-Once).
    Default: DAO. Ignored when -DataCd is used.
.PARAMETER DataCd
    Burn an MP3 data disc instead of a Red Book audio CD. Transcodes every
    source file to 320kbps CBR MP3 in a persistent "<Path>_mp3" folder, then
    burns that folder as an ISO9660+Joliet data disc.
.PARAMETER Eject
    Eject the disc after burning completes.
.PARAMETER Verify
    Verify the burned disc after writing (adds ~10 min to process).
.PARAMETER PassThrough
    Emit burn result objects to the pipeline for further processing.
.EXAMPLE
    .\invoke-imgburn-audio.ps1 -Path "$env:USERPROFILE\Music\my_playlist"
.EXAMPLE
    .\invoke-imgburn-audio.ps1 -Path "D:\Music\playlist" -DriveLetter F -Speed 4
.EXAMPLE
    .\invoke-imgburn-audio.ps1 -Path "D:\Music\playlist" -Eject -Verify
.EXAMPLE
    .\invoke-imgburn-audio.ps1 -Path "D:\Music\playlist" -DataCd
    Burns an MP3 data disc for car head units that read MP3s from data CDs.
.NOTES
    Requires ImgBurn and ffmpeg installed. Get them via:
      winget install LIGHTNINGUK.ImgBurn
      winget install Gyan.FFmpeg
    Always use CD-R media (not CD-RW) for car radio compatibility.
    The source directory should contain audio files (FLAC, WAV, MP3, etc.).
    ImgBurn does NOT decode audio - it burns exactly the bytes a CUE points at.
    This script uses ffmpeg to transcode every source file to Red Book
    CD-DA (44.1kHz/16-bit/stereo PCM WAV) before handing the CUE to ImgBurn.
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory, Position = 0)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$Path,

    [ValidatePattern('^[A-Za-z]$')]
    [string]$DriveLetter,

    [ValidateRange(1, 48)]
    [int]$Speed = 8,

    [ValidateSet('DAO', 'SAO')]
    [string]$WriteType = 'DAO',

    [switch]$DataCd,

    [switch]$Eject,

    [switch]$Verify,

    [switch]$PassThrough
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Common.ps1"

Add-Log -Text 'ImgBurn Audio CD Burner started'
Add-Log -Text "Source: $Path"

# Locate ImgBurn
$imgburnCandidates = @(
    "${env:ProgramFiles}\ImgBurn\ImgBurn.exe",
    "${env:ProgramFiles(x86)}\ImgBurn\ImgBurn.exe",
    "$env:LOCALAPPDATA\ImgBurn\ImgBurn.exe",
    "${env:ProgramFiles}\ImgBurn\ImgBurn64.exe",
    "${env:ProgramFiles(x86)}\ImgBurn\ImgBurn64.exe"
)
$imgburnPath = $imgburnCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not $imgburnPath) {
    Write-Error "ImgBurn not found. Install via: winget install LIGHTNINGUK.ImgBurn"
    exit 1
}
Add-Log -Text "ImgBurn: $imgburnPath"

# Locate ffmpeg (required to transcode source audio to Red Book CD-DA WAV)
$ffmpegCommand = Get-Command -Name ffmpeg.exe -ErrorAction SilentlyContinue
if (-not $ffmpegCommand) {
    Write-Error "ffmpeg not found on PATH. Install via: winget install Gyan.FFmpeg"
    exit 1
}
$ffmpegPath = $ffmpegCommand.Source
Add-Log -Text "ffmpeg: $ffmpegPath"

# Discover CD burner drives
$allDrives = @(Get-CimInstance -ClassName Win32_CDROMDrive)
$drives = @($allDrives | Where-Object {
    $_.MediaType -match 'CD|DVD|Blu.?ray' -or $_.Name -match 'CD|DVD|Blu.?ray'
})

if ($drives.Length -eq 0) {
    Write-Error 'No CD/DVD/Blu-ray drives detected.'
    exit 1
}

if ($DriveLetter) {
    $targetDrive = $drives | Where-Object { $_.Drive -eq "$($DriveLetter):" }
    if (-not $targetDrive) {
        Write-Error "Drive '$DriveLetter' not found or is not an optical drive."
        Write-Warning "Available drives: $($drives.Drive -join ', ')"
        exit 1
    }
} else {
    # Prefer drives loaded with media (ignore empty drives)
    $targetDrive = $drives | Select-Object -First 1
    Add-Log -Text "Auto-selected drive: $($targetDrive.Drive)"
}

$destDrive = $targetDrive.Drive
Add-Log -Text "Destination: $destDrive"

# Ensure the disc is blank before burning (erase if rewritable, fail if a
# finalized CD-R already has data - ImgBurn cannot append/overwrite that).
$discMaster = New-Object -ComObject IMAPI2.MsftDiscMaster2
$recorderId = $discMaster | Where-Object {
    $rec = New-Object -ComObject IMAPI2.MsftDiscRecorder2
    $rec.InitializeDiscRecorder($_)
    $rec.VolumePathNames -contains "$destDrive\"
} | Select-Object -First 1

if (-not $recorderId) {
    Write-Error "Could not find an IMAPI2 recorder for drive $destDrive."
    exit 1
}

$recorder = New-Object -ComObject IMAPI2.MsftDiscRecorder2
$recorder.InitializeDiscRecorder($recorderId)
$dataFormat = New-Object -ComObject IMAPI2.MsftDiscFormat2Data
$dataFormat.Recorder = $recorder

# IMAPI_MEDIA_PHYSICAL_TYPE: 3=CDRW, 7/13=DVD+RW, 10=DVD-RW, 19=BDRE
$rewritableMediaTypes = 3, 7, 10, 13, 19

if (-not $dataFormat.MediaHeuristicallyBlank) {
    Add-Log -Text "Disc is not blank (physical media type $($dataFormat.CurrentPhysicalMediaType)), attempting erase"
    if ($dataFormat.CurrentPhysicalMediaType -notin $rewritableMediaTypes) {
        Write-Error "Disc in $destDrive is not blank and is not a rewritable format (finalized CD-R?). Insert a blank disc, or reinsert if this is a fresh CD-R being misreported."
        exit 1
    }
    if ($PSCmdlet.ShouldProcess($destDrive, 'Erase existing disc contents')) {
        $eraser = New-Object -ComObject IMAPI2.MsftDiscFormat2Erase
        $eraser.Recorder = $recorder
        $eraser.EraseMedia()
        Add-Log -Text 'Erase complete'
    }
} else {
    Add-Log -Text 'Disc confirmed blank'
}

# Check source for audio files
$audioFiles = @(Get-ChildItem -LiteralPath $Path -File | Where-Object {
    $_.Extension -match '\.(flac|wav|mp3|wma|ogg|aac|m4a|ape|wv|aiff|dff|dsf)$'
} | Sort-Object Name)
if ($audioFiles.Length -eq 0) {
    Write-Error "No supported audio files found in: $Path"
    exit 1
}
Add-Log -Text "Audio tracks: $($audioFiles.Length)"

$projectLabel = Split-Path -Leaf $Path

if ($DataCd) {
    # Transcode every source file to 320kbps CBR MP3 in a persistent folder
    # next to the source, then burn that folder as an ISO9660+Joliet data
    # disc. Output is kept (not deleted) so it can be reused for future burns.
    $mp3Dir = Join-Path -Path (Split-Path -Parent $Path) -ChildPath ((Split-Path -Leaf $Path) + '_mp3')
    New-Item -Path $mp3Dir -ItemType Directory -Force | Out-Null
    Add-Log -Text "Transcoding $($audioFiles.Length) track(s) to 320kbps MP3 in $mp3Dir"

    foreach ($f in $audioFiles) {
        $mp3Path = Join-Path -Path $mp3Dir -ChildPath ($f.BaseName + '.mp3')
        $ffmpegArgs = @(
            '-y', '-loglevel', 'error'
            '-i', $f.FullName
            '-vn', '-c:a', 'libmp3lame', '-b:a', '320k'
            '-map_metadata', '0', '-id3v2_version', '3'
            $mp3Path
        )
        & $ffmpegPath $ffmpegArgs 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $mp3Path)) {
            Write-Error "ffmpeg failed to transcode: $($f.FullName)"
            exit 1
        }
    }
    Add-Log -Text "Transcode complete: $($audioFiles.Length) MP3 file(s) in $mp3Dir"

    # ISO9660/Joliet volume label: uppercase alnum/underscore only, 16 char max.
    $volLabel = $projectLabel.ToUpper() -replace '[^A-Z0-9_]', '_'
    if ($volLabel.Length -gt 16) { $volLabel = $volLabel.Substring(0, 16) }

    $imgArgs = @(
        '/MODE', 'BUILD'
        '/BUILDINPUTMODE', 'STANDARD'
        '/BUILDOUTPUTMODE', 'DEVICE'
        '/SRC', $mp3Dir
        '/DEST', $destDrive
        '/FILESYSTEM', 'ISO9660 + Joliet'
        '/VOLUMELABEL_ISO9660', $volLabel
        '/VOLUMELABEL_JOLIET', $volLabel
        '/SPEED', [string]$Speed
        '/START'
        '/CLOSE'
    )
    $cleanupDir = $null
} else {
    # Transcode every source file to Red Book CD-DA (44.1kHz/16-bit/stereo PCM WAV).
    # ImgBurn does not decode audio itself - it burns exactly the bytes a CUE's
    # FILE line points at, so feeding it FLAC/MP3 directly produces a corrupt disc.
    $workDir = Join-Path -Path $env:TEMP -ChildPath "imgburn_$([guid]::NewGuid().Guid)"
    New-Item -Path $workDir -ItemType Directory -Force | Out-Null
    Add-Log -Text "Transcoding $($audioFiles.Length) track(s) to CD-DA WAV..."

    $wavFiles = for ($i = 0; $i -lt $audioFiles.Length; $i++) {
        $trackNum = '{0:D2}' -f ($i + 1)
        $wavPath = Join-Path -Path $workDir -ChildPath "track_$trackNum.wav"
        $ffmpegArgs = @(
            '-y', '-loglevel', 'error'
            '-i', $audioFiles[$i].FullName
            '-ar', '44100', '-ac', '2', '-sample_fmt', 's16'
            '-f', 'wav', $wavPath
        )
        & $ffmpegPath $ffmpegArgs 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $wavPath)) {
            Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Error "ffmpeg failed to transcode: $($audioFiles[$i].FullName)"
            exit 1
        }
        Get-Item -LiteralPath $wavPath
    }
    Add-Log -Text "Transcode complete: $($wavFiles.Length) WAV file(s) in $workDir"

    # Build a CUE sheet referencing each transcoded WAV by absolute path.
    # ImgBurn's WRITE mode /SRC needs a single file (ISO/CUE/etc.), not a folder,
    # so we generate a temporary CUE pointing at the WAV files.
    $cuePath = Join-Path -Path $workDir -ChildPath 'burn.cue'
    $cueLines = @(
        "REM GENRE Audio"
        "REM DATE $(Get-Date -Format 'yyyy')"
        "REM COMMENT Generated by invoke-imgburn-audio.ps1"
        "TITLE `"$projectLabel`""
        "FILE `"$($wavFiles[0].FullName)`" WAVE"
    )
    for ($i = 0; $i -lt $wavFiles.Length; $i++) {
        $trackNum = '{0:D2}' -f ($i + 1)
        $cueLines += "  TRACK $trackNum AUDIO"
        $cueLines += "    INDEX 01 00:00:00"
        if ($i -lt $wavFiles.Length - 1) {
            $cueLines += "FILE `"$($wavFiles[$i + 1].FullName)`" WAVE"
        }
    }
    Set-Content -LiteralPath $cuePath -Value $cueLines -Encoding ASCII
    Add-Log -Text "CUE sheet: $cuePath"

    # Build ImgBurn arguments
    $imgArgs = @(
        '/MODE', 'WRITE'
        '/SRC', $cuePath
        '/DEST', $destDrive
        '/SPEED', [string]$Speed
        '/WRITETYPE', $WriteType
        '/START'
        '/CLOSE'
    )
    $cleanupDir = $workDir
}

if ($Eject) { $imgArgs += '/EJECT' }
if ($Verify) { $imgArgs += '/VERIFY' }

$discKind = if ($DataCd) { 'MP3 data' } else { 'audio' }
if ($PSCmdlet.ShouldProcess($destDrive, "Burn $discKind CD from $Path @ ${Speed}x $WriteType")) {
    Write-Verbose "Command: $imgburnPath $($imgArgs -join ' ')"
    Add-Log -Text "Starting burn: $Speed`x $WriteType"
    Add-Log -Text "Tracks: $($audioFiles.Length) files, ~$([math]::Round(($audioFiles | Measure-Object -Property Length -Sum).Sum / 1MB)) MB"

    # If ImgBurn is already running (e.g. tray icon), a new invocation just
    # relays the command to that instance and exits immediately - our
    # temp-folder cleanup below would then race the actual burn. Close any
    # existing instance so this invocation is the one that blocks until done.
    Get-Process -Name 'ImgBurn' -ErrorAction SilentlyContinue | Stop-Process -Force

    try {
        # ImgBurn is a GUI app - '&' does not block for it, so Start-Process
        # -Wait is required to keep the temp CUE/WAV files alive until the
        # burn actually finishes (otherwise the finally below deletes them
        # while ImgBurn is still starting up, and it fails to find the CUE).
        $proc = Start-Process -FilePath $imgburnPath -ArgumentList $imgArgs -Wait -PassThru
        $ec = $proc.ExitCode
    } finally {
        if ($cleanupDir) { Remove-Item -Path $cleanupDir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    if ($ec -eq 0) {
        Add-Log -Text 'Burn completed successfully'
        if ($PassThrough) {
            [PSCustomObject]@{
                Source   = $Path
                Drive    = $destDrive
                Speed    = $Speed
                WriteType = $WriteType
                Status   = 'Completed'
                ExitCode = $ec
            }
        }
    } else {
        Write-Warning "ImgBurn exited with code $ec"
        Add-Log -Text "FAILED (exit $ec)"
        if ($PassThrough) {
            [PSCustomObject]@{
                Source   = $Path
                Drive    = $destDrive
                Speed    = $Speed
                WriteType = $WriteType
                Status   = "Failed (exit $ec)"
                ExitCode = $ec
            }
        }
    }
}
