#Requires -Version 5.1

<#
.SYNOPSIS
    Deduplicate images and videos in a folder using fclones then czkawka.
.DESCRIPTION
    Passes run fastest/exact first, fuzzy last:
      1. fclones - removes byte-for-byte identical duplicates (fast, exact).
      2. czkawka - duplicate-file hash pass, opt-in via -IncludeDup.
      3. czkawka - finds perceptually similar images (fuzzy).
      4. czkawka - finds perceptually similar videos (fuzzy, slowest).
      5. czkawka - removes zero-byte media files.
    The czkawka duplicate-file pass is off by default: fclones already found
    every byte-identical file in pass 1, faster, so running it again is a
    second full-tree hash for no additional matches. -IncludeDup re-enables it.
    Both fclones passes are scoped to media extensions, case-insensitively,
    and skip Nextcloud/sync metadata (see -Exclude).
    The dup/image/video passes use Lanczos3 image resampling (highest-quality
    hashing input) and include files below czkawka's default minimum size, so
    small media is no longer silently skipped. Match strictness (ImageDifference,
    VideoTolerance) is unchanged from czkawka's own defaults.
    Runs in preview mode by default; nothing is deleted until you pass -Apply.
    Only the fclones exact-duplicate pass deletes permanently (files are
    byte-identical). Every czkawka pass - dup, image, video, empty-files -
    moves matches to the Recycle Bin instead, so a wrong match is recoverable.
    In each similar-file or duplicate-file group the newest file is kept
    (czkawka delete method AEN).
    fclones, czkawka, and any ffmpeg process czkawka spawns for the video
    pass all run at Above Normal CPU priority.
    fclones is installed automatically via scoop, czkawka via winget, if
    either is missing.
.PARAMETER Path
    Folder to scan recursively. If omitted, a folder picker dialog opens.
.PARAMETER Help
    Show this help and exit. Aliased to -h; a literal "-h", "--help", or "/?"
    typed as the first argument is also recognized.
.PARAMETER Apply
    Perform deletions. Without it the script only previews what would be removed.
.PARAMETER Force
    Skip the confirmation prompt when used with -Apply.
.PARAMETER SkipExact
    Skip the fclones exact-duplicate pass.
.PARAMETER IncludeDup
    Run the czkawka duplicate-file hash pass. Off by default because the
    fclones pass already removes every byte-identical file, and czkawka's
    dup mode is a slower way of finding the same set.
.PARAMETER Exclude
    Extra glob patterns matched against the full path and skipped by the
    fclones passes, appended to the built-in Nextcloud/sync-metadata list.
.PARAMETER SkipImages
    Skip the czkawka similar-image pass.
.PARAMETER SkipVideos
    Skip the czkawka similar-video pass (this pass is the slowest).
.PARAMETER SkipEmptyFiles
    Skip the czkawka empty-file pass.
.PARAMETER ImageDifference
    czkawka max image difference, 0 (identical) to 40 (loose). Default 5.
.PARAMETER VideoTolerance
    czkawka max video difference, 0 (identical) to 20 (loose). Default 10.
