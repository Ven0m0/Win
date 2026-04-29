#!/bin/bash
# OpenHands setup script for Ven0m0/Win repository
# Installs dependencies for PowerShell development and validation

set -e

echo "=== Setting up Ven0m0/Win development environment ==="

# Install system dependencies
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive DEBCONF_NOWARNINGS=yes apt-get install -yqq --no-install-recommends \
  ripgrep build-essential pkg-config git curl

# Install Mise (if not present) for dotbot management
if ! command -v mise &> /dev/null; then
  echo "Installing mise..."
  curl -sSfL https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

# Trust and install from mise.toml if present
if [[ -f mise.toml ]]; then
  mise trust
  mise install
fi

# Install PowerShell
if ! command -v pwsh &> /dev/null; then
  echo "Installing PowerShell..."
  curl -sSfL https://webi.sh/powershell | sh
  source ~/.config/envman/PATH.env 2>/dev/null || true
  export PATH="$HOME/.local/bin:$HOME/.local/opt/powershell:$PATH"
fi

# Ensure PowerShell is in PATH for this session
export PATH="$HOME/.local/bin:$HOME/.local/opt/powershell:$PATH"

# Install PowerShell modules
pwsh -NoLogo -NoProfile -Command '
  Set-PSRepository PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
  if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber
  }
  if (-not (Get-Module -ListAvailable -Name Pester)) {
    Install-Module -Name Pester -MinimumVersion 5.0 -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber
  }
  Write-Host "PowerShell modules installed successfully"
'

# Create output directory for test results
mkdir -p .agents_tmp

echo "=== Setup complete ==="
echo "Run pre-commit checks with: .openhands/pre-commit.sh"
