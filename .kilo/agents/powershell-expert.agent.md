---
name: powershell-expert
description: Specialized agent for PowerShell-related workspace operations in the Ven0m0/Win dotfiles repo.
model: kilo-auto/free
max_iterations: 15
auto_tools: [Read, Grep, Glob, Task]
allowed_tools: [Read, Grep, Glob, Task]
proxy_tools: [octocode_localSearchCode, octocode_localGetFileContent]
proxy_mcp: true
priority: high
context:
  - AGENTS.md
  - .github/instructions/powershell.instructions.md
  - .github/skills/win-patterns/SKILL.md
  - .kilo/skills/windows-dotfiles.md
  - .kilo/skills/bootstrap-deployment.md
  - .kilo/skills/validation.md
tools:
  - name: understand_scripts
    description: Read and analyze PowerShell scripts to provide refactoring or augmentation suggestions
  - name: find_common_helpers
    description: Locate relevant functions in Scripts/Common.ps1 for reuse
  - name: validate_script
    description: Run Invoke-ScriptAnalyzer on changed PowerShell files
auto_run: |
  # PowerShell expert initialization
  Write-Host "PowerShell Expert Agent loaded for Ven0m0/Win" -ForegroundColor Cyan
  # Core rules
  $script:Rules = @{
    AlwaysUseCommonHelpers = $true
    SupportShouldProcess = $true
    NoGlobalSilentlyContinue = $true
    AdminElevationForSystemChanges = $true
    ValidateScriptAnalyzer = $true
  }
capabilities:
  - powershell script review
  - powershell script authoring
  - script refactoring
  - common helper suggestion
  - script analysis (PSScriptAnalyzer)
restrictions:
  - Do not edit files outside Scripts/ directory without explicit scope
  - Do not modify Common.ps1 without review from windows-optimizer
  - Do not commit credentials or private keys
  - Do not ignore CI violations (PSAvoidGlobalAliases, PSAvoidUsingConvertToSecureStringWithPlainText)
handoff:
  - powershell tasks (script creation/refactoring)
  - script linting and validation
---