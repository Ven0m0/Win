#!/bin/bash
# OpenHands pre-commit hook for Ven0m0/Win repository
# Runs linting and tests on changed files

set -e

echo "=== Running pre-commit checks ==="

# Track exit codes
PYTHON_FAILED=0
POWERSHELL_LINT_FAILED=0
POWERSHELL_TEST_FAILED=0

# Ensure PowerShell is in PATH
export PATH="$HOME/.local/bin:$HOME/.local/opt/powershell:$PATH:/usr/local/bin:$PATH"

# --- PowerShell Linting ---
echo ""
echo ">>> Running PowerShell linting..."

# Get list of changed PowerShell files
CHANGED_PS=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.(ps1|psm1|psd1)$' || true)

if [[ -n "$CHANGED_PS" ]]; then
    echo "Linting changed PowerShell files:"
    echo "$CHANGED_PS"
    echo "$CHANGED_PS" | pwsh -NoProfile -File .github/scripts/Lint-PowerShell.ps1 -CheckMode || POWERSHELL_LINT_FAILED=1
else
    echo "No PowerShell files changed."
fi

# --- PowerShell Tests ---
echo ""
echo ">>> Running PowerShell tests..."

if [[ -d "Scripts" ]]; then
    # Ensure test output directory exists
    mkdir -p .agents_tmp
    
    pwsh -NoProfile -File .github/scripts/Test-PowerShell.ps1 -OutputFormat Minimal || POWERSHELL_TEST_FAILED=1
else
    echo "No Scripts directory found - skipping tests"
fi

# --- Summary ---
echo ""
echo "=== Pre-commit Summary ==="
if [[ $POWERSHELL_LINT_FAILED -eq 0 ]] && [[ $POWERSHELL_TEST_FAILED -eq 0 ]]; then
    echo "✓ All checks passed"
    exit 0
else
    echo "✗ Some checks failed:"
    [[ $POWERSHELL_LINT_FAILED -eq 1 ]] && echo "  - PowerShell linting failed"
    [[ $POWERSHELL_TEST_FAILED -eq 1 ]] && echo "  - PowerShell tests failed"
    exit 1
fi
