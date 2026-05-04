import sys

def modify_file(file_path):
    with open(file_path, 'rb') as f:
        content = f.read().decode('utf-8-sig')

    lines = content.split('\n')

    for i in range(len(lines)):
        import re
        m = re.match(r'^(\s+)', lines[i])
        if m and not lines[i].strip().startswith('#'):
            spaces = len(m.group(1))
            if spaces % 2 != 0:
                lines[i] = " " + lines[i]

    with open(file_path, 'wb') as f:
        f.write('\n'.join(lines).encode('utf-8-sig'))

    print(f"File {file_path} modified successfully.")

modify_file('tests/Setup-Dotfiles.Tests.ps1')
modify_file('Scripts/Setup-Dotfiles.ps1')

def fix_long_lines(file_path):
    with open(file_path, 'rb') as f:
        content = f.read().decode('utf-8-sig')

    lines = content.split('\n')

    for i in range(len(lines)):
        if len(lines[i]) > 120 and not lines[i].strip().startswith('#'):
            if file_path == 'Scripts/Setup-Dotfiles.ps1':
                if "Get-ChildItem -Path" in lines[i]:
                    lines[i] = lines[i].replace("-Directory -ErrorAction SilentlyContinue |", "`\n        -Directory -ErrorAction SilentlyContinue |")
                elif "ResolveDestination = { $profilePath = Get-FirefoxDefaultProfilePath; if ($profilePath) { Join-Path $profilePath 'user.js' } }" in lines[i]:
                    lines[i] = "    ResolveDestination = { $profilePath = Get-FirefoxDefaultProfilePath\n      if ($profilePath) { Join-Path $profilePath 'user.js' } }"
                elif "Note  = 'manual deployment required; the folder contains mixed scripts, profiles, docs, and registry assets for install.'" in lines[i]:
                    lines[i] = "    Note  = 'manual deployment required; the folder contains mixed scripts, ' +\n      'profiles, docs, and registry assets for install.'"
                elif "  @{ label = 'Execution policy (User)'; ok = (Get-ExecutionPolicy -Scope CurrentUser) -notin @('Restricted', 'Undefined') }" in lines[i]:
                    lines[i] = "  @{ label = 'Execution policy (User)'\n     ok = (Get-ExecutionPolicy -Scope CurrentUser) -notin @('Restricted', 'Undefined') }"
            elif file_path == 'tests/Setup-Dotfiles.Tests.ps1':
                if "Get-Command Get-StarWarsBattlefrontIIActiveProfilePath -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty" in lines[i]:
                    lines[i] = "            Get-Command Get-StarWarsBattlefrontIIActiveProfilePath -ErrorAction SilentlyContinue | `\n                Should -Not -BeNullOrEmpty"
                elif "Get-Command Deploy-StarWarsBattlefrontIIConfigs -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty" in lines[i]:
                    lines[i] = "            Get-Command Deploy-StarWarsBattlefrontIIConfigs -ErrorAction SilentlyContinue | `\n                Should -Not -BeNullOrEmpty"

    with open(file_path, 'wb') as f:
        f.write('\n'.join(lines).encode('utf-8-sig'))

fix_long_lines('tests/Setup-Dotfiles.Tests.ps1')
fix_long_lines('Scripts/Setup-Dotfiles.ps1')

