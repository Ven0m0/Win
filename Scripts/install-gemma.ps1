#Requires -Version 5.1
<#
.SYNOPSIS
Downloads the Gemma 4 31B ARA-heretic GGUF used by claude-local.ps1 and opencode-local.ps1.
.DESCRIPTION
Fetches the GGUF with `uvx --from huggingface_hub hf download` into ~\models\Gemma-4-31B-ARA-Heretic on the
Windows host, where llama-common.ps1 expects it. The download is skipped when the file already exists.
.PARAMETER Quant
GGUF quant to download (file gemma-4-31B-it-ARA-heretic.<Quant>.gguf). llama-common.ps1 expects IQ4_XS.
.EXAMPLE
pwsh -File Scripts/install-gemma.ps1 -WhatIf
.EXAMPLE
pwsh -File Scripts/install-gemma.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param (
  [ValidatePattern('^[A-Za-z0-9_]+$')][string]$Quant = 'IQ4_XS'
)

$ErrorActionPreference = 'Stop'

$modelRepo = 'mradermacher/gemma-4-31B-it-ARA-heretic-GGUF'
$modelFile = "gemma-4-31B-it-ARA-heretic.$Quant.gguf"
$modelDir = Join-Path -Path $HOME -ChildPath 'models\Gemma-4-31B-ARA-Heretic'

if (Test-Path -LiteralPath (Join-Path -Path $modelDir -ChildPath $modelFile)) {
  Write-Host "[OK] $modelFile already present in $modelDir"
  return
}
if (-not (Get-Command -Name 'uvx' -CommandType Application -ErrorAction SilentlyContinue)) {
  throw 'uvx not found; install uv first'
}
if ($PSCmdlet.ShouldProcess($modelDir, "Download $modelFile (about 17 GB)")) {
  & uvx --from huggingface_hub hf download $modelRepo $modelFile --local-dir $modelDir
  if ($LASTEXITCODE -ne 0) {
    throw "hf download failed with exit code $LASTEXITCODE"
  }
  Write-Host "[OK] $modelFile downloaded to $modelDir"
}
