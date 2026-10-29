#Requires -Version 5.1
<#
.SYNOPSIS
Runs Claude Code against local models served by a llama-server router.
.DESCRIPTION
Starts llama-server in router mode if it is not already up, points Claude Code at it through the
Anthropic-compatible /v1/messages endpoint, and stops the server afterwards when this
script started it. Models load on first use, one at a time: opus/fable -> Qwen3.6-35B-A3B (planning),
sonnet/haiku/subagents -> Qwen3.5-9B (execution). The default --model is opusplan, so plan mode
plans on the 35B and everything else runs on the 9B; each switch reloads a model.
Config, MCP servers, skills, agents and hooks come from the normal ~/.claude setup.
.EXAMPLE
claude-local
.EXAMPLE
claude-local -KeepServer -p "summarize this repo"
#>
$ErrorActionPreference = 'Stop'

# No param block: any [Parameter] attribute enables common parameters, which would capture
# claude flags such as -p. -KeepServer (leave llama-server running) is parsed by hand.
$KeepServer = $args -contains '-KeepServer'
$ClaudeArgs = @($args | Where-Object { $_ -ne '-KeepServer' })

$url = 'http://127.0.0.1:8080'
$planModel = 'qwen3.6-35b-a3b'
$execModel = 'qwen3.5-9b-exec'
# llama-server.exe and the chat template live in the llama.cpp install dir, not next to this script.
$llamaDir = if ($env:LLAMA_CPP_DIR) { $env:LLAMA_CPP_DIR } else { Join-Path -Path $HOME -ChildPath 'llama.cpp' }
$server = Join-Path -Path $llamaDir -ChildPath 'llama-server.exe'
$logDir = Join-Path -Path $llamaDir -ChildPath 'logs'
$models = Join-Path -Path $HOME -ChildPath 'models'
$planFile = 'Qwen3.6-35B-A3B-Uncensored\Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf'
$execFile = 'Qwen3.5-9B-HauhauCS\Qwen3.5-9B-Uncensored-HauhauCS-Aggressive-Q4_K_M.gguf'
# Lower NCpuMoe to move more planning-model expert layers onto the 8 GB GPU.
$nCpuMoe = 36
# Claude Code never compacts below a ~100k window, so the execution model needs at least that much.
$execCtx = 106496

# One endpoint, two models, loaded on demand and only one at a time (8 GB GPU).
function Write-RouterPreset {
  param ([string]$Path)

  # Forward slashes: backslashes are escape characters in some ini parsers.
  $plan = (Join-Path -Path $models -ChildPath $planFile) -replace '\\', '/'
  $exec = (Join-Path -Path $models -ChildPath $execFile) -replace '\\', '/'
  $template = (Join-Path -Path $llamaDir -ChildPath 'qwen36-chat-template.jinja') -replace '\\', '/'
  $ini = @"
version = 1

[*]
jinja = true
; Stock template rejects the mid-conversation system messages Claude Code sends.
chat-template-file = $template
flash-attn = on
parallel = 1
load-on-startup = false
stop-timeout = 20

[$planModel]
model = $plan
n-gpu-layers = 99
n-cpu-moe = $nCpuMoe
batch-size = 2048
ubatch-size = 2048
ctx-size = 131072
cache-type-k = q8_0
cache-type-v = q8_0
temp = 1.0
top-p = 0.95
top-k = 20
min-p = 0
presence-penalty = 1.5

[$execModel]
model = $exec
n-gpu-layers = 99
ctx-size = $execCtx
cache-type-k = q8_0
cache-type-v = q8_0
; Execution follows a plan; thinking costs 3-5k tokens per turn on this model.
reasoning-budget = 0
temp = 0.7
top-p = 0.8
top-k = 20
min-p = 0
"@
  Set-Content -Path $Path -Value $ini -Encoding ascii
}

function Test-ServerHealthy {
  $response = curl.exe -s -m 3 "$url/health"
  [bool]($response -match '"ok"')
}

