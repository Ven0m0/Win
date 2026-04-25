with open('Scripts/Common.ps1', 'r', encoding='utf-8-sig') as f:
    lines = f.read().splitlines()

for i, line in enumerate(lines):
    if i in [949, 950] and line.startswith('               '): # 15 spaces
        lines[i] = '                ' + line[15:] # 16 spaces

content = '\n'.join(lines)
content = content.replace('\n', '\r\n')

with open('Scripts/Common.ps1', 'wb') as f:
    f.write(b'\xef\xbb\xbf' + content.encode('utf-8'))
