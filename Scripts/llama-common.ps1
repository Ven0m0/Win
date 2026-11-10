#Requires -Version 5.1
<#
.SYNOPSIS
Shared helpers that run the local llama.cpp router for claude-local.ps1 and opencode-local.ps1.
.DESCRIPTION
Dot-source this file, then call Get-LlamaLayout and Start-LlamaRouter. Both launchers drive one
llama-server in router mode on 127.0.0.1:8080 with three uncensored models that load on demand,
one at a time (8 GB GPU): gemma-4-31b-heretic (default, dense 31B, most layers in RAM),
qwen3.8-35b-a3b (planning, MoE experts partly in RAM) and qwen3.8-9b-exec (execution, fully on
the GPU, thinking off). The preset ini is generated here so model paths can follow $HOME and the
layer split can be tuned per launch. A model section is written only when its GGUF exists.
#>
$ErrorActionPreference = 'Stop'

function Get-LlamaLayout {
  <#
  .SYNOPSIS
  Resolves the llama.cpp install, the GGUF files and the patched chat templates.
  .OUTPUTS
  PSCustomObject
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param (
    # llama-server.exe, the chat templates and the logs live here; LLAMA_CPP_DIR overrides ~\llama.cpp.
    [string]$Directory = $(if ($env:LLAMA_CPP_DIR) { $env:LLAMA_CPP_DIR } else { Join-Path -Path $HOME -ChildPath 'llama.cpp' }),

    # Models are kept in one directory per repo.
    [string]$ModelsDirectory = (Join-Path -Path $HOME -ChildPath 'models')
  )

  [pscustomobject]@{
    Directory       = $Directory
    Server          = Join-Path -Path $Directory -ChildPath 'llama-server.exe'
    LogDirectory    = Join-Path -Path $Directory -ChildPath 'logs'
    ModelsDirectory = $ModelsDirectory
    PlanFile        = Join-Path -Path $ModelsDirectory -ChildPath 'Qwen3.8-35B-A3B-Abliterated\Qwen3.8-35B-A3B-Distill.APEX-I-MiniPlus-V2.1-Abliterated.gguf'
    ExecFile        = Join-Path -Path $ModelsDirectory -ChildPath 'Qwen3.8-9B-Heretic\Qwen3.8-9B-heretic-uncensored.Q4_K_M.gguf'
    PlanTemplate    = Join-Path -Path $Directory -ChildPath 'qwen38-35b-chat-template.jinja'
    ExecTemplate    = Join-Path -Path $Directory -ChildPath 'qwen38-9b-chat-template.jinja'
    GemmaFile       = Join-Path -Path $ModelsDirectory -ChildPath 'Gemma-4-31B-ARA-Heretic\gemma-4-31B-it-ARA-heretic.IQ4_XS.gguf'
    Url             = 'http://127.0.0.1:8080'
    PlanModel       = 'qwen3.8-35b-a3b'
    ExecModel       = 'qwen3.8-9b-exec'
    GemmaModel      = 'gemma-4-31b-heretic'
  }
}

function ConvertTo-LlamaIniPath ($Path) {
  # Forward slashes: backslashes are escape characters in some ini parsers.
  $Path -replace '\\', '/'
}

function ConvertTo-RangeValue {
  <#
  .SYNOPSIS
  Validates a hand-parsed numeric switch value and returns it as an int.
  #>
  [CmdletBinding()]
  [OutputType([int])]
  param (
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Value,
    [Parameter(Mandatory)][int]$Minimum,
    [Parameter(Mandatory)][int]$Maximum
  )

  $number = 0
  if (-not [int]::TryParse($Value, [ref]$number) -or $number -lt $Minimum -or $number -gt $Maximum) {
    throw "$Name needs an integer between $Minimum and $Maximum, got '$Value'"
  }
  $number
}

