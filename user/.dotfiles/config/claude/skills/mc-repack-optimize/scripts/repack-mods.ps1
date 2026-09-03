#Requires -Version 7
<#
.SYNOPSIS
  Repacks a PrismLauncher instance's mods with mc-repack, after backing up the originals.
.DESCRIPTION
  Resolves the mods folder under the given instance/mods path, copies it to a timestamped
  backup, runs 'mc-repack jars' into a temp output directory with a CSV size report, then
  copies the repacked jars back over the originals. Never touches the mods folder until
  mc-repack has already produced output - if mc-repack fails, the originals are untouched.
.PARAMETER Path
  Path to either the instance's mods folder directly, or the instance root - .minecraft\mods,
  minecraft\mods, and mods are all checked under it.
.PARAMETER Zopfli
  Zopfli iteration count (1-255) for slower but stronger compression. Omit for the default,
  much faster Libdeflater path.
.PARAMETER KeepDirs
  Keep directory entries in the repacked jars instead of dropping them.
.PARAMETER Blacklist
  Apply mc-repack's built-in junk-file blacklist in addition to any config file.
.PARAMETER Config
  Path to a specific mc-repack.toml instead of the default lookup.
.EXAMPLE
  .\repack-mods.ps1 -Path 'C:\Users\Ven0m0\AppData\Roaming\PrismLauncher\instances\MyPack'
  Backs up and repacks MyPack's mods folder with default settings.
.OUTPUTS
  None. Writes progress to Verbose and a size-savings summary to Information.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param (
  # Instance root or mods folder to repack
  [Parameter(Mandatory)]
  [string]$Path,

  # Zopfli iteration count (1-255); omit to use the fast default compressor
  [ValidateRange(1, 255)]
  [int]$Zopfli,

  # Keep directory entries in the repacked jars
  [switch]$KeepDirs,

  # Apply mc-repack's built-in junk-file blacklist
  [switch]$Blacklist,

  # Explicit mc-repack.toml path
  [string]$Config
)

process {
  $ErrorActionPreference = 'Stop'

  if (-not (Get-Command -Name mc-repack -ErrorAction SilentlyContinue)) {
    throw "mc-repack not found on PATH. Install with 'cargo install mc-repack' or grab a release zip: https://github.com/szeweq/mc-repack/releases/latest"
  }

  $resolvedInput = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
  $modsCandidates = if ((Split-Path -Path $resolvedInput -Leaf) -eq 'mods') {
    @($resolvedInput)
  } else {
    @(
      (Join-Path -Path $resolvedInput -ChildPath '.minecraft\mods'),
      (Join-Path -Path $resolvedInput -ChildPath 'minecraft\mods'),
      (Join-Path -Path $resolvedInput -ChildPath 'mods')
    )
  }
  $mods = $modsCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1
  if (-not $mods) {
    throw "No mods folder found under '$resolvedInput'. Checked: $($modsCandidates -join ', ')"
  }
  $mods = (Resolve-Path -LiteralPath $mods).Path
  Write-Verbose -Message "mods folder: $mods"

  $jarCount = (Get-ChildItem -LiteralPath $mods -Filter '*.jar' -File).Count
  if ($jarCount -eq 0) {
    throw "No .jar files found directly in '$mods' - nothing to repack."
  }
  Write-Verbose -Message "$jarCount jar(s) found."

  if (-not $PSCmdlet.ShouldProcess($mods, 'Back up and repack mods with mc-repack')) {
    return
  }

  $parent = Split-Path -Path $mods -Parent
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $backup = Join-Path -Path $parent -ChildPath "mods-backup-$stamp"
  $out = Join-Path -Path $env:TEMP -ChildPath "mc-repack-out-$stamp"
  $report = Join-Path -Path $parent -ChildPath "mc-repack-report-$stamp.csv"

  Write-Verbose -Message "Backing up originals to: $backup"
  Copy-Item -LiteralPath $mods -Destination $backup -Recurse

  $mcRepackArgs = @('jars', '--in', $mods, '--out', $out, '-r', $report)
  if ($Zopfli) {
    $mcRepackArgs += @('-z', $Zopfli)
  }
  if ($KeepDirs) {
    $mcRepackArgs += '-d'
  }
  if ($Blacklist) {
    $mcRepackArgs += '-b'
  }
  if ($Config) {
    $mcRepackArgs += @('-c', $Config)
  }

  Write-Verbose -Message "Running: mc-repack $($mcRepackArgs -join ' ')"
  & mc-repack @mcRepackArgs
  if ($LASTEXITCODE -ne 0) {
    throw "mc-repack exited with code $LASTEXITCODE. Originals in '$mods' were not touched. Backup (unneeded) is at '$backup'."
  }

  $repacked = Get-ChildItem -LiteralPath $out -Include '*.jar', '*.zip' -File -Recurse
  if ($repacked.Count -eq 0) {
    throw "mc-repack produced no output files in '$out'. Originals in '$mods' were not touched."
  }
  foreach ($file in $repacked) {
    Copy-Item -LiteralPath $file.FullName -Destination (Join-Path -Path $mods -ChildPath $file.Name) -Force
  }
  Write-Information -MessageData "$($repacked.Count) repacked jar(s) copied into '$mods'." -InformationAction Continue

  if (Test-Path -LiteralPath $report) {
    $rows = Import-Csv -LiteralPath $report
    $oldTotal = ($rows | Measure-Object -Property old_size -Sum).Sum
    $newTotal = ($rows | Measure-Object -Property new_size -Sum).Sum
    if ($oldTotal -gt 0) {
      $savedMB = [math]::Round(($oldTotal - $newTotal) / 1MB, 2)
      $percent = [math]::Round((1 - ($newTotal / $oldTotal)) * 100, 1)
      Write-Information -MessageData "Saved: $savedMB MB ($percent% smaller) across $($rows.Count) file(s)." -InformationAction Continue
    }
    Write-Information -MessageData "Full report: $report" -InformationAction Continue
  }

  Write-Information -MessageData "Backup of originals: $backup" -InformationAction Continue
}
