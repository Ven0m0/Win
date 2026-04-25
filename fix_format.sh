#!/bin/bash
# Remove trailing whitespace
find . -name "*.ps1" -exec sed -i 's/[[:space:]]*$//' {} +
# Replace tabs with 2 spaces
find . -name "*.ps1" -exec sed -i 's/\t/  /g' {} +
