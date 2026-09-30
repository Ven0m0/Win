#Requires -Version 5.1
#Requires -Modules PSScriptAnalyzer

<#
.SYNOPSIS
  Lints and/or formats PowerShell scripts using PSScriptAnalyzer.
.DESCRIPTION
  Runs Invoke-ScriptAnalyzer and Invoke-Formatter against one or more files or
  directories, using the repo's PSScriptAnalyzerSettings.psd1. Mirrors the
  checks the lint-format-test.yml CI workflow performs, so issues can be
  caught locally before a push.
.PARAMETER Path
  Files or directories to process. Defaults to Scripts/.
.PARAMETER Mode
  Lint reports diagnostics only. Format rewrites files with Invoke-Formatter.
  Fix runs Invoke-ScriptAnalyzer -Fix then Invoke-Formatter.
.PARAMETER SettingsPath
  Path to the PSScriptAnalyzer settings file. Defaults to the repo root
  PSScriptAnalyzerSettings.psd1.
.EXAMPLE
  ./Scripts/Format-PSScripts.ps1 -Path Scripts/Common.ps1
  Lints a single file and reports diagnostics.
.EXAMPLE
  ./Scripts/Format-PSScripts.ps1 -Path Scripts -Mode Fix
  Auto-fixes analyzer findings and reformats every script under Scripts/.
.OUTPUTS
  None. Writes status to the console and exits 1 if any file has findings
  (Lint) or was changed (Format/Fix).
#>

[CmdletBinding(SupportsShouldProcess)]
param (
  # One or more files or directories to lint/format
  [Parameter(Position = 0, ValueFromRemainingArguments)]
  [string[]]$Path,

  # Lint reports only; Format rewrites; Fix auto-fixes then reformats
  [ValidateSet('Lint', 'Format', 'Fix')]
  [string]$Mode = 'Lint',

  # PSScriptAnalyzer settings file
  [string]$SettingsPath
)

$ErrorActionPreference = 'Stop'

# Defaults resolved here: PS 5.1 leaves $PSScriptRoot empty inside param() default expressions.
if (-not $Path) { $Path = $PSScriptRoot }
if (-not $SettingsPath) { $SettingsPath = Join-Path -Path $PSScriptRoot -ChildPath '..\PSScriptAnalyzerSettings.psd1' }

. (Join-Path -Path $PSScriptRoot -ChildPath 'Common.ps1')

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
  throw 'PSScriptAnalyzer module not found. Install with: Install-Module PSScriptAnalyzer -Scope CurrentUser'
}
if (-not (Test-Path -Path $SettingsPath)) {
  throw "Settings file not found: ${SettingsPath}"
}

# Repo style (2-space OTBS). The formatter's built-in default is 4-space, and
# PSScriptAnalyzerSettings.psd1 enables no formatting rules (CI lint must accept legacy
# 4-space files), so neither can drive Format mode.
$formatterSettings = @{
  IncludeRules = @(
    'PSPlaceOpenBrace', 'PSPlaceCloseBrace', 'PSUseConsistentIndentation',
    'PSUseConsistentWhitespace', 'PSUseCorrectCasing'
  )
  Rules        = @{
    PSPlaceOpenBrace           = @{ Enable = $true; OnSameLine = $true; NewLineAfter = $true; IgnoreOneLineBlock = $true }
    PSPlaceCloseBrace          = @{ Enable = $true; NewLineAfter = $false; IgnoreOneLineBlock = $true }
    PSUseConsistentIndentation = @{ Enable = $true; IndentationSize = 2; Kind = 'space' }
    PSUseConsistentWhitespace  = @{ Enable = $true }
    PSUseCorrectCasing         = @{ Enable = $true }
  }
}


function Get-TargetScript {
  <#
  .SYNOPSIS
    Resolves paths and directories into a flat list of .ps1/.psm1 files.
  .PARAMETER InputPath
    File or directory path to resolve.
  .EXAMPLE
    Get-TargetScript -InputPath 'Scripts'
    Returns every .ps1/.psm1 file under Scripts recursively.
  #>
  [CmdletBinding()]
  [OutputType([System.IO.FileInfo])]
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [string]$InputPath
  )
  process {
    $resolvedPath = Resolve-Path -Path $InputPath
    foreach ($item in $resolvedPath) {
      if (Test-Path -Path $item -PathType Container) {
        Get-ChildItem -Path $item -File -Recurse -Include '*.ps1', '*.psm1'
      } else {
        Get-Item -Path $item
      }
    }
  }
}

function Invoke-ScriptLint {
  <#
  .SYNOPSIS
    Reports PSScriptAnalyzer diagnostics for a script; does not modify it.
  .PARAMETER File
    Script file to analyze.
  .EXAMPLE
    Invoke-ScriptLint -File (Get-Item Scripts/Common.ps1)
  #>
  [CmdletBinding()]
  [OutputType([bool])]
  param (
    [Parameter(Mandatory)]
    [System.IO.FileInfo]$File
  )
  process {
    $diagnostics = Invoke-ScriptAnalyzer -Path $File.FullName -Settings $SettingsPath
    if ($diagnostics) {
      Write-Warn $File.FullName
      $diagnostics | Format-Table -AutoSize RuleName, Severity, Line, Message | Out-String -Width 200 |
        ForEach-Object { Write-ColorOutput $_ -ForegroundColor DarkGray }
      return $true
    }
    Write-Success $File.FullName
    return $false
  }
}

function Invoke-ScriptFormat {
  <#
  .SYNOPSIS
    Reformats a script with Invoke-Formatter, optionally auto-fixing first.
  .PARAMETER File
    Script file to format.
  .PARAMETER AutoFix
    Run Invoke-ScriptAnalyzer -Fix before formatting.
  .EXAMPLE
    Invoke-ScriptFormat -File (Get-Item Scripts/Common.ps1) -AutoFix
  #>
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([bool])]
  param (
    [Parameter(Mandatory)]
    [System.IO.FileInfo]$File,

    [switch]$AutoFix
  )
  process {
    if ($AutoFix) {
      $null = Invoke-ScriptAnalyzer -Path $File.FullName -Settings $SettingsPath -Fix
    }

    $original = Get-Content -Path $File.FullName -Raw
    $formatted = Invoke-Formatter -ScriptDefinition $original -Settings $formatterSettings

    if ($original -eq $formatted) {
      Write-Success $File.FullName
      return $false
    }

    if ($PSCmdlet.ShouldProcess($File.FullName, 'Reformat')) {
      # .NET write keeps the file's existing BOM state and works on PS 5.1, which lacks -Encoding utf8NoBom.
      $bytes = [System.IO.File]::ReadAllBytes($File.FullName)
      $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
      [System.IO.File]::WriteAllText($File.FullName, $formatted, [System.Text.UTF8Encoding]::new($hasBom))
    }
    Write-Warn "$($File.FullName) (reformatted)"
    return $true
  }
}

Write-Header "PowerShell $Mode"

$targetFile = $Path | Get-TargetScript
$anyChanged = $false

foreach ($file in $targetFile) {
  $changed = switch ($Mode) {
    'Lint' { Invoke-ScriptLint -File $file }
    'Format' { Invoke-ScriptFormat -File $file }
    'Fix' { Invoke-ScriptFormat -File $file -AutoFix }
  }
  if ($changed) {
    $anyChanged = $true
  }
}

if ($anyChanged) {
  exit 1
}
