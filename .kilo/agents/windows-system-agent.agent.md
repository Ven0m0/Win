---
name: windows-system-agent
description: Specialized agent for Windows system optimization, registry tweaks, debloating, and gaming performance tuning.
model: kilo-auto/free
max_iterations: 20
auto_tools: [Read, Grep, Task]
allowed_tools: [Read, Grep, Glob, Task, Edit]
proxy_tools: [octocode_localSearchCode, octocode_localGetFileContent]
proxy_mcp: true
priority: high
context:
  - AGENTS.md
  - .github/instructions/powershell.instructions.md
  - .github/skills/win-patterns/SKILL.md
  - .kilo/skills/windows-dotfiles.md
  - .kilo/skills/validation.md
tools:
  - name: analyze_system_scripts
    description: Read debloat, optimize, and gaming scripts to understand current state
  - name: suggest_registry_changes
    description: Propose safe registry modifications with rollback plan
  - name: suggest_debloat
    description: Identify safe Windows Apps/services/tasks to remove
  - name: gaming_optimization
    description: Fullscreen, MPO, shader cache, DLSS tweaks
auto_run: |
  # Windows System Optimizer Agent initialization
  Write-Host "Windows System Optimizer Agent loaded" -ForegroundColor Cyan
  $script:RequireElevation = $true
  $script:CreateRestorePoint = $true
capabilities:
  - registry optimization
  - windows debloating
  - service management
  - scheduled task cleanup
  - gaming performance tuning
  - network adapter optimization
restrictions:
  - Always use Set-RegistryValue/Remove-RegistryValue from Common.ps1 (never direct reg.exe)
  - Always create restore point before system changes (unless -NoRestorePoint)
  - Support -WhatIf and -Confirm on all system-modifying operations
  - Document rollback steps in comment-based help
  - Do not remove critical Windows components (verify Appx is safe before removal)
  - Do not modify files outside Scripts/ without explicit coordination
handoff:
  - registry tweaks implementation
  - debloat script updates
  - gaming optimization scripts
  - network tweaker enhancements
  - NVIDIA GPU registry handling
---