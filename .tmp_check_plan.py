#!/usr/bin/env python3
import re

with open("TODO.md") as f:
    content = f.read()
todo_items = []
for line in content.split("\n"):
    line = line.strip()
    if line and not line.startswith("#") and line[0].isdigit():
        # Extract the item text after the number
        m = re.match(r"^\d+:\s*(.*)", line)
        if m:
            todo_items.append(m.group(1))

print("=== TODO.md items ===")
for i, item in enumerate(todo_items, 1):
    print(f"{i}: {item}")

with open("PLAN.md") as f:
    plan_content = f.read()

print("\n=== PLAN.md file refs ===")
refs = re.findall(r"File:\s*`([^`]+)`", plan_content)
for r in refs:
    print(r)

print("\n=== PLAN.md task titles ===")
tasks = re.findall(r"### T(\d+) \· (.*)", plan_content)
for tid, title in tasks:
    print(f"T{tid}: {title}")
