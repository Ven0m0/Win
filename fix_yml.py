import re

with open('.github/workflows/ps-format.yml', 'rb') as f:
    content = f.read().decode('utf-8')

# The previous replacement failed probably because the indentation or CRLF was different.
# Let's just regex replace the exact line.
content = re.sub(
    r"\$files = @\(Get-ChildItem -Path \. -Recurse -Include \*\.ps1,\*\.psm1,\*\.psd1 -File \| Select-Object -ExpandProperty FullName\)",
    r"$files = @()",
    content
)

with open('.github/workflows/ps-format.yml', 'wb') as f:
    f.write(content.encode('utf-8'))
