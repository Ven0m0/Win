#Requires -Version 7
<#
.SYNOPSIS
  PostToolUse validator for Edit/Write/MultiEdit.
.DESCRIPTION
  Routes the edited file to the right tool by extension:
    .ps1/.psm1/.psd1        PSScriptAnalyzer, then the matching Pester test if one exists
    .py/.pyi                ruff format, then ruff check --fix
    .json/.jsonc            biome check --write
    .yaml/.yml              yq eval parse
    .xml and XML dialects   well-formedness parse
  Safe fixes are applied in place. Anything left unfixed goes to stderr with
  exit 2, which feeds the diagnostic back to Claude so it repairs the file.
  One dispatcher on purpose: a single pwsh process per edit instead of one per check.
.NOTES
  Wired from settings.json as a PostToolUse hook matching Edit|Write|MultiEdit.
#>
$ErrorActionPreference = 'Stop'

# Emit a diagnostic and exit 2, the code that feeds stderr back to Claude.
function Exit-Hook ([string]$Message) {
  [Console]::Error.WriteLine($Message)
  exit 2
}

# Nearest ancestor directory containing $Relative, for repo-local config discovery.
# Walks up from the edited file so results never depend on the session's cwd.
function Find-AncestorPath ([string]$StartFile, [string]$Relative) {
  $dir = Split-Path -Path $StartFile -Parent
  while ($dir) {
    $candidate = Join-Path -Path $dir -ChildPath $Relative
    if (Test-Path -LiteralPath $candidate) { return $candidate }
    $parent = Split-Path -Path $dir -Parent
    if ($parent -eq $dir) { break }
    $dir = $parent
  }
  return $null
}

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try {
  $filePath = ($raw | ConvertFrom-Json).tool_input.file_path
} catch {
  exit 0
}
if (-not $filePath -or -not (Test-Path -LiteralPath $filePath -PathType Leaf)) { exit 0 }

$ext = [IO.Path]::GetExtension($filePath).ToLowerInvariant()

switch -Regex ($ext) {

  '^\.(ps1|psm1|psd1)$' {
    if (-not (Get-Command -Name Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue)) { break }
    $analyzer = @{ Path = $filePath }
    $settingsPath = Find-AncestorPath -StartFile $filePath -Relative 'PSScriptAnalyzerSettings.psd1'
    if ($settingsPath) { $analyzer.Settings = $settingsPath }
    try {
      $issues = Invoke-ScriptAnalyzer @analyzer
    } catch {
      $err = $_
      Exit-Hook -Message "PSScriptAnalyzer failed: $($err.Exception.Message)"
    }
    if ($issues) {
      $lines = foreach ($issue in $issues) {
        '{0}:{1}:{2} {3} [{4}]' -f $filePath, $issue.Line, $issue.Column, $issue.Message, $issue.RuleName
      }
      Exit-Hook -Message ($lines -join [Environment]::NewLine)
    }

    if ($ext -eq '.ps1') {
      $baseName = [IO.Path]::GetFileNameWithoutExtension($filePath)
      $relativeTest = Join-Path -Path 'tests' -ChildPath "$baseName.Tests.ps1"
      $testPath = Find-AncestorPath -StartFile $filePath -Relative $relativeTest
      if ($testPath -and (Get-Command -Name Invoke-Pester -ErrorAction SilentlyContinue)) {
        $result = Invoke-Pester -Path $testPath -Output Minimal -PassThru
        if ($result.FailedCount -gt 0) {
          Exit-Hook -Message "Pester: $($result.FailedCount) failing test(s) in $testPath"
        }
      }
    }
    break
  }

  '^\.(py|pyi)$' {
    if (-not (Get-Command -Name ruff -ErrorAction SilentlyContinue)) { break }
    $null = & ruff format -- $filePath 2>&1
    $output = & ruff check --fix --output-format concise -- $filePath 2>&1
    if ($LASTEXITCODE -ne 0) {
      Exit-Hook -Message ('ruff:' + [Environment]::NewLine + ($output -join [Environment]::NewLine))
    }
    break
  }

  '^\.(json|jsonc)$' {
    if (-not (Get-Command -Name biome -ErrorAction SilentlyContinue)) { break }
    $flags = @(
      'check', '--write', '--colors=off', '--log-level=error', '--max-diagnostics=10',
      '--formatter-enabled=true', '--linter-enabled=true', '--assist-enabled=false',
      '--files-ignore-unknown=true'
    )
    # A repo shipping its own biome.json owns its style; only impose house style where none is set.
    $hasConfig = (Find-AncestorPath -StartFile $filePath -Relative 'biome.json') -or
      (Find-AncestorPath -StartFile $filePath -Relative 'biome.jsonc')
    if (-not $hasConfig) {
      $flags += @('--indent-style=space', '--indent-width=2', '--line-width=120')
    }
    $output = & biome @flags $filePath 2>&1
    if ($LASTEXITCODE -ne 0) {
      Exit-Hook -Message ('biome:' + [Environment]::NewLine + ($output -join [Environment]::NewLine))
    }
    break
  }

  '^\.(yaml|yml)$' {
    if (-not (Get-Command -Name yq -ErrorAction SilentlyContinue)) { break }
    $output = & yq eval '.' -- $filePath 2>&1
    if ($LASTEXITCODE -ne 0) {
      Exit-Hook -Message ('yq:' + [Environment]::NewLine + ($output -join [Environment]::NewLine))
    }
    break
  }

  '^\.(xml|xaml|csproj|vbproj|props|targets|resx|nuspec|config|manifest)$' {
    $readerSettings = [System.Xml.XmlReaderSettings]::new()
    # Ignore rather than Prohibit: a DOCTYPE is legal, but never resolve it (no XXE, no network).
    $readerSettings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
    $readerSettings.XmlResolver = $null
    try {
      $reader = [System.Xml.XmlReader]::Create($filePath, $readerSettings)
      try {
        while ($reader.Read()) { }
      } finally {
        $reader.Dispose()
      }
    } catch {
      $err = $_
      Exit-Hook -Message "XML not well-formed: $filePath$([Environment]::NewLine)$($err.Exception.Message)"
    }
    break
  }
}

exit 0
