---
name: ps-release-check
description: Pre-commit gate for PowerShell changes - PSScriptAnalyzer with the repo settings, matching Pester tests, and a -WhatIf pass on changed .ps1 files. Use before committing or merging .ps1/.psm1/.psd1 changes, or when asked to "check my scripts" or "run the PS gate".
disable-model-invocation: true
---

# PowerShell release check

Run all three steps on the changed PowerShell files. Report each step's result separately. Stop and report on the first failing step; do not auto-fix without asking.

## 1. Collect changed files

```powershell
git diff --name-only --diff-filter=ACM HEAD | Where-Object { $_ -match '\.(ps1|psm1|psd1)$' }
```

No git repo or no changes: use the paths in `$ARGUMENTS`. Nothing to check: say so and stop.

## 2. Lint

Use the nearest `PSScriptAnalyzerSettings.psd1` walking up from each file (falls back to `~/PSScriptAnalyzerSettings.psd1`).

```powershell
Invoke-ScriptAnalyzer -Path <file> -Settings <settings.psd1>
```

Any finding is a failure. List `file:line:col message [rule]`.

## 3. Tests

For each `X.ps1`, run `tests/X.Tests.ps1` (nearest ancestor `tests/` dir) if it exists:

```powershell
Invoke-Pester -Path <test> -Output Minimal -PassThru
```

No test file: report "no test" for that script, not a pass.

## 4. Dry run

Only for scripts that declare `SupportsShouldProcess` or a `-WhatIf` parameter:

```powershell
pwsh -NoProfile -File <script> -WhatIf
```

Skip scripts that do not support `-WhatIf`; never run them to "see what happens". Scripts that touch HKLM, services, or `Remove-*` without `-WhatIf` support: flag them in the report instead.

## Report

One table: file, lint, tests, dry run. End with a one-line verdict: ready or blocked, and why.
