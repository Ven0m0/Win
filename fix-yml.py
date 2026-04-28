import sys
import re

with open('.github/workflows/ps-format.yml', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the syntax error in the yaml file at line 46:
# "files=$($files -join ',')") | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8BOM
content = content.replace("\"files=$($files -join ',')\") | Out-File", "\"files=$($files -join ',')\" | Out-File")

with open('.github/workflows/ps-format.yml', 'w', encoding='utf-8') as f:
    f.write(content)