.PARAMETER VideoWindowCount
    Temporal windows czkawka samples per video, 1 to 20. Default 8 (above
    czkawka's own default of 5) for better match accuracy; more windows means
    more ffmpeg decoding, the dominant cost of the video pass. Lower it for
    faster, less-thorough scans.
.PARAMETER MatchRotated
    Also match mirrored and 90-degree-rotated image variants as duplicates
    (czkawka --geometric-invariance mirror-flip-rotate90). Roughly 3x the
    image-pass work; off by default.
.PARAMETER CheckAudio
    Also compare videos by audio fingerprint, not just visual frames
    (czkawka --check-audio-content). Very resource-intensive; off by default.
.EXAMPLE
    .\dedupe-media.ps1 -Path 'D:\Pictures'
    Preview duplicates without deleting anything.
.EXAMPLE
    .\dedupe-media.ps1 -Path 'D:\Pictures' -Apply
    Remove exact duplicates and send fuzzy matches to the Recycle Bin.
.EXAMPLE
    .\dedupe-media.ps1 -Help
    Show full help and exit.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param (
    [Parameter(Position = 0)]
    [string]$Path,
    [Alias('h')]
    [switch]$Help,
    [switch]$Apply,
    [switch]$Force,
    [switch]$SkipExact,
    [switch]$IncludeDup,
    [string[]]$Exclude = @(),
    [switch]$SkipImages,
    [switch]$SkipVideos,
    [switch]$SkipEmptyFiles,
    [ValidateRange(0, 40)]
    [int]$ImageDifference = 5,
    [ValidateRange(0, 20)]
    [int]$VideoTolerance = 10,
    [ValidateRange(1, 20)]
    [int]$VideoWindowCount = 8,
    [switch]$MatchRotated,
    [switch]$CheckAudio
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

# Image and video extensions used to scope the exact-duplicate pass.
$mediaExtensions = @(
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'tiff', 'tif', 'heic', 'heif', 'avif',
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', 'mpg', 'mpeg', 'ts', 'm2ts'
)

# Nextcloud/Syncthing metadata and partial-transfer files. fclones matches --exclude
# patterns against the full path, hence the leading '**/'. Deduplicating a version
# history or a trash bin against the live file would delete the live copy.
$excludePatterns = @(
    '**/files_versions/**', '**/files_trashbin/**', '**/.nextcloud/**', '**/.nextcloud*',
    '**/.sync_*.db', '**/*.part', '**/*.partial', '**/.stfolder/**', '**/.stversions/**',
    '**/.thumbnails/**', '**/Thumbs.db', '**/.cache/**', '**/thumbnails/**'
) + $Exclude


# Unit multipliers: fclones reports decimal (KB=1000), czkawka reports binary (KiB=1024).
$decimalUnits = @{ B = 1; KB = 1000; MB = 1000 * 1000; GB = 1000 * 1000 * 1000; TB = 1000 * 1000 * 1000 * 1000 }
$binaryUnits = @{ B = 1; KiB = 1024; MiB = 1024 * 1024; GiB = 1024 * 1024 * 1024; TiB = 1024 * 1024 * 1024 * 1024 }


function Get-ReclaimedByteCount {
    [CmdletBinding()]
    [OutputType([double])]
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][hashtable]$Units
    )
    process {
        $match = [regex]::Match($Text, $Pattern)
        if (-not $match.Success) {
            return 0.0
        }
        [double]$match.Groups[1].Value * $Units[$match.Groups[2].Value]
    }
}


function Invoke-ToolAboveNormal {
    <#
    .SYNOPSIS
        Runs a console tool at Above Normal priority, streaming its output live.
    .PARAMETER FilePath
        Executable to run.
    .PARAMETER ArgumentList
        Arguments passed to the executable.
    .PARAMETER StandardInputPath
        File piped to the process's stdin.
    .PARAMETER WatchFfmpeg
        Also raise the priority of ffmpeg processes the tool spawns while it runs.
        Only meaningful for czkawka's video pass; leave off elsewhere so unrelated
        encodes (for example a concurrent optimize-media.ps1) are never touched.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [string]$StandardInputPath,
        [switch]$WatchFfmpeg
    )
    process {
        $stdOutFile = [System.IO.Path]::GetTempFileName()
        $stdErrFile = [System.IO.Path]::GetTempFileName()
        $readers = @()
        $collected = [System.Collections.Generic.List[string]]::new()
        try {
            $startArgs = @{
                FilePath               = $FilePath
                ArgumentList           = $ArgumentList
                NoNewWindow            = $true
                PassThru               = $true
                RedirectStandardOutput = $stdOutFile
                RedirectStandardError  = $stdErrFile
            }
            if ($StandardInputPath) {
                $startArgs.RedirectStandardInput = $StandardInputPath
            }
            $proc = Start-Process @startArgs
            try {
                $proc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::AboveNormal
            }
            catch {
                Write-Verbose "Could not raise priority for $FilePath (PID $($proc.Id)): $($_.Exception.Message)"
            }

            # Read the redirect files as the process writes them (FileShare.ReadWrite so
            # the child keeps its own handle) instead of dumping everything after exit -
            # a multi-hour video pass otherwise shows nothing at all until it finishes.
            $readers = @($stdOutFile, $stdErrFile) | ForEach-Object {
                [System.IO.StreamReader]::new(
                    [System.IO.File]::Open($_, [System.IO.FileMode]::Open,
                        [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite))
            }

            $drain = {
                foreach ($reader in $readers) {
                    while ($null -ne ($line = $reader.ReadLine())) {
                        $collected.Add($line)
                        Write-Host $line
                    }
                }
            }

            while (-not $proc.HasExited) {
                & $drain
                if ($WatchFfmpeg) {
                    # czkawka's video pass shells out to ffmpeg per file; ffmpeg is a fresh
                    # child process and does not inherit our priority bump. Only touch ffmpeg
                    # processes that started after this tool did, so a concurrent encode
                    # started by something else is left alone.
                    foreach ($ffmpegProc in @(Get-Process -Name 'ffmpeg' -ErrorAction SilentlyContinue)) {
                        try {
                            if ($ffmpegProc.StartTime -ge $proc.StartTime -and
                                $ffmpegProc.PriorityClass -ne [System.Diagnostics.ProcessPriorityClass]::AboveNormal) {
                                $ffmpegProc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::AboveNormal
                            }
                        }
                        catch {
                            Write-Verbose ("Could not raise priority for ffmpeg " +
                                "(PID $($ffmpegProc.Id)): $($_.Exception.Message)")
                        }
                    }
                }
                Start-Sleep -Milliseconds 250
            }
            & $drain

            [PSCustomObject]@{
                Output   = $collected.ToArray()
                ExitCode = $proc.ExitCode
            }
        }
        finally {
            foreach ($reader in $readers) { $reader.Dispose() }
            Remove-Item -LiteralPath $stdOutFile, $stdErrFile -ErrorAction SilentlyContinue
        }
    }
}


