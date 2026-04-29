#!/bin/bash

# Python
ruff check .
ty check .
basedpyright .
pytest .

# Powershell
pwsh -NoProfile -File .github/scripts/Lint-PowerShell.ps1 -CheckMode
pwsh -NoProfile -File .github/scripts/Test-PowerShell.ps1
