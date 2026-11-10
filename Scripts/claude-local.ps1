#Requires -Version 5.1
<#
.SYNOPSIS
Runs Claude Code against a local uncensored model on the llama.cpp router: Gemma 4 31B by default.
.DESCRIPTION
Starts the llama.cpp router (llama-common.ps1) if it is not running, points Claude Code at its
/v1/messages endpoint and stops the router afterwards if this script started it. Default model is
gemma-4-31b-heretic (dense 31B IQ4_XS, most layers in RAM, ~2 tok/s generation on the 8 GB GPU;
run install-gemma.ps1 once to download it). -Qwen selects qwen3.8-35b-a3b (MoE, experts partly in
RAM, ~33 tok/s) and -Small selects qwen3.8-9b-exec (fully on the GPU, thinking off, ~67 tok/s).
Every model tier maps to the one chosen model on purpose: separate tiers make Claude Code reload
the model mid-conversation.
Traffic goes through Headroom (prompt compression) when installed; -NoHeadroom talks to the server
directly. Config, MCP servers, skills, agents and hooks come from the normal ~/.claude setup.
.PARAMETER Qwen
Uses qwen3.8-35b-a3b instead of Gemma.
.PARAMETER Small
Uses qwen3.8-9b-exec instead of Gemma. 64k window.
.PARAMETER KeepServer
Leaves the server running if this script started it.
.PARAMETER NoHeadroom
Skips the Headroom proxy and calls the server directly.
.PARAMETER ContextLength
Gemma context window (16384-131072, default 131072). Claude Code ignores compaction windows
below 100k, so lower values mean compaction never triggers before the window is full.
.PARAMETER RouterNCpuMoe
Expert layers of the 35B kept in RAM (0-40, default 36). Lower puts them on the GPU.
.PARAMETER ExecCtx
Context size of the 9B (16384-98304, default 65536).
.EXAMPLE
claude-local
.EXAMPLE
claude-local -p "summarize repo"
.EXAMPLE
claude-local -Small -p "hi"
#>
$ErrorActionPreference = 'Stop'
. (Join-Path -Path $PSScriptRoot -ChildPath 'llama-common.ps1')

# No param block: any [Parameter] attribute enables common parameters, which would capture claude
# flags such as -p. Only the switches below are consumed; everything else is forwarded verbatim.
$Qwen = $false
$Small = $false
$KeepServer = $false
$NoHeadroom = $false
$NCpuMoe = 36
$ExecCtx = 65536
$ContextLength = 131072
$ClaudeArgs = [System.Collections.Generic.List[string]]::new()
for ($index = 0; $index -lt $args.Count; $index++) {
  $argument = $args[$index]
  if ($argument -eq '-Qwen') {
    $Qwen = $true
  } elseif ($argument -eq '-Small') {
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
  } elseif ($argument -match '^-ContextLength(?:=(\d+))?$') {
    $value = if ($Matches[1]) { $Matches[1] } elseif ($index + 1 -lt $args.Count) { $args[++$index] } else { '' }
    $ContextLength = ConvertTo-RangeValue -Name '-ContextLength' -Value $value -Minimum 16384 -Maximum 131072
  } else {
    $ClaudeArgs.Add($argument)
  }
}

$layout = Get-LlamaLayout
$model = if ($Small) { $layout.ExecModel } elseif ($Qwen) { $layout.PlanModel } else { $layout.GemmaModel }
if ($model -eq $layout.GemmaModel -and $ContextLength -lt 110000) {
  Write-Warning 'Claude Code ignores compaction windows below 100k; context may overflow before compacting.'
}
$server = Start-LlamaRouter -Layout $layout -NCpuMoe $NCpuMoe -ExecCtx $ExecCtx -GemmaCtx $ContextLength -Model $model

$envVars = @{
  # No ANTHROPIC_AUTH_TOKEN on purpose: disables claude.ai connectors (Gmail, Calendar, GitHub...).
  # The login token would only be sent to the local server, which ignores it.
  ANTHROPIC_BASE_URL                       = $layout.Url
  ANTHROPIC_DEFAULT_OPUS_MODEL             = $model
  ANTHROPIC_DEFAULT_FABLE_MODEL            = $model
  ANTHROPIC_DEFAULT_SONNET_MODEL           = $model
  ANTHROPIC_DEFAULT_HAIKU_MODEL            = $model
  CLAUDE_CODE_SUBAGENT_MODEL               = $model
  # Claude Code ignores compaction windows below 100K, so the model needs at least that much context.
  CLAUDE_CODE_AUTO_COMPACT_WINDOW          = '100000'
  # A changing attribution header would invalidate the server's prompt cache every turn.
  CLAUDE_CODE_ATTRIBUTION_HEADER           = '0'
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '1'
}
$savedEnv = @{}
foreach ($name in $envVars.Keys) {
  $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name)
  [Environment]::SetEnvironmentVariable($name, $envVars[$name])
}

# settings.json uses "auto" mode, where a model classifier approves actions; with a locally
# uncensored model that is not wanted. Default to prompting you instead; pass --permission-mode to override.
$permissionArgs = @()
if (-not ($ClaudeArgs -match '^--(permission-mode|dangerously-skip-permissions|allow-dangerously-skip-permissions)')) {
  $permissionArgs = @('--permission-mode', 'default')
}

# opusplan keeps plan mode separate; every tier resolves to the local model.
$modelArgs = @()
if (-not ($ClaudeArgs -match '^--model(=|$)')) {
  $modelArgs = @('--model', 'opusplan')
}

$headroom = Get-Command -Name 'headroom' -CommandType Application -ErrorAction SilentlyContinue

try {
  if ($headroom -and -not $NoHeadroom) {
    # Headroom reads the ANTHROPIC_BASE_URL set above as its upstream, compresses, and forwards to
    # the server. It starts a dedicated proxy because the resident cloud proxy routes elsewhere.
    Write-Host 'Claude Code -> Headroom -> llama-server (use -NoHeadroom to skip Headroom).'
    & headroom wrap claude --no-mcp --code-memory none -- @modelArgs @permissionArgs @($ClaudeArgs)
  } else {
    & claude.exe @modelArgs @permissionArgs @($ClaudeArgs)
  }
} finally {
  foreach ($name in $savedEnv.Keys) {
    [Environment]::SetEnvironmentVariable($name, $savedEnv[$name])
  }
  if ($server.Started -and -not $KeepServer) {
    Stop-Process -Name 'llama-server' -Force -ErrorAction SilentlyContinue
  }
}
