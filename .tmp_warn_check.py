#!/usr/bin/env python3
import subprocess, os

os.chdir(
    "/workspace/3fa973b4-834e-4f9f-bb84-4461709c8875/sessions/agent_4fa48c62-cafd-4d3d-8b94-3302c0c7eec7"
)
result = subprocess.run(
    ["git", "grep", "-n", "Write-Host.*WARN", "--", "*.ps1"],
    capture_output=True,
    text=True,
)
lines = result.stdout.strip().split("\n") if result.stdout else []
print(f"Write-Host WARN occurrences: {len(lines)}")
if lines:
    print("\nFirst 5:")
    for l in lines[:5]:
        print(l)
print("\n(These are runtime messages, not TODO markers)")
