with open('Scripts/Common.ps1', 'r', encoding='utf-8-sig') as f:
    lines = f.read().splitlines()

for i, line in enumerate(lines):
    if len(line) > 120 and not line.lstrip().startswith('#'):
        if 'Get-ItemProperty "HKLM:\\SOFTWARE\\WOW6432Node\\Valve\\Steam" -Name \'InstallPath\' -ErrorAction SilentlyContinue' in line:
            indent_str = ' ' * (len(line) - len(line.lstrip()))
            lines[i] = f"{indent_str}$path = \"HKLM:\\SOFTWARE\\WOW6432Node\\Valve\\Steam\"\n{indent_str}$prop = Get-ItemProperty $path -Name 'InstallPath' -ErrorAction SilentlyContinue"
        elif 'Get-ItemProperty "HKCU:\\Software\\Valve\\Steam" -Name \'SteamPath\' -ErrorAction SilentlyContinue' in line:
            indent_str = ' ' * (len(line) - len(line.lstrip()))
            lines[i] = f"{indent_str}$path = \"HKCU:\\Software\\Valve\\Steam\"\n{indent_str}$prop = Get-ItemProperty $path -Name 'SteamPath' -ErrorAction SilentlyContinue"

content = '\n'.join(lines)
content = content.replace('\n', '\r\n')

with open('Scripts/Common.ps1', 'wb') as f:
    f.write(b'\xef\xbb\xbf' + content.encode('utf-8'))
