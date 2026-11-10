#Requires -Version 5.1
<#
.SYNOPSIS
Runs OpenCode against a local uncensored model on the llama.cpp router: Gemma 4 31B by default.
.DESCRIPTION
Starts the llama.cpp router (llama-common.ps1) if it is not running, selects the local provider through
OPENCODE_CONFIG_CONTENT and stops the router afterwards if this script started it. Default model is
gemma-4-31b-heretic (dense 31B IQ4_XS, most layers in RAM, ~2 tok/s generation on the 8 GB GPU; run
install-gemma.ps1 once to download it). -Qwen selects qwen3.8-35b-a3b (~33 tok/s, MoE with experts partly
in RAM) and -Small selects qwen3.8-9b-exec (~67 tok/s, thinking off).
Traffic goes through a Headroom proxy (prompt compression) when installed; -NoHeadroom talks to the server
directly. Headroom's own `wrap opencode` is not used: it rewrites the global opencode config and uses a
transient proxy port, so the script runs a private proxy that the headroom-local provider points at
(127.0.0.1:8788).
All arguments are passed to opencode unchanged, for example -c to continue a session.
.PARAMETER Qwen
Uses qwen3.8-35b-a3b instead of Gemma.
.PARAMETER Small
Uses qwen3.8-9b-exec instead of Gemma.
.PARAMETER KeepServer
Leaves the server running if this script started it.
.PARAMETER NoHeadroom
Skips the Headroom proxy and calls the server directly.
.PARAMETER ContextLength
Gemma context window (16384-131072, default 131072).
.PARAMETER RouterNCpuMoe
Expert layers of the 35B kept in RAM (0-40, default 36).
.PARAMETER ExecCtx
Context size of the 9B (16384-98304, default 65536).
.EXAMPLE
opencode-local
.EXAMPLE
opencode-local -Small -c
.EXAMPLE
opencode-local run "explain repository"
#>
$ErrorActionPreference = 'Stop'
. (Join-Path -Path $PSScriptRoot -ChildPath 'llama-common.ps1')

# No param block: any [Parameter] attribute enables common parameters, which would capture
# opencode flags. Only the switches below are consumed; everything else is forwarded verbatim.
$Qwen = $false
$Small = $false
$KeepServer = $false
$NoHeadroom = $false
$NCpuMoe = 36
$ExecCtx = 65536
$ContextLength = 131072
$OpenCodeArgs = [System.Collections.Generic.List[string]]::new()

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
    $OpenCodeArgs.Add($argument)
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
$model = if ($Small) { $layout.ExecModel } elseif ($Qwen) { $layout.PlanModel } else { $layout.GemmaModel }
$server = Start-LlamaRouter -Layout $layout -NCpuMoe $NCpuMoe -ExecCtx $ExecCtx -GemmaCtx $ContextLength -Model $model
$directProvider = 'llama-local'
$proxyProvider = 'headroom-local'
# 8788 is the port the headroom-local provider points at in the opencode config.
$proxyPort = 8788
$backendName = 'llama-server'

$headroom = Get-Command -Name 'headroom' -CommandType Application -ErrorAction SilentlyContinue
$proxy = $null
$provider = $directProvider
$savedContent = $env:OPENCODE_CONFIG_CONTENT
try {
  if ($headroom -and -not $NoHeadroom) {
    $proxy = Start-HeadroomProxy -UpstreamUrl $layout.Url -LogDirectory $layout.LogDirectory -Port $proxyPort
    $provider = $proxyProvider
    Write-Host "OpenCode -> Headroom (:$($proxy.Port)) -> $backendName (use -NoHeadroom to skip Headroom)."
  }

  $env:OPENCODE_CONFIG_CONTENT = [ordered]@{
    model       = "$provider/$model"
    small_model = "$provider/$model"
  } | ConvertTo-Json -Compress

  # Without --standalone opencode attaches to an already running server that read the global config
  # before this launcher set the model, so the local model would be silently ignored.
  if (-not ($OpenCodeArgs -contains '--standalone')) {
    $OpenCodeArgs.Insert(0, '--standalone')
  }

  & opencode @($OpenCodeArgs)
} finally {
  $env:OPENCODE_CONFIG_CONTENT = $savedContent
  if ($proxy -and $proxy.Started) {
    Stop-Process -Id $proxy.Process.Id -Force -ErrorAction SilentlyContinue
  }
  if ($server.Started -and -not $KeepServer) {
    Stop-Process -Name 'llama-server' -Force -ErrorAction SilentlyContinue
  }
}
