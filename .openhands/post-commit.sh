#!/bin/bash
# OpenHands post-commit hook for Ven0m0/Win repository
# Runs after successful commits (optional, disabled by default)

set +e  # Don't fail on errors for post-commit

echo "=== Post-commit cleanup ==="

# Clean up any temporary files from previous runs
rm -rf .agents_tmp/test-results.xml 2>/dev/null || true
rm -rf .agents_tmp/coverage.xml 2>/dev/null || true

# Optionally push to remote if on main branch
# Uncomment the following to enable:
# if [[ "$(git branch --show-current)" == "main" ]]; then
#   echo "Pushing to remote..."
#   git push origin main 2>/dev/null || true
# fi

echo "=== Post-commit complete ==="
