#Requires -Version 5.1
<#
.SYNOPSIS
Runs Claude Code against the local uncensored Qwen3.8 models served by llama-server.
.DESCRIPTION
Starts the llama.cpp router if it is not already up, points Claude Code at it through the
Anthropic-compatible /v1/messages endpoint, and stops the server afterwards when this script
started it. The model loads on first use: qwen3.8-35b-a3b (MoE, experts partly in RAM, ~33 tok/s)
by default, or qwen3.8-9b-exec (fully on the GPU, thinking off, ~67 tok/s) with -Small.
Every model tier maps to the same model on purpose: separate tiers make Claude Code reload the
13 GB planning model mid-conversation, roughly 40 s per swap.
Traffic goes through Headroom (prompt compression) when it is installed; -NoHeadroom talks to
llama-server directly. Config, MCP servers, skills, agents and hooks come from the normal
~/.claude setup.
.PARAMETER Small
Uses qwen3.8-9b-exec for every tier instead of the 35B. Faster, 64k window.
.PARAMETER KeepServer
Leaves llama-server running when this script started it.
.PARAMETER NoHeadroom
Skips the Headroom proxy and calls llama-server directly.
.PARAMETER RouterNCpuMoe
Expert layers kept in RAM for the 35B (0-40, default 36). Lower puts more on the GPU.
.PARAMETER ExecCtx
Context size for the 9B (16384-98304, default 65536).
.EXAMPLE
claude-local
.EXAMPLE
claude-local -Small -p "summarize this repo"
.EXAMPLE
claude-local -NoHeadroom -RouterNCpuMoe 30
#>
$ErrorActionPreference = 'Stop'
. (Join-Path -Path $PSScriptRoot -ChildPath 'llama-common.ps1')

# No param block: any [Parameter] attribute enables common parameters, which would capture claude
# flags such as -p. Only the switches below are consumed; everything else is forwarded verbatim.
$Small = $false
$KeepServer = $false
$NoHeadroom = $false
$NCpuMoe = 36
$ExecCtx = 65536
$ClaudeArgs = [System.Collections.Generic.List[string]]::new()

for ($index = 0; $index -lt $args.Count; $index++) {
  $argument = $args[$index]
  if ($argument -eq '-Small') {
    $Small = $true
  } elseif ($argument -eq '-KeepServer') {
    $KeepServer = $true
  } elseif ($argument -eq '-NoHeadroom') {
    $NoHeadroom = $true
  } elseif ($argument -match '^-RouterNCpuMoe(?:=(\d+))?$') {
    $value = if ($Matches[1]) { $Matches[1] } elseif ($index + 1 -lt $args.Count) { $args[++$index] } else { '' }
    $NCpuMoe = ConvertTo-RangeValue -Name '-RouterNCpuMoe' -Value $value -Minimum 0 -Maximum 40
  } elseif ($argument -match '^-ExecCtx(?:=(\d+))?$') {
    $value = if ($Matches[1]) { $Matches[1] } elseif ($index + 1 -lt $args.Count) { $args[++$index] } else { '' }
    $ExecCtx = ConvertTo-RangeValue -Name '-ExecCtx' -Value $value -Minimum 16384 -Maximum 98304
  } else {
    $ClaudeArgs.Add($argument)
  }
}

$layout = Get-LlamaLayout
$router = Start-LlamaRouter -Layout $layout -NCpuMoe $NCpuMoe -ExecCtx $ExecCtx
$model = if ($Small) { $layout.ExecModel } else { $layout.PlanModel }

# Claude Code ignores compaction windows below 100K, so both models need at least that much context.
$envVars = @{
  # No ANTHROPIC_AUTH_TOKEN on purpose: it disables the claude.ai connectors (Gmail, Calendar, GitHub...).
  # The login token is then sent to this local server only, which ignores it.
  ANTHROPIC_BASE_URL                       = $layout.Url
  ANTHROPIC_DEFAULT_OPUS_MODEL             = $model
  ANTHROPIC_DEFAULT_FABLE_MODEL            = $model
  ANTHROPIC_DEFAULT_SONNET_MODEL           = $model
  ANTHROPIC_DEFAULT_HAIKU_MODEL            = $model
  CLAUDE_CODE_SUBAGENT_MODEL               = $model
  CLAUDE_CODE_AUTO_COMPACT_WINDOW          = '100000'
  # A changing attribution header would invalidate llama.cpp's prompt cache every turn.
  CLAUDE_CODE_ATTRIBUTION_HEADER           = '0'
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '1'
}

$savedEnv = @{}
foreach ($name in $envVars.Keys) {
  $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name)
  [Environment]::SetEnvironmentVariable($name, $envVars[$name])
}

# settings.json uses "auto" mode, where a model classifier approves actions; locally that would be
# the uncensored model. Default to prompting you instead; pass --permission-mode to override.
$permissionArgs = @()
if (-not ($ClaudeArgs -match '^--(permission-mode|dangerously-skip-permissions|allow-dangerously-skip-permissions)')) {
  $permissionArgs = @('--permission-mode', 'default')
}

# opusplan keeps plan mode separate; every tier resolves to the same local model.
$modelArgs = @()
if (-not ($ClaudeArgs -match '^--model(=|$)')) {
  $modelArgs = @('--model', 'opusplan')
}

$headroom = Get-Command -Name 'headroom' -CommandType Application -ErrorAction SilentlyContinue

try {
  if ($headroom -and -not $NoHeadroom) {
    # Headroom reads the ANTHROPIC_BASE_URL set above as its upstream, compresses, and forwards to
    # llama-server. It starts a dedicated proxy because the resident cloud proxy routes elsewhere.
    Write-Host 'Claude Code -> Headroom -> llama-server (use -NoHeadroom to skip Headroom).'
    & headroom wrap claude --no-mcp --code-memory none -- @modelArgs @permissionArgs @($ClaudeArgs)
  } else {
    & claude.exe @modelArgs @permissionArgs @($ClaudeArgs)
  }
} finally {
  foreach ($name in $savedEnv.Keys) {
    [Environment]::SetEnvironmentVariable($name, $savedEnv[$name])
  }
  if ($router.Started -and -not $KeepServer) {
    Stop-Process -Name 'llama-server' -Force -ErrorAction SilentlyContinue
  }
}
