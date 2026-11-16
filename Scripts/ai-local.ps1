#Requires -Version 5.1
<#
.SYNOPSIS
Runs Claude Code, OpenCode or Pi (omp) against a local uncensored model on the llama.cpp router.
.DESCRIPTION
Usage: ai-local.ps1 <claude|opencode|pi> [-Mid|-Small] [-KeepServer|-StopServer] [-NoHeadroom] [options] [tool arguments]

Starts the llama.cpp router (llama-common.ps1) if it is not running and points the chosen tool at it.
Default model is qwen3.8-35b-a3b (-Mid, abliterated MoE with 3B active, experts partly in RAM, ~33 tok/s); -Small selects
qwen3.8-9b-exec (fully on the GPU, thinking off, ~60 tok/s).
claude and opencode stop the router afterwards if this script started it (-KeepServer keeps it). pi keeps it
running by default (-StopServer stops it): the RAM prompt cache survives only while the server runs, so the
next session skips re-reading the ~40k-token agent prompt.
Claude Code and OpenCode traffic goes through Headroom (prompt compression) when installed; -NoHeadroom talks
to the server directly. pi never uses Headroom: it rewrites earlier messages, which breaks the server's
prefix cache (use the `pih` alias for cloud models).

pi: runs `omp --model llama.cpp/<model>`; omp's built-in llama.cpp provider finds the server through
LLAMA_CPP_BASE_URL, set here for the run only.
claude: every model tier maps to the one chosen model on purpose (separate tiers make Claude Code reload the
model mid-conversation). Config, MCP servers, skills, agents and hooks come from the normal ~/.claude setup.
opencode: Headroom's own `wrap opencode` is not used (it rewrites the global opencode config and uses a
transient proxy port); a private proxy on 127.0.0.1:8788 is started that the headroom-local provider uses.

Options (all other arguments are forwarded to the tool unchanged):
  -Mid                  Use qwen3.8-35b-a3b (default).
  -Small                Use qwen3.8-9b-exec.
  -KeepServer           Leave the server running if this script started it (default for pi).
  -StopServer           Stop the server afterwards even for pi.
  -NoHeadroom           Skip the Headroom proxy.
  -ContextLength <n>    Mid-model context window (16384-131072, default 131072). Claude Code ignores
                        compaction windows below 100k, so lower values mean compaction never triggers.
  -RouterNCpuMoe <n>    Expert layers of the mid model kept in RAM (0-40, default 32). Lower puts them on the GPU.
  -SpecType <t>         none, ngram-mod (default) or ngram-cache drafting for the mid model.
  -ExecCtx <n>          Context size of the 9B (16384-98304, default 65536).
.EXAMPLE
pwsh Scripts/ai-local.ps1 claude
.EXAMPLE
pwsh Scripts/ai-local.ps1 pi -Small -p "say hi"
.EXAMPLE
pwsh Scripts/ai-local.ps1 claude -Small -p "hi"
.EXAMPLE
pwsh Scripts/ai-local.ps1 opencode -c
#>
$ErrorActionPreference = 'Stop'
. (Join-Path -Path $PSScriptRoot -ChildPath 'llama-common.ps1')

# No param block: any [Parameter] attribute enables common parameters, which would capture tool
# flags such as -p. Only the switches below are consumed; everything else is forwarded verbatim.
$tool = if ($args.Count -gt 0) { [string]$args[0] } else { '' }
if ($tool -notin @('claude', 'opencode', 'pi')) {
  throw "Usage: ai-local.ps1 <claude|opencode|pi> [-Mid|-Small] [-KeepServer|-StopServer] [-NoHeadroom] [tool arguments]"
}

$Small = $false
$KeepServer = $tool -eq 'pi'
$SpecType = 'ngram-mod'
$NoHeadroom = $false
$NCpuMoe = 32
$ExecCtx = 65536
$ContextLength = 131072
$toolArgs = [System.Collections.Generic.List[string]]::new()
for ($index = 1; $index -lt $args.Count; $index++) {
  $argument = $args[$index]
  if ($argument -eq '-Mid') {
    $Small = $false
  } elseif ($argument -eq '-Small') {
    $Small = $true
  } elseif ($argument -eq '-KeepServer') {
    $KeepServer = $true
  } elseif ($argument -eq '-StopServer') {
    $KeepServer = $false
  } elseif ($argument -match '^-SpecType(?:=(\S+))?$') {
    $SpecType = if ($Matches[1]) { $Matches[1] } elseif ($index + 1 -lt $args.Count) { $args[++$index] } else { '' }
    if ($SpecType -notin @('none', 'ngram-mod', 'ngram-cache')) {
      throw "-SpecType needs none, ngram-mod or ngram-cache, got '$SpecType'"
    }
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
    $toolArgs.Add($argument)
  }
}

function Test-HeadroomReady {
  param ([string]$Url)

  $status = curl.exe -s -o NUL -w '%{http_code}' -m 2 "$Url/readyz"
  $status -eq '200'
}

