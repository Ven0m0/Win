#!/bin/bash

sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive DEBCONF_NOWARNINGS=yes apt-get install -yqq --no-install-recommends \
  ripgrep build-essential pkg-config

command -v uv || curl -LsSf https://astral.sh/uv/install.sh | bash

curl -sSfL https://mise.run | bash
eval "$(~/.local/bin/mise activate bash)"
if [[ -f mise.toml ]]; then
  mise trust
  mise install
fi
[[ -f pyproject.toml ]] && uv sync --all-extras --all-packages --all-groups --link-mode symlink --frozen 2>/dev/null || true

curl -sSfL https://webi.sh/powershell | bash
source ~/.config/envman/PATH.env || true
export PATH="$HOME/.local/bin:$HOME/.local/opt/powershell:$PATH"
pwsh -NoLogo -NoProfile -Command '
Set-PSRepository PSGallery -InstallationPolicy Trusted; Install-Module PSScriptAnalyzer -Scope CurrentUser -Force'

prek install
