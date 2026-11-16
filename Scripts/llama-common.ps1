#Requires -Version 5.1
<#
.SYNOPSIS
Shared helpers that run the local llama.cpp router for ai-local.ps1.
.DESCRIPTION
Dot-source this file, then call Get-LlamaLayout and Start-LlamaRouter. Both launchers drive one
llama-server in router mode on 127.0.0.1:8080 with two uncensored models that load on demand,
one at a time (8 GB GPU): qwen3.8-35b-a3b (default, abliterated MoE with 3B active, experts partly in
RAM) and qwen3.8-9b-exec (small, fully on the GPU, thinking off). The preset ini is generated here so model paths can follow $HOME and the
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
    MidFile         = Join-Path -Path $ModelsDirectory -ChildPath 'Qwen3.8-35B-A3B-Abliterated\Qwen3.8-35B-A3B-Distill.APEX-I-MiniPlus-V2.1-Abliterated.gguf'
    ExecFile        = Join-Path -Path $ModelsDirectory -ChildPath 'Qwen3.8-9B-Heretic\Qwen3.8-9B-heretic-uncensored.Q4_K_M.gguf'
    ExecTemplate    = Join-Path -Path $Directory -ChildPath 'qwen38-9b-chat-template.jinja'
    Url             = 'http://127.0.0.1:8080'
    MidTemplate     = Join-Path -Path $Directory -ChildPath 'qwen38-35b-chat-template.jinja'
    MidModel        = 'qwen3.8-35b-a3b'
    ExecModel       = 'qwen3.8-9b-exec'
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
  Measured on the RTX 2080 Super: the 35B MoE ran ~33 tok/s generation, ~630 tok/s prompt at
  n-cpu-moe 36 (5-6.3 GB VRAM); the 9B ~59-67 tok/s generation, ~1,350 tok/s prompt.
  Mid model via pi (omp, ~11.5k-token prompt): 5.6 GB VRAM, prompt ~600 tok/s. Generation by spec-type on an edit-style prompt (same task, 3 runs each): none ~31 tok/s;
  ngram-mod 29-38 tok/s, with 87% draft acceptance when the reply copies file text but 3% on fresh text;
  ngram-cache 15-27 tok/s (acceptance 21-54%, slower than none). ngram-mod is kept: it never fell
  meaningfully below none and gains ~20% on copy-heavy edits. llama-bench n-cpu-moe sweep (q8_0 KV, fa on, ub 1024): 36 -> 685 pp / 27 tg; 32 -> 849 / 36;
  28 -> 872 / 36; 24 -> CUDA out of memory. Default is 32 (28 is no faster in generation and leaves less VRAM).
  MTP drafting on the 35B failed with a CUDA0 buffer allocation error; n-gram drafting needs no VRAM.
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)][pscustomobject]$Layout,
    [Parameter(Mandatory)][string]$Path,
    # Lower this to move more mid-model expert layers onto the GPU (32 won the sweep; 24 runs out of VRAM).
    [ValidateRange(0, 40)][int]$NCpuMoe = 32,
    # Execution window. The 9B KV cache is expensive, so 64k is the practical ceiling on 8 GB.
    [ValidateRange(16384, 98304)][int]$ExecCtx = 65536,
    # Mid-model window.
    [ValidateRange(16384, 131072)][int]$MidCtx = 131072,
    # n-gram drafting predicts repeated file text and needs no VRAM.
    [ValidateSet('none', 'ngram-mod', 'ngram-cache')][string]$SpecType = 'ngram-mod'
  )

  $mid = ConvertTo-LlamaIniPath $Layout.MidFile
  $midTemplate = ConvertTo-LlamaIniPath $Layout.MidTemplate
  $slots = ConvertTo-LlamaIniPath (Join-Path -Path $Layout.Directory -ChildPath 'slots')
  $exec = ConvertTo-LlamaIniPath $Layout.ExecFile
  $execTemplate = ConvertTo-LlamaIniPath $Layout.ExecTemplate
  $header = @"
version = 1

[*]
jinja = true
flash-attn = on
parallel = 1
load-on-startup = false
stop-timeout = 20
; Lets a warm prompt-cache slot be saved and restored across server restarts.
slot-save-path = $slots

"@
  $specLine = if ($SpecType -eq 'none') { '; spec-type none' } else { "spec-type = $SpecType" }
  $midSection = @"
[$($Layout.MidModel)]
model = $mid
chat-template-file = $midTemplate
n-gpu-layers = 99
n-cpu-moe = $NCpuMoe
batch-size = 2048
ubatch-size = 1024
ctx-size = $MidCtx
cache-type-k = q8_0
cache-type-v = q8_0
$specLine
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
  # Skip sections whose GGUF is absent so one missing model cannot block the others.
  $ini = $header
  if (Test-Path -LiteralPath $Layout.MidFile) { $ini += $midSection }
  if (Test-Path -LiteralPath $Layout.ExecFile) { $ini += $execSection }
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
    [ValidateRange(0, 40)][int]$NCpuMoe = 32,
    [ValidateRange(16384, 98304)][int]$ExecCtx = 65536,
    [ValidateRange(16384, 131072)][int]$MidCtx = 131072,
    [ValidateSet('none', 'ngram-mod', 'ngram-cache')][string]$SpecType = 'ngram-mod',
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
    $Layout.MidModel { @($Layout.MidFile, $Layout.MidTemplate) }
    $Layout.ExecModel { @($Layout.ExecFile, $Layout.ExecTemplate) }
    default { throw "Unknown model '$Model'" }
  }
  $missing = @(@($Layout.Server) + $required | Where-Object { -not (Test-Path -LiteralPath $_) })
  if ($missing.Count -gt 0) {
    $hint = if ($Model -eq $Layout.MidModel) {
      "`nDownload: uvx --from huggingface_hub hf download IsValorum/Qwen3.8-35B-A3B-Distill-MTP-APEX-I-MiniPlus-V2.1-Abliterated-GGUF " +
      "Qwen3.8-35B-A3B-Distill.APEX-I-MiniPlus-V2.1-Abliterated.gguf --local-dir " +
      "<ModelsDirectory>\Qwen3.8-35B-A3B-Abliterated, or use -Small."
    } else { '' }
    throw "Missing files:`n$($missing -join "`n")$hint"
  }

  # The mid model (~10 GB commit) plus the client and its MCP servers need ~14 GB of free
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
  # llama-server refuses a --slot-save-path that does not exist.
  $null = New-Item -ItemType Directory -Force -Path (Join-Path -Path $Layout.Directory -ChildPath 'slots')
  $presetFile = Join-Path -Path $Layout.LogDirectory -ChildPath 'models.generated.ini'
  Write-LlamaPreset -Layout $Layout -Path $presetFile -NCpuMoe $NCpuMoe -ExecCtx $ExecCtx -MidCtx $MidCtx -SpecType $SpecType

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
