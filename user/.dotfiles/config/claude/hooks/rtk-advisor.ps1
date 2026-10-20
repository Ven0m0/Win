#Requires -Version 5.1
<#
.SYNOPSIS
  PreToolUse advisor for rtk-hostile command shapes.
.DESCRIPTION
  rtk's own hook (`rtk hook claude`) rewrites what it can, but by design refuses
  four shapes: pipelines (only the final stage could ever be filtered, and rtk
  won't guess), command substitution ($(...), backticks, <(...)), a `timeout N`
  prefix (not a registered transparent wrapper), and PowerShell cmdlets (rtk's
  rule table is POSIX-tool-name only). This hook never blocks - it only adds
  advisory context naming the rtk equivalent when one plausibly exists, so the
  next command in the session gets rewritten instead of silently passing through
  unfiltered. Delegates every rewrite decision to `rtk hook check` (the
  documented single source of truth) rather than re-implementing rtk's rules.
#>

$ErrorActionPreference = 'Stop'

try {
  $payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
} catch {
  exit 0
}

$toolName = $payload.tool_name
if ($toolName -ne 'Bash' -and $toolName -ne 'PowerShell') {
  exit 0
}

$command = $payload.tool_input.command
if ([string]::IsNullOrWhiteSpace($command)) {
  exit 0
}

function Test-RtkRewrites {
  # rtk hook check writes both its result ("No rewrite for: ..." or the
  # rewritten command) and its "no hook installed" nag banner to STDERR;
  # stdout carries only the rewritten command when one exists, and is empty
  # otherwise. Check stdout alone so the banner can never corrupt the result.
  param([string]$Cmd)
  $out = (& rtk hook check -- $Cmd 2>$null | Out-String).Trim()
  return -not [string]::IsNullOrEmpty($out)
}

$messages = [System.Collections.Generic.List[string]]::new()

# Command substitution disables rtk for the whole command in the real hook
# (contains_unattestable_construct -> Passthrough), even though `rtk hook check`
# (dry-run) does not model this and misreports it as rewritten. Check this
# first, but do NOT return early - a command can also have a pipeline or an
# unrewritable PowerShell cmdlet, and both deserve their own advice.
# Backtick is PowerShell's escape character and appears constantly in normal
# pwsh commands, so only treat it as substitution for the Bash tool.
$substitutionPattern = if ($toolName -eq 'Bash') { '\$\(|`|<\(|>\(' } else { '\$\(|<\(|>\(' }
if ($command -match $substitutionPattern) {
  $messages.Add('Command substitution ($(...), backtick in Bash, <(...)) disables rtk for the whole command. Split into separate tool calls so each can be rtk-filtered.')
}

# rtk already handles this command (or env/sudo-prefixed, &&/||/; chained, etc).
if ($messages.Count -eq 0 -and (Test-RtkRewrites -Cmd $command)) {
  exit 0
}

# timeout N cmd: strip the prefix and re-check.
if ($command -match '^\s*timeout\s+\S+\s+(?<rest>.+)$') {
  $rest = $Matches['rest']
  if (Test-RtkRewrites -Cmd $rest) {
    $messages.Add("'timeout N cmd' is not an rtk transparent wrapper. Use the Bash tool's own timeout parameter and run: $rest")
  }
}

# Trailing pipeline: rtk only ever rewrites a pipeline's final stage, and only
# when that stage has a rule. Try stripping to the first stage and to a bare
# `2>&1 | tail/head/wc` tail as the two most common patterns.
if ($command -match '\|') {
  $firstStage = ($command -split '\|')[0] -replace '2>&1\s*$', '' -replace '\s+$', ''
  if ($firstStage -and (Test-RtkRewrites -Cmd $firstStage)) {
    $messages.Add("Piping disables rtk on every non-final stage. Drop the pipe - rtk already truncates/filters: $firstStage")
  }
}

# PowerShell cmdlets rtk has no rule for.
$psMap = @{
  'Get-ChildItem'   = 'rtk ls'
  'Get-Content'     = 'rtk read'
  'Select-String'   = 'rtk grep'
  'Get-Item'        = 'rtk ls'
  'Measure-Object'  = 'rtk wc'
  'Select-Object -First' = 'rtk read --max-lines N (or drop the pipe)'
}
foreach ($cmdlet in $psMap.Keys) {
  if ($command -match "\b$cmdlet\b") {
    $messages.Add("$cmdlet has no rtk rule - use $($psMap[$cmdlet]) instead (rtk.exe runs fine from PowerShell).")
    break
  }
}

if ($messages.Count -eq 0) {
  exit 0
}

$context = $messages -join ' '
$result = @{
  hookSpecificOutput = @{
    hookEventName    = 'PreToolUse'
    additionalContext = "[rtk-advisor] $context"
  }
}
Write-Output ($result | ConvertTo-Json -Compress -Depth 5)
exit 0
