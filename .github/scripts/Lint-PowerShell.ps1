#Requires -Version 5.1
<#
.SYNOPSIS
    PowerShell linting script using PSScriptAnalyzer for pre-commit hooks.

.DESCRIPTION
    Runs PSScriptAnalyzer on PowerShell files (.ps1, .psm1, .psd1) with repository-specific
    settings (PSScriptAnalyzerSettings.psd1) and outputs violations in a format that
    pre-commit can understand.

.PARAMETER Files
    Array of file paths to lint. If not provided, reads from stdin.

.PARAMETER CheckMode
    When specified, outputs in pre-commit format. Otherwise, outputs detailed results.

.PARAMETER Severity
    Minimum severity level to report: Error, Warning, Information. Default: Warning.

.EXAMPLE
    # Lint specific files
    .\Lint-PowerShell.ps1 -Files @("Scripts/test.ps1", "Scripts/utils.ps1")

.EXAMPLE
    # Lint from stdin (pre-commit hook)
    git diff --name-only | .\Lint-PowerShell.ps1

.EXAMPLE
    # Lint with custom settings
    .\Lint-PowerShell.ps1 -Files @("Scripts/") -Severity Error
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
    [string[]]$Files,

    [Parameter(Mandatory = $false)]
    [switch]$CheckMode,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Error', 'Warning', 'Information')]
    [string]$Severity = 'Warning'
)

$ErrorActionPreference = 'Continue'
$Script:IssuesFound = $false

# Find the settings file relative to this script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$SettingsPath = Join-Path $RepoRoot 'PSScriptAnalyzerSettings.psd1'

# Verify PSScriptAnalyzer is available
$pssaModule = Get-Module -Name PSScriptAnalyzer -ListAvailable
if (-not $pssaModule) {
    Write-Host "PSScriptAnalyzer module not found. Installing..." -ForegroundColor Yellow
    try {
        Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber
        Import-Module PSScriptAnalyzer
    } catch {
        Write-Host "Failed to install PSScriptAnalyzer: $_" -ForegroundColor Red
        exit 1
    }
}

# Import module
Import-Module PSScriptAnalyzer -Force

function Write-LintResult {
    param(
        [object]$Result
    )

    $Script:IssuesFound = $true

    $file = $Result.ScriptPath
    $line = $Result.Line
    $rule = $Result.RuleName
    $severity = $Result.Severity
    $message = $Result.Message

    if ($CheckMode) {
        # Pre-commit compatible format: file:line: column: severity: rule: message
        $col = if ($Result.Column -gt 0) { $Result.Column } else { 1 }
        Write-Output "$file`:$line`:$col`: $severity`: $rule`: $message"
    } else {
        $color = switch ($severity) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Information' { 'Cyan' }
            default { 'White' }
        }
        Write-Host "[$file]:$line`: $severity - $rule" -ForegroundColor $color
        Write-Host "    $message" -ForegroundColor Gray
        Write-Host ""
    }
}

function Invoke-Lint {
    param(
        [string[]]$FilePaths
    )

    foreach ($file in $FilePaths) {
        # Handle both files and directories
        if (Test-Path $file -PathType Container) {
            # Directory - get all PowerShell files recursively
            $psFiles = Get-ChildItem -Path $file -Recurse -Include *.ps1, *.psm1, *.psd1 -File
            foreach ($psFile in $psFiles) {
                Invoke-Lint -FilePaths @($psFile.FullName)
            }
        } elseif (Test-Path $file -PathType Leaf) {
            # Single file
            if (-not ($file -match '\.(ps1|psm1|psd1)$')) {
                Write-Verbose "Skipping non-PowerShell file: $file"
                continue
            }

            Write-Verbose "Linting: $file"

            try {
                $params = @{
                    Path = $file
                }

                # Use settings if file exists
                if (Test-Path $SettingsPath) {
                    $params['Settings'] = $SettingsPath
                }

                # Add severity filter if specified
                if ($Severity -ne 'Warning') {
                    $params['Severity'] = $Severity
                }

                $results = Invoke-ScriptAnalyzer @params

                foreach ($result in $results) {
                    # Filter by severity if not using the module's built-in filtering
                    if ($Severity -ne 'Warning' -or $result.Severity -ne 'Information') {
                        Write-LintResult -Result $result
                    }
                }
            } catch {
                Write-Host "Error linting $file`: $_" -ForegroundColor Red
            }
        }
    }
}

# Main execution
$filesToLint = @()

if ($Files.Count -gt 0) {
    $filesToLint = $Files
} else {
    # Read from stdin (pre-commit hook mode)
    try {
        $stdinInput = [Console]::In.ReadToEnd()
        if ($stdinInput) {
            $filesToLint = $stdinInput -split "`n" | Where-Object {
                $_ -and $_.Trim() -and ($_ -match '\.(ps1|psm1|psd1)$')
            } | ForEach-Object { $_.Trim() }
        }
    } catch {
        # No stdin available
    }
}

if ($filesToLint.Count -eq 0) {
    Write-Verbose "No files to lint."
    exit 0
}

Invoke-Lint -FilePaths $filesToLint

if ($Script:IssuesFound) {
    if (-not $CheckMode) {
        Write-Host ""
        Write-Host "Lint issues found. Run with -CheckMode for pre-commit output." -ForegroundColor Yellow
    }
    exit 1
} else {
    if (-not $CheckMode) {
        Write-Host "No lint issues found." -ForegroundColor Green
    }
    exit 0
}
