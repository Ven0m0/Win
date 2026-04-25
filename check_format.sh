#!/bin/bash
issues=0
for file in $(find . -name "*.ps1"); do
    if grep -q $'\t' "$file"; then
        echo "Error: Tabs found in $file"
        issues=$((issues+1))
    fi
    if grep -q "[[:space:]]$" "$file"; then
        echo "Error: Trailing whitespace found in $file"
        issues=$((issues+1))
    fi
done
exit $issues