function Write-LlamaPreset {
  <#
  .SYNOPSIS
  Writes the router preset ini for every model whose GGUF exists.
  .DESCRIPTION
  Measured on the RTX 2080 Super: planning ~33 tok/s generation, ~630 tok/s prompt processing at
  n-cpu-moe 36 (5-6.3 GB VRAM); execution ~67 tok/s at 6.4 GB VRAM; Gemma 31B ~2.1 tok/s
  generation, ~66 tok/s prompt processing (2.6k-token prompt, 128k window, 7 GB VRAM). Gemma with
  -ub 1024 doubled prompt speed to 124 tok/s but cut generation to 1.6 tok/s; -ub 512 is kept
  because Claude Code resends little new prompt per turn. MTP drafting and threads were not tried.
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)][pscustomobject]$Layout,
    [Parameter(Mandatory)][string]$Path,
    # Lower this to move more planning-model expert layers onto the GPU; 36 leaves ~1.9 GB free.
    [ValidateRange(0, 40)][int]$NCpuMoe = 36,
    # Execution window. The 9B KV cache is expensive, so 64k is the practical ceiling on 8 GB.
    [ValidateRange(16384, 98304)][int]$ExecCtx = 65536,
    # Gemma window; llama-server's fit logic offloads layers and KV cache as needed.
    [ValidateRange(16384, 131072)][int]$GemmaCtx = 131072
  )

  $gemma = ConvertTo-LlamaIniPath $Layout.GemmaFile
  $plan = ConvertTo-LlamaIniPath $Layout.PlanFile
  $exec = ConvertTo-LlamaIniPath $Layout.ExecFile
  $planTemplate = ConvertTo-LlamaIniPath $Layout.PlanTemplate
  $execTemplate = ConvertTo-LlamaIniPath $Layout.ExecTemplate
  $header = @"
version = 1

[*]
jinja = true
flash-attn = on
parallel = 1
load-on-startup = false
stop-timeout = 20

"@
  $planSection = @"
[$($Layout.PlanModel)]
model = $plan
chat-template-file = $planTemplate
n-gpu-layers = 99
n-cpu-moe = $NCpuMoe
batch-size = 2048
; 1024 keeps the prompt-processing buffers small enough for 128k context on 8 GB.
ubatch-size = 1024
ctx-size = 131072
cache-type-k = q8_0
cache-type-v = q8_0

temp = 1.0
top-p = 0.95
top-k = 20
min-p = 0
presence-penalty = 1.5

"@
  $execSection = @"
[$($Layout.ExecModel)]
model = $exec
chat-template-file = $execTemplate
n-gpu-layers = 99
batch-size = 2048
ubatch-size = 1024
ctx-size = $ExecCtx
; q8_0 KV does not fit next to the 9B weights, and q4_0 measured no slower on short turns.
cache-type-k = q4_0
cache-type-v = q4_0
; Execution follows a plan; thinking costs 3-5k tokens per turn on this model.
reasoning-budget = 0
temp = 0.7
top-p = 0.8
top-k = 20
min-p = 0

"@
  $gemmaSection = @"
[$($Layout.GemmaModel)]
model = $gemma
; Dense 31B IQ4_XS is 16.9 GB, so it cannot fit in 8 GB VRAM; llama-server's fit logic
; picks how many layers go on the GPU. Chat template comes from the GGUF (jinja = true above).
fit = on
batch-size = 1024
ubatch-size = 512
ctx-size = $GemmaCtx
cache-type-k = q8_0
cache-type-v = q8_0
temp = 1.0
top-p = 0.95
top-k = 64

"@
  # Skip sections whose GGUF is absent so one missing model cannot block the others.
  $ini = $header
  if (Test-Path -LiteralPath $Layout.PlanFile) { $ini += $planSection }
  if (Test-Path -LiteralPath $Layout.ExecFile) { $ini += $execSection }
  if (Test-Path -LiteralPath $Layout.GemmaFile) { $ini += $gemmaSection }
  Set-Content -Path $Path -Value $ini -Encoding ascii
}

function Test-LlamaRouter {
  <#
  .SYNOPSIS
  Returns true when llama-server answers its health endpoint.
  #>
  [CmdletBinding()]
  [OutputType([bool])]
  param (
    [string]$Url = 'http://127.0.0.1:8080'
  )

  $response = curl.exe -s -m 3 "$Url/health"
  [bool]($response -match '"ok"')
}

function Test-TcpPort {
  <#
  .SYNOPSIS
  Returns true when something is listening on the local TCP port.
  #>
  [CmdletBinding()]
  [OutputType([bool])]
  param (
    [Parameter(Mandatory)][int]$Port
  )

  $client = [System.Net.Sockets.TcpClient]::new()
  try {
    $client.Connect('127.0.0.1', $Port)
    $true
  } catch {
    $false
  } finally {
    $client.Dispose()
  }
}