function Invoke-FclonesPass {
    [CmdletBinding()]
    [OutputType([double])]
    param(
        [Parameter(Mandatory)][string]$Tool,
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][string[]]$NameGlob,
        [string[]]$ExcludeGlob = @(),
        [Parameter(Mandatory)][string]$ReportPath,
        [Parameter(Mandatory)][bool]$DryRun
    )
    process {
        # Scoping belongs on `group`, not `remove`: without --name, group hashes every file
        # in the tree (documents, archives, sync journals) only for `remove` to then ignore
        # them. -i because fclones globs are case-sensitive by default, so *.jpg would never
        # match IMG_0001.JPG. `remove` accepts neither --exclude nor -i, and needs no filter
        # of its own - the report it reads back is already scoped by this pass.
        $scopeArgs = [System.Collections.Generic.List[string]]::new()
        foreach ($glob in $NameGlob) {
            $scopeArgs.Add('--name')
            $scopeArgs.Add($glob)
        }
        foreach ($glob in $ExcludeGlob) {
            $scopeArgs.Add('--exclude')
            $scopeArgs.Add($glob)
        }
        $scopeArgs.Add('--ignore-case')

        Write-Phase "fclones: scanning for exact duplicates in $TargetPath"
        $groupArgs = [System.Collections.Generic.List[string]]::new()
        $groupArgs.Add('group')
        $groupArgs.Add('--cache')
        $groupArgs.AddRange($scopeArgs)
        $groupArgs.Add('--output'); $groupArgs.Add($ReportPath)
        $groupArgs.Add($TargetPath)
        $groupResult = Invoke-ToolAboveNormal -FilePath $Tool -ArgumentList $groupArgs
        if ($groupResult.ExitCode -ne 0) {
            throw "fclones group failed (exit $($groupResult.ExitCode))."
        }

        $removeArgs = [System.Collections.Generic.List[string]]::new()
        $removeArgs.Add('remove')
        if ($DryRun) {
            $removeArgs.Add('--dry-run')
        }

        if ($DryRun) {
            Write-Phase 'fclones: previewing removals (nothing deleted)'
        }
        else {
            Write-Phase 'fclones: removing exact duplicates'
        }
        $removeResult = Invoke-ToolAboveNormal -FilePath $Tool -ArgumentList $removeArgs -StandardInputPath $ReportPath
        if ($removeResult.ExitCode -ne 0) {
            throw "fclones remove failed (exit $($removeResult.ExitCode))."
        }

        # e.g. "Would process 1 files and reclaim 100.0 KB space" / "Processed 1 files and reclaimed 100.0 KB space"
        Get-ReclaimedByteCount -Text ($removeResult.Output -join "`n") -Pattern 'reclaim(?:ed)? ([\d.]+) (B|KB|MB|GB|TB) space' -Units $decimalUnits
    }
}


