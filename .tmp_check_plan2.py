#!/usr/bin/env python3
import re

with open("TODO.md") as f:
    lines = [l.rstrip() for l in f.readlines()]

print("=== TODO.md raw ===")
for i, line in enumerate(lines, 1):
    print(f"{i}: {line}")

# Extract items: lines that start with "### <num>"
todo_items = []
for line in lines:
    m = re.match(r"^###\s+(\d+)", line)
    if m:
        num = m.group(1)
        # Next non-empty line after ### N is the description
        idx = lines.index(line)
        # Find next non-empty line
        for next_line in lines[idx + 1 :]:
            if next_line.strip():
                todo_items.append((num, next_line.strip()))
                break

print("\n=== Extracted TODO items ===")
for num, desc in todo_items:
    print(f"{num}: {desc}")

print("\n=== Summary ===")
print(f"Total TODO items: {len(todo_items)}")
for num, desc in todo_items:
    print(f"- TODO #{num}: {desc[:80]}")