$startedServer = $false
if (-not (Test-ServerHealthy)) {
  if (-not (Test-Path -LiteralPath $server)) {
    throw "llama-server.exe not found: $server (set LLAMA_CPP_DIR)"
  }
  # The planning model (~10 GB commit) plus Claude Code and its MCP servers need ~14 GB of free commit;
  # below that MCP servers fail to start and the model pages to disk (75 vs 359 prompt tokens/s).
  $freeCommitGb = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreeVirtualMemory / 1MB, 1)
  if ($freeCommitGb -lt 14) {
    $hogs = Get-Process | Sort-Object -Property PrivateMemorySize64 -Descending |
      Select-Object -First 3 | ForEach-Object {
        '{0} ({1:N1} GB)' -f $_.ProcessName, ($_.PrivateMemorySize64 / 1GB)
      }
    Write-Warning "Only $freeCommitGb GB of commit memory free. Close big processes first: $($hogs -join ', ')"
  }

  $null = New-Item -ItemType Directory -Force -Path $logDir
  $presetFile = Join-Path -Path $logDir -ChildPath 'models.generated.ini'
  Write-RouterPreset -Path $presetFile
  $serverProc = @{
    FilePath               = $server
    ArgumentList           = @(
      '--models-preset', "`"$presetFile`"", '--models-max', '1', '--host', '127.0.0.1', '--port', '8080'
    )
    WindowStyle            = 'Hidden'
    RedirectStandardOutput = Join-Path -Path $logDir -ChildPath 'server.out.log'
    RedirectStandardError  = Join-Path -Path $logDir -ChildPath 'server.err.log'
  }
  Start-Process @serverProc
  $startedServer = $true

  Write-Host 'Starting llama-server router (models load on first use)...'
  $deadline = (Get-Date).AddMinutes(6)
  while (-not (Test-ServerHealthy)) {
    if ((Get-Date) -gt $deadline) {
      throw "llama-server did not become healthy; see $logDir"
    }
    Start-Sleep -Seconds 3
  }
}

# Claude Code assumes a 200K window and ignores values below 100K; compact before the local contexts
# overflow (35B: 128K, 9B: ~104K, see the router preset above).
$envVars = @{
  # No ANTHROPIC_AUTH_TOKEN on purpose: it disables the claude.ai connectors (Gmail, Calendar, GitHub...).
  # The login token is then sent to this local server only, which ignores it.
  ANTHROPIC_BASE_URL                       = $url
  ANTHROPIC_DEFAULT_OPUS_MODEL             = $planModel
  ANTHROPIC_DEFAULT_FABLE_MODEL            = $planModel
  ANTHROPIC_DEFAULT_SONNET_MODEL           = $execModel
  ANTHROPIC_DEFAULT_HAIKU_MODEL            = $execModel
  CLAUDE_CODE_SUBAGENT_MODEL               = $execModel
  CLAUDE_CODE_AUTO_COMPACT_WINDOW          = '100000'
  # A changing attribution header would invalidate llama.cpp's prompt cache every turn.
  CLAUDE_CODE_ATTRIBUTION_HEADER           = '0'
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '1'
}

$saved = @{}
foreach ($name in $envVars.Keys) {
  $saved[$name] = [Environment]::GetEnvironmentVariable($name)
  [Environment]::SetEnvironmentVariable($name, $envVars[$name])
}

# settings.json uses "auto" mode, where a model classifier approves actions; locally that would be
# the uncensored model. Default to prompting you instead; pass --permission-mode to override.
$permissionArgs = @()
if (-not ($ClaudeArgs -match '^--(permission-mode|dangerously-skip-permissions|allow-dangerously-skip-permissions)')) {
  $permissionArgs = @('--permission-mode', 'default')
}

# opusplan: opus-tier model in plan mode, sonnet-tier otherwise. Pass --model to override.
$modelArgs = @()
if (-not ($ClaudeArgs -match '^--model(=|$)')) {
  $modelArgs = @('--model', 'opusplan')
}

try {
  & claude.exe @modelArgs @permissionArgs @ClaudeArgs
} finally {
  foreach ($name in $saved.Keys) {
    [Environment]::SetEnvironmentVariable($name, $saved[$name])
  }
  if ($startedServer -and -not $KeepServer) {
    Stop-Process -Name 'llama-server' -Force -ErrorAction SilentlyContinue
  }
}
