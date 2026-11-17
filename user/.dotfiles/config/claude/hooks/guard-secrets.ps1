# PreToolUse (Bash|PowerShell): block git commit / git push when gitleaks finds a secret.
# Exit 2 = block (stderr goes to Claude). Any other failure fails open with a warning.
$ErrorActionPreference = 'Stop'
try {
    $payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $cmd = [string]$payload.tool_input.command
    if ($cmd -notmatch '(?<![\w-])git\s+(?:-\S+\s+)*(commit|push)\b') { exit 0 }
    $kind = $Matches[1]
    $cwd = if ($payload.cwd) { $payload.cwd } else { (Get-Location).Path }

    if (-not (Get-Command gitleaks -ErrorAction SilentlyContinue)) {
        [Console]::Error.WriteLine('guard-secrets: gitleaks not on PATH, skipping scan'); exit 0
    }
    git -C $cwd rev-parse --git-dir 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { exit 0 }

    # 77 = leaks found, so a runtime error (exit 1) is not mistaken for a secret.
    $base = @('--no-banner', '--redact', '--exit-code', '77')
    $runs = @()
    if ($kind -eq 'commit') {
        $runs += , (@('git', '--staged') + $base)
        # shortcut: a chained `git add x && git commit` stages after this hook runs, so also scan the
        # unstaged diff then; new untracked files stay uncovered. Upgrade: wrap git via a real pre-commit hook.
        if ($cmd -match '\bgit\s+add\b|\bcommit\b[^|;&]*\s-\w*a') { $runs += , (@('git', '--pre-commit') + $base) }
    } else {
        git -C $cwd rev-parse --abbrev-ref '@{upstream}' 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { exit 0 }  # no upstream to diff against
        $runs += , (@('git', '--log-opts=@{upstream}..HEAD') + $base)
    }
    foreach ($a in $runs) {
        $out = & gitleaks @a $cwd 2>&1 | Out-String
        if ($LASTEXITCODE -eq 77) {
            [Console]::Error.WriteLine("guard-secrets: gitleaks found a possible secret, blocking git $kind.`n$out")
            exit 2
        }
        if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine("guard-secrets: gitleaks failed (exit $LASTEXITCODE), not blocking`n$out") }
    }
    exit 0
} catch {
    [Console]::Error.WriteLine("guard-secrets: hook error, not blocking: $_"); exit 0
}
