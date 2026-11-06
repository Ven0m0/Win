#Requires -Version 5.1
<#
.SYNOPSIS
  PreToolUse advisor for rtk-hostile command shapes.
.DESCRIPTION
  rtk's own hook (`rtk hook claude`) rewrites what it can, but by design refuses
  four shapes: pipelines (only the final stage could ever be filtered, and rtk
  won't guess), command substitution ($(...), backticks, <(...)), a `timeout N`
  prefix (not a registered transparent wrapper), and PowerShell cmdlets (rtk's
  rule table is POSIX-tool-name only). This hook never blocks. For one shape -
  a Bash pipeline whose later stages are only head/tail - it rewrites the first
  stage itself (rtk's hook emits nothing for pipes, so there is no conflicting
  updatedInput). Otherwise it only adds advisory context naming the rtk
  equivalent, so the next command gets rewritten instead of silently passing
  through unfiltered. Delegates every rewrite decision to `rtk hook check` (the
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

function Get-RtkRewrite {
  # rtk hook check writes both its result ("No rewrite for: ..." or the
  # rewritten command) and its "no hook installed" nag banner to STDERR;
  # stdout carries only the rewritten command when one exists, and is empty
  # otherwise. Check stdout alone so the banner can never corrupt the result.
  param([string]$Cmd)
  $out = (& rtk hook check -- $Cmd 2>$null | Out-String).Trim()
  # An already-rtk command comes back unchanged; that is not a rewrite.
  if ($out -and $out -ne $Cmd.Trim()) { $out } else { $null }
}


function Split-Pipeline {
  # Quote-aware split on single `|`: `rg -n 'a|b'` is the common case and a
  # plain -split would cut the pattern. `||` stays inside its stage. Returns
  # $null on unbalanced quotes so callers never act on a misparse.
  param([string]$Cmd)
  $stages = [System.Collections.Generic.List[string]]::new()
  $sb = [System.Text.StringBuilder]::new()
  $quote = [char]0
  for ($i = 0; $i -lt $Cmd.Length; $i++) {
    $c = $Cmd[$i]
    if ($c -eq '\' -and $quote -ne "'" -and $i + 1 -lt $Cmd.Length) {
      $null = $sb.Append($c).Append($Cmd[$i + 1])
      $i++
      continue
    }
    if ($quote -ne [char]0) {
      if ($c -eq $quote) { $quote = [char]0 }
      $null = $sb.Append($c)
      continue
    }
    if ($c -eq '"' -or $c -eq "'") {
      $quote = $c
      $null = $sb.Append($c)
      continue
    }
    if ($c -eq '|') {
      if ($i + 1 -lt $Cmd.Length -and $Cmd[$i + 1] -eq '|') {
        $null = $sb.Append('||')
        $i++
        continue
      }
      $stages.Add($sb.ToString())
      $null = $sb.Clear()
      continue
    }
    $null = $sb.Append($c)
  }
  if ($quote -ne [char]0) { return $null }
  $stages.Add($sb.ToString())
  , $stages
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
if ($messages.Count -eq 0 -and (Get-RtkRewrite -Cmd $command)) {
  exit 0
}

# timeout N cmd: strip the prefix and re-check.
if ($command -match '^\s*timeout\s+\S+\s+(?<rest>.+)$') {
  $rest = $Matches['rest']
  if (Get-RtkRewrite -Cmd $rest) {
    $messages.Add("'timeout N cmd' is not an rtk transparent wrapper. Use the Bash tool's own timeout parameter and run: $rest")
  }
}

# Pipelines: rtk refuses the whole command. When every later stage is a plain
# head/tail (display-only truncation), rewrite the first stage in place. Other
# tails (wc, grep, sort, awk) would compute on rtk-reformatted output, so those
# only get advice.
$stages = if ($command -match '\|') { Split-Pipeline -Cmd $command } else { $null }
if ($stages -and $stages.Count -gt 1) {
  $firstStage = $stages[0] -replace '\s*2>&1\s*$', ''
  $redirect = if ($stages[0] -match '2>&1\s*$') { ' 2>&1' } else { '' }
  $firstStage = $firstStage.Trim()
  $rewritten = if ($firstStage) { Get-RtkRewrite -Cmd $firstStage } else { $null }
  $tails = $stages | Select-Object -Skip 1
  $tailPattern = '^\s*(head|tail)(\s+-[nc]\s*[+-]?\d+|\s+-\d+)?\s*$'
  $allTailsDisplayOnly = @($tails | Where-Object { $_ -notmatch $tailPattern }).Count -eq 0
  $canRewrite = $toolName -eq 'Bash' -and $messages.Count -eq 0 -and $command -notmatch '\n'
  if ($rewritten -and $allTailsDisplayOnly -and $canRewrite) {
    # Keep every other tool_input field (timeout, run_in_background, ...).
    $newInput = $payload.tool_input
    $newInput.command = $rewritten + $redirect + ' |' + ($tails -join '|')
    $result = @{
      hookSpecificOutput = @{
        hookEventName            = 'PreToolUse'
        permissionDecisionReason = 'rtk-advisor pipe rewrite'
        updatedInput             = $newInput
      }
    }
    Write-Output ($result | ConvertTo-Json -Compress -Depth 5)
    exit 0
  }
  if ($rewritten) {
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
