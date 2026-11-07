#Requires -Version 5.1
<#
.SYNOPSIS
Runs OpenCode against the local uncensored Qwen3.8 models served by llama-server.
.DESCRIPTION
Starts the llama.cpp router if it is not already up, selects the local provider through
OPENCODE_CONFIG_CONTENT, and stops the server afterwards when this script started it. The model
loads on first use: qwen3.8-35b-a3b (~33 tok/s, MoE with experts partly in RAM) by default, or
qwen3.8-9b-exec (~67 tok/s, thinking off) with -Small.
Traffic goes through a Headroom proxy (prompt compression) when it is installed; -NoHeadroom
talks to llama-server directly. Headroom's own `wrap opencode` is not used: it rewrites the
global opencode config and its transient proxy port, so this script runs a private proxy on
127.0.0.1:8788 that the `headroom-local` provider points at.
All other arguments are passed to opencode unchanged, for example -c to continue a session.
.PARAMETER Small
Uses qwen3.8-9b-exec instead of the 35B.
.PARAMETER KeepServer
Leaves llama-server running when this script started it.
.PARAMETER NoHeadroom
Skips the Headroom proxy and calls llama-server directly.
.PARAMETER RouterNCpuMoe
Expert layers kept in RAM for the 35B (0-40, default 36).
.PARAMETER ExecCtx
Context size for the 9B (16384-98304, default 65536).
.EXAMPLE
opencode-local
.EXAMPLE
opencode-local -Small -c
.EXAMPLE
opencode-local run "explain this repository"
#>
$ErrorActionPreference = 'Stop'
. (Join-Path -Path $PSScriptRoot -ChildPath 'llama-common.ps1')

# No param block: any [Parameter] attribute enables common parameters, which would capture
# opencode flags. Only the switches below are consumed; everything else is forwarded verbatim.
$Small = $false
$KeepServer = $false
$NoHeadroom = $false
$NCpuMoe = 36
$ExecCtx = 65536
$OpenCodeArgs = [System.Collections.Generic.List[string]]::new()

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
  Starts `headroom proxy` for the local llama-server and waits until it reports ready.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param (
    [Parameter(Mandatory)][pscustomobject]$Layout,
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

  $null = New-Item -ItemType Directory -Force -Path $Layout.LogDirectory
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $proxyProc = @{
    FilePath               = (Get-Command -Name 'headroom' -CommandType Application).Source
    ArgumentList           = @(
      'proxy', '--port', "$Port", '--openai-api-url', "$($Layout.Url)/v1"
    )
    WindowStyle            = 'Hidden'
    RedirectStandardOutput = Join-Path -Path $Layout.LogDirectory -ChildPath "headroom-$stamp.out.log"
    RedirectStandardError  = Join-Path -Path $Layout.LogDirectory -ChildPath "headroom-$stamp.err.log"
    PassThru               = $true
  }
  $process = Start-Process @proxyProc

  $deadline = (Get-Date).AddSeconds(60)
  while (-not (Test-HeadroomReady -Url $url)) {
    if ($process.HasExited) {
      throw "headroom proxy exited with code $($process.ExitCode); see $($Layout.LogDirectory)"
    }
    if ((Get-Date) -gt $deadline) {
      throw "headroom proxy did not become ready; see $($Layout.LogDirectory)"
    }
    Start-Sleep -Milliseconds 500
  }

  [pscustomobject]@{ Started = $true; Process = $process; Port = $Port }
}

$layout = Get-LlamaLayout
$router = Start-LlamaRouter -Layout $layout -NCpuMoe $NCpuMoe -ExecCtx $ExecCtx
$model = if ($Small) { $layout.ExecModel } else { $layout.PlanModel }

$headroom = Get-Command -Name 'headroom' -CommandType Application -ErrorAction SilentlyContinue
$proxy = $null
$provider = 'llama-local'
try {
  if ($headroom -and -not $NoHeadroom) {
    # 8788 is the port the headroom-local provider points at in the opencode config.
    $proxy = Start-HeadroomProxy -Layout $layout -Port 8788
    $provider = 'headroom-local'
    Write-Host "OpenCode -> Headroom (:$($proxy.Port)) -> llama-server (use -NoHeadroom to skip Headroom)."
  }

  $savedContent = $env:OPENCODE_CONFIG_CONTENT
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
  if ($router.Started -and -not $KeepServer) {
    Stop-Process -Name 'llama-server' -Force -ErrorAction SilentlyContinue
  }
}
