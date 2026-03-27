---
description: Run PSScriptAnalyzer on all PowerShell scripts and report violations
agent: code
---

Run PSScriptAnalyzer across the repository. The CI enforces these same rules on every push.

Target: `$ARGUMENTS` (default: all `.ps1` and `.psm1` files under `Scripts/`)

Steps:
1. Identify all PowerShell files in scope: `!`find Scripts/ -name "*.ps1" -o -name "*.psm1" | head -50``
2. For each file, report any PSScriptAnalyzer violations. Focus on:
   - `PSAvoidGlobalAliases` — banned by CI
   - `PSAvoidUsingConvertToSecureStringWithPlainText` — banned by CI
   - `PSAvoidUsingInvokeExpression` — security rule, also banned
   - `PSUseDeclaredVarsMoreThanAssignments` — common dead-code
   - OTBS brace style violations
   - 2-space indent violations
3. For each violation list: file, line, rule name, and a concrete fix.
4. Do NOT auto-fix; present fixes for user review.

Reference: `.github/workflows/powershell.yml` uses `microsoft/psscriptanalyzer-action` with `recurse: true`.
