#Requires -Version 5.1
<#
.SYNOPSIS
    PowerShell formatting validation script for pre-commit hooks.

.DESCRIPTION
    Validates PowerShell files (.ps1, .psm1, .psd1) against repository formatting standards:
    - 2-space indentation (no tabs)
    - No trailing whitespace
    - UTF-8 with BOM encoding
    - Max line length of 120 characters (excluding comments)

    Output format compatible with pre-commit hook expectations.

.PARAMETER Files
    Array of file paths to check. If not provided, reads from stdin.

.PARAMETER CheckMode
    When specified, outputs in pre-commit format. Otherwise, outputs detailed results.

.EXAMPLE
    # Check specific files
    .\Format-PowerShell.ps1 -Files @("Scripts/test.ps1", "Scripts/utils.ps1")

.EXAMPLE
    # Check from stdin (pre-commit hook)
    git diff --name-only | .\Format-PowerShell.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
    [string[]]$Files,

    [Parameter(Mandatory = $false)]
    [switch]$CheckMode
)

$ErrorActionPreference = 'Continue'
$Script:IssuesFound = $false

# Repository formatting standards
$MaxLineLength = 120
$IndentSize = 2

function Write-Check {
    param(
        [string]$File,
        [int]$Line,
        [string]$Message,
        [string]$Type = 'error'
    )

    $Script:IssuesFound = $true
    if ($CheckMode) {
        # Pre-commit compatible format
        Write-Output "$File`:$Line`: $Message"
    } else {
        $color = if ($Type -eq 'error') { 'Red' } else { 'Yellow' }
        Write-Host "[$File]:$Line`: $Message" -ForegroundColor $color
    }
}

function Test-FileFormatting {
    param(
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        Write-Verbose "File not found: $FilePath"
        return
    }

    # Read as bytes to check BOM
    $bytes = [System.IO.File]::ReadAllBytes($FilePath)

    # Read content with UTF-8 BOM handling
    $content = [System.IO.File]::ReadAllText($FilePath, [System.Text.UTF8Encoding]::new($true))
    $lines = $content -split "\r?\n"

    # Check 1: UTF-8 BOM
    if ($bytes.Count -ge 3) {
        $bom = [System.Text.Encoding]::UTF8.GetPreamble()
        $hasBom = $true
        for ($i = 0; $i -lt $bom.Length; $i++) {
            if ($bytes[$i] -ne $bom[$i]) {
                $hasBom = $false
                break
            }
        }
        if (-not $hasBom) {
            Write-Check -File $FilePath -Line 0 -Message "Missing UTF-8 BOM"
        }
    } else {
        Write-Check -File $FilePath -Line 0 -Message "Missing UTF-8 BOM"
    }

    # Check 2: Indentation (2 spaces, no tabs)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # Skip empty lines
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        # Check for tabs
        if ($line -match '^\t') {
            Write-Check -File $FilePath -Line ($i + 1) -Message "Line uses tabs instead of spaces"
        }

        # Check for inconsistent indentation (not multiple of 2)
        if ($line -match '^(\s+)') {
            $leadingSpaces = $matches[1].Length
            if ($leadingSpaces % 2 -ne 0 -and $line -notmatch '^\s*#') {
                Write-Check -File $FilePath -Line ($i + 1) -Message "Indentation not multiple of $IndentSize spaces"
            }
        }
    }

    # Check 3: Trailing whitespace
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $trimmedLine = $line.TrimEnd()

        # Skip empty lines and lines that only have trailing \r (CRLF residue)
        if ($trimmedLine -ne '' -and $line -ne $trimmedLine -and ($line.Length - $trimmedLine.Length) -eq 1) {
            # Only has \r, skip (this is normal CRLF)
            continue
        }
        if ($trimmedLine -ne '' -and $trimmedLine -match '\s+$') {
            Write-Check -File $FilePath -Line ($i + 1) -Message "Trailing whitespace"
        }
    }

    # Check 4: Max line length (excluding comments)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # Skip empty lines
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        # Skip comment-only lines
        if ($line -match '^\s*#') {
            continue
        }

        if ($line.Length -gt $MaxLineLength) {
            Write-Check -File $FilePath -Line ($i + 1) -Message "Line exceeds $MaxLineLength characters ($($line.Length))"
        }
    }
}

# Main execution
if ($Files.Count -gt 0) {
    foreach ($file in $Files) {
        Test-FileFormatting -FilePath $file
    }
} else {
    # Read from stdin (pre-commit hook mode)
    $stdinFiles = @()
    try {
        $stdinInput = [Console]::In.ReadToEnd()
        if ($stdinInput) {
            $stdinFiles = $stdinInput -split "`n" | Where-Object { $_ -and $_.Trim() -and ($_ -match '\.(ps1|psm1|psd1)$') }
        }
    } catch {
        # No stdin available
    }

    foreach ($file in $stdinFiles) {
        Test-FileFormatting -FilePath $file.Trim()
    }
}

if ($Script:IssuesFound) {
    if (-not $CheckMode) {
        Write-Host ""
        Write-Host "Formatting issues found. Run with -CheckMode for pre-commit output." -ForegroundColor Yellow
    }
    exit 1
} else {
    if (-not $CheckMode) {
        Write-Host "No formatting issues found." -ForegroundColor Green
    }
    exit 0
}