function Invoke-CzkawkaPass {
    [CmdletBinding()]
    [OutputType([double])]
    param(
        [Parameter(Mandatory)][string]$Tool,
        [Parameter(Mandatory)][ValidateSet('image', 'video', 'dup', 'empty-files')][string]$Mode,
        [Parameter(Mandatory)][string]$TargetPath,
        [int]$Threshold,
        [int]$WindowCount,
        [string[]]$AllowedExtensions,
        [switch]$MatchRotated,
        [switch]$CheckAudio,
        [Parameter(Mandatory)][string]$ReportPath,
        [Parameter(Mandatory)][bool]$DryRun
    )
    process {
        $label = switch ($Mode) {
            'image' { 'similar images' }
            'video' { 'similar videos' }
            'dup' { 'duplicate files (hash)' }
            'empty-files' { 'empty files' }
        }
        Write-Phase "czkawka: scanning for $label in $TargetPath"

        $cliArgs = [System.Collections.Generic.List[string]]::new()
        $cliArgs.Add($Mode)
        $cliArgs.Add('--directories'); $cliArgs.Add($TargetPath)
        # ponytail: Nextcloud/sync metadata is excluded from the fclones passes only.
        # czkawka is not installed on the machine this was written on and its
        # excluded-items flag name was not verified, so nothing is guessed here.
        # To wire it up: run `czkawka_cli dup --help`, confirm the flag (expected to be
        # --excluded-items / --excluded-directories, taking comma-separated globs), then
        # append $excludePatterns through a new -ExcludeGlob parameter exactly as
        # Invoke-FclonesPass does.
        foreach ($ext in $AllowedExtensions) {
            $cliArgs.Add('--allowed-extensions')
            $cliArgs.Add($ext)
        }
        if ($Mode -in 'dup', 'image', 'video') {
            # Include small media that czkawka's own default minimum size would otherwise skip.
            $cliArgs.Add('--minimal-file-size'); $cliArgs.Add('1')
        }
        switch ($Mode) {
            'image' {
                $cliArgs.Add('--max-difference'); $cliArgs.Add([string]$Threshold)
                $cliArgs.Add('--image-filter'); $cliArgs.Add('Lanczos3')
                if ($MatchRotated) {
                    $cliArgs.Add('--geometric-invariance'); $cliArgs.Add('mirror-flip-rotate90')
                }
            }
            'video' {
                $cliArgs.Add('--tolerance'); $cliArgs.Add([string]$Threshold)
                $cliArgs.Add('--window-count'); $cliArgs.Add([string]$WindowCount)
                if ($CheckAudio) {
                    $cliArgs.Add('--check-audio-content')
                }
            }
        }
        $cliArgs.Add('--file-to-save'); $cliArgs.Add($ReportPath)
        $cliArgs.Add('--ignore-error-code-on-found')
        if ($Mode -eq 'empty-files') {
            $cliArgs.Add('--delete-files')
        }
        else {
            # AEN = keep the newest file in each group, remove the rest.
            $cliArgs.Add('--delete-method'); $cliArgs.Add('AEN')
        }
        if ($DryRun) {
            $cliArgs.Add('--dry-run')
        }
        else {
            # Move matches to the Recycle Bin instead of permanent deletion.
            $cliArgs.Add('--move-to-trash')
        }

        $result = Invoke-ToolAboveNormal -FilePath $Tool -ArgumentList $cliArgs -WatchFfmpeg:($Mode -eq 'video')
        # czkawka returns non-zero when it finds matches; -W keeps that at 0.
        if ($result.ExitCode -ne 0) {
            throw "czkawka $Mode failed (exit $($result.ExitCode))."
        }
        Write-Host "    report: $ReportPath" -ForegroundColor DarkGray

        # e.g. "Found 1 duplicated files which in 1 groups which takes 97.66 KiB."
        Get-ReclaimedByteCount -Text ($result.Output -join "`n") -Pattern 'which takes ([\d.]+) (B|KiB|MiB|GiB|TiB)' -Units $binaryUnits
    }
}


if (-not $PSBoundParameters.ContainsKey('Path')) {
    $Path = Select-FolderDialog -Description 'Select the folder to deduplicate'
}

$resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
    throw "Path is not a folder: $resolvedPath"
}

$fclones = Resolve-OrInstallTool -Name 'fclones' -ScoopPackage 'fclones'