function Start-LlamaRouter {
  <#
  .SYNOPSIS
  Starts llama-server in router mode when it is not already serving, and waits for health.
  .OUTPUTS
  PSCustomObject with Started (bool) and Process (the started llama-server, or $null).
  #>
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([pscustomobject])]
  param (
    [Parameter(Mandatory)][pscustomobject]$Layout,
    [ValidateRange(0, 40)][int]$NCpuMoe = 36,
    [ValidateRange(16384, 98304)][int]$ExecCtx = 65536,
    [ValidateRange(16384, 131072)][int]$GemmaCtx = 131072,
    # Model id the caller will use; only that model's files are required.
    [Parameter(Mandatory)][string]$Model,
    [ValidateRange(30, 900)][int]$TimeoutSeconds = 360
  )

  if (Test-LlamaRouter -Url $Layout.Url) {
    # A router started from an older preset may lack the requested model; fail here, not inside the client.
    $served = curl.exe -s -m 5 "$($Layout.Url)/models"
    if ($served -notmatch [regex]::Escape("`"$Model`"")) {
      throw "llama-server is running without $Model; stop it (Stop-Process -Name llama-server) and retry"
    }
    return [pscustomobject]@{ Started = $false; Process = $null }
  }

  $required = switch ($Model) {
    $Layout.GemmaModel { @($Layout.GemmaFile) }
    $Layout.PlanModel { @($Layout.PlanFile, $Layout.PlanTemplate) }
    $Layout.ExecModel { @($Layout.ExecFile, $Layout.ExecTemplate) }
    default { throw "Unknown model '$Model'" }
  }
  $missing = @(@($Layout.Server) + $required | Where-Object { -not (Test-Path -LiteralPath $_) })
  if ($missing.Count -gt 0) {
    $hint = if ($Model -eq $Layout.GemmaModel) { "`nRun Scripts\install-gemma.ps1 to download it." } else { '' }
    throw "Missing files:`n$($missing -join "`n")$hint"
  }

  # The planning model (~10 GB commit) plus the client and its MCP servers need ~14 GB of free
  # commit; below that MCP servers fail to start and the model pages to disk.
  $freeCommitGb = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreeVirtualMemory / 1MB, 1)
  if ($freeCommitGb -lt 14) {
    $hogs = Get-Process | Sort-Object -Property PrivateMemorySize64 -Descending |
      Select-Object -First 3 | ForEach-Object {
        '{0} ({1:N1} GB)' -f $_.ProcessName, ($_.PrivateMemorySize64 / 1GB)
      }
    Write-Warning "Only $freeCommitGb GB of commit memory free. Close big processes first: $($hogs -join ', ')"
  }

  $null = New-Item -ItemType Directory -Force -Path $Layout.LogDirectory
  $presetFile = Join-Path -Path $Layout.LogDirectory -ChildPath 'models.generated.ini'
  Write-LlamaPreset -Layout $Layout -Path $presetFile -NCpuMoe $NCpuMoe -ExecCtx $ExecCtx -GemmaCtx $GemmaCtx

  if (-not $PSCmdlet.ShouldProcess($Layout.Server, 'Start llama-server router')) {
    return [pscustomobject]@{ Started = $false; Process = $null }
  }

  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $serverProc = @{
    FilePath               = $Layout.Server
    ArgumentList           = @(
      '--models-preset', "`"$presetFile`"", '--models-max', '1', '--host', '127.0.0.1', '--port', '8080'
    )
    WindowStyle            = 'Hidden'
    RedirectStandardOutput = Join-Path -Path $Layout.LogDirectory -ChildPath "router-$stamp.out.log"
    RedirectStandardError  = Join-Path -Path $Layout.LogDirectory -ChildPath "router-$stamp.err.log"
    PassThru               = $true
  }
  $process = Start-Process @serverProc

  Write-Host 'Starting llama-server router (models load on first use)...'
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while (-not (Test-LlamaRouter -Url $Layout.Url)) {
    if ($process.HasExited) {
      throw "llama-server exited with code $($process.ExitCode); see $($Layout.LogDirectory)"
    }
    if ((Get-Date) -gt $deadline) {
      throw "llama-server did not become healthy in $TimeoutSeconds s; see $($Layout.LogDirectory)"
    }
    Start-Sleep -Seconds 3
  }

  [pscustomobject]@{ Started = $true; Process = $process }
}
