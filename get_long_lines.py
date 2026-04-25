with open('Scripts/Common.ps1', 'r', encoding='utf-8-sig') as f:
    lines = f.read().splitlines()

for i, line in enumerate(lines):
    if len(line) > 120 and not line.lstrip().startswith('#'):
        print(f"Line {i+1} ({len(line)}): {line.strip()}")