# Resolved lazily: with every czkawka pass skipped (or only the fclones pass wanted)
# there is no reason to install czkawka first.
$czkawka = $null
if ($IncludeDup -or -not ($SkipImages -and $SkipVideos -and $SkipEmptyFiles)) {
    $czkawka = Resolve-OrInstallTool -Name 'czkawka_cli', 'windows_czkawka_cli' -WingetId 'qarmin.czkawka.cli'
}

$dryRun = -not $Apply
if ($WhatIfPreference) {
    $dryRun = $true
}

if (-not $dryRun -and -not $Force) {
    $target = "Delete duplicate media under '$resolvedPath'"
    $caption = 'Confirm deletion'
    $warning = "Exact duplicates are removed permanently; fuzzy matches go to the Recycle Bin.`nContinue?"
    if (-not $PSCmdlet.ShouldProcess($target, $caption) -or
        -not $PSCmdlet.ShouldContinue($warning, $caption)) {
        Write-Warning 'Aborted by user.'
        return
    }
}

if ($dryRun) {
    Write-Host 'PREVIEW MODE - no files will be deleted. Re-run with -Apply to act.' -ForegroundColor Yellow
}
Write-Host ('Note: the Recycle Bin has a per-volume size cap. A large czkawka pass can push ' +
    'older recycled items out permanently, so "recoverable" only holds up to that cap.') -ForegroundColor DarkYellow

$reportDir = Join-Path -Path $env:TEMP -ChildPath 'dedupe-media'
$null = New-Item -Path $reportDir -ItemType Directory -Force
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$reclaimedBytes = 0.0

if (-not $SkipExact) {
    $mediaGlob = [System.Collections.Generic.List[string]]::new()
    foreach ($ext in $mediaExtensions) {
        $mediaGlob.Add("*.$ext")
    }
    $reclaimedBytes += Invoke-FclonesPass -Tool $fclones -TargetPath $resolvedPath -NameGlob $mediaGlob `
        -ExcludeGlob $excludePatterns -ReportPath (Join-Path $reportDir "fclones-$stamp.txt") -DryRun $dryRun
}

if ($IncludeDup) {
    $reclaimedBytes += Invoke-CzkawkaPass -Tool $czkawka -Mode 'dup' -TargetPath $resolvedPath -AllowedExtensions $mediaExtensions `
        -ReportPath (Join-Path $reportDir "dup-$stamp.txt") -DryRun $dryRun
}

if (-not $SkipImages) {
    $reclaimedBytes += Invoke-CzkawkaPass -Tool $czkawka -Mode 'image' -TargetPath $resolvedPath `
        -Threshold $ImageDifference -MatchRotated:$MatchRotated `
        -ReportPath (Join-Path $reportDir "images-$stamp.txt") -DryRun $dryRun
}

if (-not $SkipVideos) {
    $reclaimedBytes += Invoke-CzkawkaPass -Tool $czkawka -Mode 'video' -TargetPath $resolvedPath `
        -Threshold $VideoTolerance -WindowCount $VideoWindowCount -CheckAudio:$CheckAudio `
        -ReportPath (Join-Path $reportDir "videos-$stamp.txt") -DryRun $dryRun
}

if (-not $SkipEmptyFiles) {
    $reclaimedBytes += Invoke-CzkawkaPass -Tool $czkawka -Mode 'empty-files' -TargetPath $resolvedPath -AllowedExtensions $mediaExtensions `
        -ReportPath (Join-Path $reportDir "empty-files-$stamp.txt") -DryRun $dryRun
}

Write-Host ''
if ($dryRun) {
    Write-Host "Estimated space that would be freed: $(Format-Size $reclaimedBytes)" -ForegroundColor Green
    if ($IncludeDup) {
        Write-Host ('(Preview totals may double-count exact duplicates: fclones only simulates removal in a ' +
            'dry run, so the -IncludeDup czkawka dup pass still sees and reports the same files.)') -ForegroundColor DarkGray
    }
}
else {
    Write-Host "Space freed: $(Format-Size $reclaimedBytes)" -ForegroundColor Green
}

Write-Host ''
if ($dryRun) {
    Write-Host 'Preview complete. Review the reports above, then re-run with -Apply.' -ForegroundColor Green
}
else {
    Write-Host 'Deduplication complete.' -ForegroundColor Green
}
