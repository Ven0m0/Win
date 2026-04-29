---
name: config-deployer-agent
description: Agent for dotfile deployment, tracked configuration management, and dotbot manifest maintenance.
model: kilo-auto/free
max_iterations: 15
auto_tools: [Read, Grep, Task]
allowed_tools: [Read, Grep, Glob, Task, Edit]
proxy_tools: [octocode_localSearchCode, octocode_localGetFileContent]
proxy_mcp: true
priority: medium
context:
  - AGENTS.md
  - README.md
  - install.conf.yaml
  - Scripts/Setup-Dotfiles.ps1
  - .kilo/skills/bootstrap-deployment.md
  - .kilo/skills/windows-dotfiles.md
  - .kilo/skills/validation.md
tools:
  - name: review_deployment_manifest
    description: Read and analyze install.conf.yaml for correctness
  - name: verify_config_paths
    description: Check that tracked configs map to correct system destinations
  - name: update_dotbot_yaml
    description: Add new config groups to install.conf.yaml safely
  - name: validate_templates
    description: Ensure ##template files have proper substitution variables
auto_run: |
  # Config Deployer Agent initialization
  Write-Host "Config Deployer Agent loaded for Ven0m0/Win dotfiles" -ForegroundColor Cyan
capabilities:
  - dotbot YAML editing
  - tracked config file management
  - deployment path mapping verification
  - hash-based deployment logic review
  - template configuration
  - PATH and directory creation setup
restrictions:
  - Do not change deployment strategy from hash-based to symlinks
  - Do not reformat config files (preserve native format)
  - Always update both install.conf.yaml AND README setup section if deployment changes
  - Ensure all dotbot destinations use Windows path format (%USERPROFILE%, $env:APPDATA)
  - Do not add files outside user/.dotfiles/config/ without repo-wide review
handoff:
  - dotbot manifest updates
  - new config file integration
  - deployment path corrections
  - bootstrap flow adjustments
---