function Start-HeadroomProxy {
  <#
  .SYNOPSIS
  Starts `headroom proxy` in front of a local OpenAI-compatible server and waits until it reports ready.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param (
    [Parameter(Mandatory)][string]$UpstreamUrl,
    [Parameter(Mandatory)][string]$LogDirectory,
    [Parameter(Mandatory)][int]$Port
  )

  $url = "http://127.0.0.1:$Port"
  if (Test-HeadroomReady -Url $url) {
    return [pscustomobject]@{ Started = $false; Process = $null; Port = $Port }
  }
  if (Test-TcpPort -Port $Port) {
    throw "Port $Port is in use but not a ready Headroom proxy; close it or free the port"
  }

  if (-not $PSCmdlet.ShouldProcess("127.0.0.1:$Port", 'Start Headroom proxy')) {
    return [pscustomobject]@{ Started = $false; Process = $null; Port = $Port }
  }

  $null = New-Item -ItemType Directory -Force -Path $LogDirectory
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $proxyProc = @{
    FilePath               = (Get-Command -Name 'headroom' -CommandType Application).Source
    ArgumentList           = @('proxy', '--port', "$Port", '--openai-api-url', "$UpstreamUrl/v1")
    WindowStyle            = 'Hidden'
    RedirectStandardOutput = Join-Path -Path $LogDirectory -ChildPath "headroom-$stamp.out.log"
    RedirectStandardError  = Join-Path -Path $LogDirectory -ChildPath "headroom-$stamp.err.log"
    PassThru               = $true
  }
  $process = Start-Process @proxyProc

  $deadline = (Get-Date).AddSeconds(60)
  while (-not (Test-HeadroomReady -Url $url)) {
    if ($process.HasExited) {
      throw "headroom proxy exited with code $($process.ExitCode); see $LogDirectory"
    }
    if ((Get-Date) -gt $deadline) {
      throw "headroom proxy did not become ready; see $LogDirectory"
    }
    Start-Sleep -Milliseconds 500
  }

  [pscustomobject]@{ Started = $true; Process = $process; Port = $Port }
}

$layout = Get-LlamaLayout
$model = if ($Small) { $layout.ExecModel } else { $layout.MidModel }
if ($tool -eq 'claude' -and $model -eq $layout.MidModel -and $ContextLength -lt 110000) {
  Write-Warning 'Claude Code ignores compaction windows below 100k; context may overflow before compacting.'
}
$server = Start-LlamaRouter -Layout $layout -NCpuMoe $NCpuMoe -ExecCtx $ExecCtx -MidCtx $ContextLength -SpecType $SpecType -Model $model
$headroom = Get-Command -Name 'headroom' -CommandType Application -ErrorAction SilentlyContinue
$useHeadroom = $headroom -and -not $NoHeadroom -and $tool -ne 'pi'
$savedEnv = @{}
$proxy = $null

try {
  if ($tool -eq 'claude') {
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
  } elseif ($tool -eq 'pi') {
    # bun's --parallel in BUN_OPTIONS turns `bun cli.js` into a script runner, which breaks omp.
    $bunOptions = ([Environment]::GetEnvironmentVariable('BUN_OPTIONS') -replace '(^|\s)--parallel(?=\s|$)', '').Trim()
    $envVars = @{ LLAMA_CPP_BASE_URL = $layout.Url; BUN_OPTIONS = $bunOptions }
  } else {
    $provider = 'llama-local'
    if ($useHeadroom) {
      # 8788 is the port the headroom-local provider points at in the opencode config.
      $proxy = Start-HeadroomProxy -UpstreamUrl $layout.Url -LogDirectory $layout.LogDirectory -Port 8788
      $provider = 'headroom-local'
      Write-Host "OpenCode -> Headroom (:$($proxy.Port)) -> llama-server (use -NoHeadroom to skip Headroom)."
    }
    $envVars = @{
      OPENCODE_CONFIG_CONTENT = [ordered]@{
        model       = "$provider/$model"
        small_model = "$provider/$model"
      } | ConvertTo-Json -Compress
    }
  }
  foreach ($name in $envVars.Keys) {
    $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name)
    [Environment]::SetEnvironmentVariable($name, $envVars[$name])
  }

  if ($tool -eq 'claude') {
    # settings.json uses "auto" mode, where a model classifier approves actions; with a locally
    # uncensored model that is not wanted. Default to prompting; pass --permission-mode to override.
    $permissionArgs = @()
    $permissionFlag = '^--(permission-mode|dangerously-skip-permissions|allow-dangerously-skip-permissions)'
    if (-not ($toolArgs -match $permissionFlag)) {
      $permissionArgs = @('--permission-mode', 'default')
    }
    # opusplan keeps plan mode separate; every tier resolves to the local model.
    $modelArgs = @()
    if (-not ($toolArgs -match '^--model(=|$)')) {
      $modelArgs = @('--model', 'opusplan')
    }

    if ($useHeadroom) {
      # Headroom reads the ANTHROPIC_BASE_URL set above as its upstream, compresses, and forwards to
      # the server. It starts a dedicated proxy because the resident cloud proxy routes elsewhere.
      Write-Host 'Claude Code -> Headroom -> llama-server (use -NoHeadroom to skip Headroom).'
      & headroom wrap claude --no-mcp --code-memory none -- @modelArgs @permissionArgs @($toolArgs)
    } else {
      & claude.exe @modelArgs @permissionArgs @($toolArgs)
    }
  } elseif ($tool -eq 'pi') {
    & omp --model "llama.cpp/$model" @($toolArgs)
  } else {
    # Without --standalone opencode attaches to an already running server that read the global config
    # before this launcher set the model, so the local model would be silently ignored.
    if (-not ($toolArgs -contains '--standalone')) {
      $toolArgs.Insert(0, '--standalone')
    }
    & opencode @($toolArgs)
  }
} finally {
  foreach ($name in $savedEnv.Keys) {
    [Environment]::SetEnvironmentVariable($name, $savedEnv[$name])
  }
  if ($proxy -and $proxy.Started) {
    Stop-Process -Id $proxy.Process.Id -Force -ErrorAction SilentlyContinue
  }
  if ($server.Started -and -not $KeepServer) {
    Stop-Process -Name 'llama-server' -Force -ErrorAction SilentlyContinue
  }
}
