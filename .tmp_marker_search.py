#!/usr/bin/env python3
import re
from pathlib import Path

marker_patterns = [
    r"#\s*(TODO|FIXME|HACK|XXX|DEPRECATED)\b",
    r"#\s*NOTE\(.*\)",
    r"#\s*WARN\(.*\)",
    r"<!--\s*(TODO|FIXME|HACK|XXX|DEPRECATED)\b",
    r"/\*\s*(TODO|FIXME|HACK|XXX|DEPRECATED)\b",
]

exclude_dirs = {
    "node_modules",
    ".venv",
    "venv",
    "vendor",
    ".git",
    "dist",
    "build",
    "__pycache__",
    ".kilo",
    ".claude",
    ".opencode",
    "target",
    "bin",
    "obj",
}
exclude_files = {
    "todo-scan/SKILL.md",
    "win-patterns/SKILL.md",
    "dead-code-cleanup/SKILL.md",
    "powershell-windows/SKILL.md",
}

results = []
repo_root = Path(".")

for file in repo_root.rglob("*"):
    if file.is_dir():
        continue
    if any(part in file.parts for part in exclude_dirs):
        continue
    if any(excl in str(file) for excl in exclude_files):
        continue
    if file.suffix.lower() not in {
        ".ps1",
        ".psm1",
        ".psd1",
        ".md",
        ".yaml",
        ".yml",
        ".json",
        ".xml",
        ".toml",
        ".sh",
        ".bash",
        ".py",
        ".ts",
        ".tsx",
        ".js",
        ".jsx",
        ".rs",
        ".go",
        ".lua",
        ".txt",
        ".reg",
        ".cfg",
        ".conf",
    }:
        continue
    try:
        content = file.read_text(encoding="utf-8", errors="ignore")
        for i, line in enumerate(content.split("\n"), 1):
            for pat in marker_patterns:
                if re.search(pat, line, re.IGNORECASE):
                    lines = content.split("\n")
                    start = max(0, i - 3)
                    end = min(len(lines) - 1, i + 2)
                    context = "\n".join(
                        f"{j + 1}: {lines[j]}" for j in range(start, end)
                    )
                    results.append(f"FILE: {file}  LINE: {i}\n{context}\n---")
                    break
    except Exception:
        pass

if results:
    print(f"FOUND {len(results)} MARKER(S):\n")
    for r in results:
        print(r)
else:
    print("No actionable marker comments found in source files.")
    print(
        "Only markers found were in documentation/SKILL files and Write-Host statements."
    )
