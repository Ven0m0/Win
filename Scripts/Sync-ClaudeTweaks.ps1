#Requires -Version 7.0

<#
.SYNOPSIS
  Keeps the tweakcc-patched Claude Code binary and the lobotomized-claude-code (lcc) overrides in sync.
.DESCRIPTION
  Idempotent. Used by topgrade and for one-time repair.
    1. Skips (exit 0) when a claude process is running, because Windows locks the exe.
    2. Fetches the lcc repo (before touching the binary, so an offline run leaves the patched binary alone).
    3. Restores the stock binary via tweakcc-fixed --restore.
    4. Optionally installs a specific CC version (-ClaudeVersion).
    5. Pins the lcc repo to the newest commit that does not yet target a CC version newer than
       the installed one (or origin/main if none does).
    6. Fetches system prompts and re-applies tweakcc.
  Exits non-zero only when a step fails.
.PARAMETER ClaudeVersion
  Optional Claude Code version to install first (e.g. 2.1.328).
.PARAMETER Force
  Run even when claude processes are running.
#>
[CmdletBinding()]
param(
  [ValidatePattern('^\d+\.\d+\.\d+$')]
  [string]$ClaudeVersion,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$lccRepo = Join-Path -Path $env:USERPROFILE -ChildPath '.tweakcc\lobotomized-claude-code'
$tweakcc = 'tweakcc-fixed@latest'

function Invoke-Native {
  param([Parameter(Mandatory)][string]$What, [Parameter(Mandatory)][scriptblock]$Command)
  Write-Host "==> $What"
  & $Command
  if ($LASTEXITCODE -ne 0) { throw "$What failed (exit $LASTEXITCODE)" }
}

$running = Get-Process -Name claude -ErrorAction SilentlyContinue
if ($running -and -not $Force) {
  Write-Warning ("Claude is running ($(@($running).Count) process(es)), skipped. " +
    'Close all Claude sessions and rerun, or pass -Force.')
  exit 0
}

if (-not (Test-Path -Path (Join-Path -Path $lccRepo -ChildPath '.git'))) { throw "lcc repo not found: $lccRepo" }

try {
  # Network first: a failed fetch must not leave the binary restored to stock but unpatched.
  Invoke-Native 'git fetch origin' { git -C $lccRepo fetch origin }

  # Stock binary first, so a version change does not start from a patched one.
  Invoke-Native 'tweakcc-fixed --restore' { bunx --bun $tweakcc --restore }

  if ($ClaudeVersion) {
    Invoke-Native "claude install $ClaudeVersion" { claude install $ClaudeVersion }
  }

  $versionLine = (claude --version 2>&1 | Select-Object -First 1) -as [string]
  if ($versionLine -notmatch '^(\d+\.\d+\.\d+)') { throw "Cannot parse installed version from: $versionLine" }
  $installed = [version]$Matches[1]

  # Oldest commit (on origin/main) whose subject names a CC version newer than installed -> use its parent.
  $target = 'origin/main'
  $log = git -C $lccRepo log --format='%H %s' origin/main
  if ($LASTEXITCODE -ne 0) { throw 'git log failed' }
  $firstNewer = $null
  foreach ($line in $log) {
    $bumpPattern = '^(?<sha>[0-9a-f]{40}) .*Claude Code (?<ver>\d+\.\d+\.\d+)'
    if ($line -match $bumpPattern -and [version]$Matches['ver'] -gt $installed) {
      $firstNewer = $Matches['sha']   # keep overwriting: ends as the oldest match
    }
  }
  if ($firstNewer) { $target = "$firstNewer^" }

  Invoke-Native "git reset --hard $target" { git -C $lccRepo reset --hard $target }
  Invoke-Native 'git clean -fd' { git -C $lccRepo clean -fd }

  Invoke-Native 'tweakcc-fixed --fetch-system-prompts' { bunx --bun $tweakcc --fetch-system-prompts }
} catch {
  $err = $_
  # Write-Error would throw under 'Stop' and skip the exit code below.
  Write-Error -Message $err.Exception.Message -ErrorAction Continue
  exit 1
}

Write-Host '==> tweakcc-fixed --apply'
bunx --bun $tweakcc --apply
$applyExit = $LASTEXITCODE   # captured now: the version/log calls below overwrite $LASTEXITCODE

Write-Host ''
Write-Host "Installed : $(claude --version 2>&1 | Select-Object -First 1)"
Write-Host "lcc commit: $(git -C $lccRepo log -1 --format='%h %s')"
Write-Host "Apply     : $(if ($applyExit -eq 0) { 'OK' } else { "FAILED (exit $applyExit)" })"
if ($applyExit -ne 0) { exit 1 }
