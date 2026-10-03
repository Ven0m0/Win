#Requires -Version 5.1
<#
.SYNOPSIS
  Runs actionlint, ghalint, and action-validator over every GitHub Actions workflow and composite action.
.DESCRIPTION
  Tools are resolved through mise ('mise exec <tool>@latest --'), so they install on first use and the
  repo needs no extra setup. ghalint reads .ghalint.yaml from the repo root, hence the Push-Location.
  Exits 1 when any linter reports a finding.
.EXAMPLE
  pwsh -NoProfile -File check-workflows.ps1 -Root C:\src\myrepo
#>
[CmdletBinding()]
param(
  # Repository root containing .github/
  [string]$Root = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

function Invoke-Linter {
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][string]$Tool,
    [Parameter(Mandatory)][string[]]$Arguments
  )
  $output = & mise exec "$Tool@latest" -- @Arguments 2>&1 | Where-Object { "$_" -notmatch '^mise WARN' }
  [pscustomobject]@{ Label = $Label; Passed = ($LASTEXITCODE -eq 0); Output = @($output) }
}

$Root = (Resolve-Path -LiteralPath $Root).Path
Push-Location -Path $Root
try {
  $githubDir = Join-Path -Path $Root -ChildPath '.github'
  if (-not (Test-Path -LiteralPath $githubDir)) { throw "No .github directory under $Root" }

  $files = @(Get-ChildItem -Path $githubDir -Recurse -File -Include '*.yml', '*.yaml' |
      Where-Object { $_.FullName -match '[\\/](workflows|actions)[\\/]' })
  if ($files.Count -eq 0) { throw "No workflow or action files found under $githubDir" }

  # -oneline gives one finding per line; the default multi-line snippets are too long to scan
  $results = @(Invoke-Linter -Label 'actionlint' -Tool 'actionlint' -Arguments @('actionlint', '-oneline'))
  $results += Invoke-Linter -Label 'ghalint' -Tool 'ghalint' -Arguments @('ghalint', 'run')
  foreach ($file in $files) {
    $relative = $file.FullName.Substring($Root.Length + 1) -replace '\\', '/'
    # action-validator takes exactly one file per call; the aqua build has no Windows binary
    $validatorArgs = @('action-validator', $relative)
    $label = "action-validator $relative"
    $results += Invoke-Linter -Label $label -Tool 'cargo:action-validator' -Arguments $validatorArgs
  }
}
finally {
  Pop-Location
}

foreach ($result in $results) {
  Write-Output ("[{0}] {1}" -f $(if ($result.Passed) { 'PASS' } else { 'FAIL' }), $result.Label)
  if (-not $result.Passed) { $result.Output | ForEach-Object { Write-Output "    $_" } }
}
if ($results.Where({ -not $_.Passed }).Count -gt 0) { exit 1 }
