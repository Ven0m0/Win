import re

with open('Scripts/Common.ps1', 'r', encoding='utf-8-sig') as f:
    lines = f.read().splitlines()

for i, line in enumerate(lines):
    if len(line) > 120 and not line.lstrip().startswith('#'):
        indent = len(line) - len(line.lstrip())
        indent_str = ' ' * indent

        # Specific fixes
        if "if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {" in line:
            lines[i] = f"{indent_str}$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()\n{indent_str}$adminRole = [Security.Principal.WindowsBuiltInRole]'Administrator'\n{indent_str}if (!($principal.IsInRole($adminRole))) {{"
        elif "Start-Process PowerShell.exe -ArgumentList (\"-NoProfile -ExecutionPolicy Bypass -File `\"{0}`\"\" -f $PSCommandPath) -Verb RunAs" in line:
            lines[i] = f"{indent_str}$args = \"-NoProfile -ExecutionPolicy Bypass -File `\"{{0}}`\"\" -f $PSCommandPath\n{indent_str}Start-Process PowerShell.exe -ArgumentList $args -Verb RunAs"
        elif "$entry.P0State = (Get-ItemProperty -Path \"Registry::$path\" -Name 'DisableDynamicPstate' -ErrorAction Stop).DisableDynamicPstate" in line:
            lines[i] = f"{indent_str}$prop = Get-ItemProperty -Path \"Registry::$path\" -Name 'DisableDynamicPstate' -ErrorAction Stop\n{indent_str}$entry.P0State = $prop.DisableDynamicPstate"
        elif "$entry.HDCP = (Get-ItemProperty -Path \"Registry::$path\" -Name 'RMHdcpKeyglobZero' -ErrorAction Stop).RMHdcpKeyglobZero" in line:
            lines[i] = f"{indent_str}$prop = Get-ItemProperty -Path \"Registry::$path\" -Name 'RMHdcpKeyglobZero' -ErrorAction Stop\n{indent_str}$entry.HDCP = $prop.RMHdcpKeyglobZero"
        elif "Write-Host \"  [WARN] Failed to update BCDEDIT settings (may require Secure Boot disabled or elevated PowerShell)\" -ForegroundColor Yellow" in line:
            lines[i] = f"{indent_str}Write-Host \"  [WARN] Failed to update BCDEDIT settings `\n{indent_str}      (may require Secure Boot disabled or elevated PowerShell)\" -ForegroundColor Yellow"
        elif 'Set-RegistryValue -Path "HKLM\\SOFTWARE\\NVIDIA Corporation\\Global" -Name "{41FCC608-8496-4DEF-B43E-7D9BD675A6FF}" -Type "REG_BINARY" -Data $regData' in line:
            lines[i] = f"{indent_str}$path = \"HKLM\\SOFTWARE\\NVIDIA Corporation\\Global\"\n{indent_str}$name = \"{{41FCC608-8496-4DEF-B43E-7D9BD675A6FF}}\"\n{indent_str}Set-RegistryValue -Path $path -Name $name -Type \"REG_BINARY\" -Data $regData"
        elif 'Set-RegistryValue -Path "HKLM\\SYSTEM\\CurrentControlSet\\Services\\nvlddmkm" -Name "{41FCC608-8496-4DEF-B43E-7D9BD675A6FF}" -Type "REG_BINARY" -Data $regData' in line:
            lines[i] = f"{indent_str}$path = \"HKLM\\SYSTEM\\CurrentControlSet\\Services\\nvlddmkm\"\n{indent_str}$name = \"{{41FCC608-8496-4DEF-B43E-7D9BD675A6FF}}\"\n{indent_str}Set-RegistryValue -Path $path -Name $name -Type \"REG_BINARY\" -Data $regData"
        elif '$globalVal = Get-RegistryValueSafe -Path "HKLM:\\SOFTWARE\\NVIDIA Corporation\\Global" -Name "{41FCC608-8496-4DEF-B43E-7D9BD675A6FF}"' in line:
            lines[i] = f"{indent_str}$path = \"HKLM:\\SOFTWARE\\NVIDIA Corporation\\Global\"\n{indent_str}$name = \"{{41FCC608-8496-4DEF-B43E-7D9BD675A6FF}}\"\n{indent_str}$globalVal = Get-RegistryValueSafe -Path $path -Name $name"
        elif '$serviceVal = Get-RegistryValueSafe -Path "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\nvlddmkm" -Name "{41FCC608-8496-4DEF-B43E-7D9BD675A6FF}"' in line:
            lines[i] = f"{indent_str}$path = \"HKLM:\\SYSTEM\\CurrentControlSet\\Services\\nvlddmkm\"\n{indent_str}$name = \"{{41FCC608-8496-4DEF-B43E-7D9BD675A6FF}}\"\n{indent_str}$serviceVal = Get-RegistryValueSafe -Path $path -Name $name"
        elif "Write-Host -NoNewLine \"`r$ProgressText $(''.PadRight($BarSize * $percent, [char]9608).PadRight($BarSize, [char]9617)) $($percentComplete.ToString('##0.00').PadLeft(6)) % \"" in line:
            lines[i] = f"{indent_str}$bar = ''.PadRight($BarSize * $percent, [char]9608).PadRight($BarSize, [char]9617)\n{indent_str}$pct = $($percentComplete.ToString('##0.00').PadLeft(6))\n{indent_str}Write-Host -NoNewLine \"`r$ProgressText $bar $pct % \""
        elif "$script:CachedMonitorInstances = (Get-CimInstance -Namespace root\\wmi -ClassName WmiMonitorID -ErrorAction Stop).InstanceName -replace '_0', ''" in line:
            lines[i] = f"{indent_str}$monitors = Get-CimInstance -Namespace root\\wmi -ClassName WmiMonitorID -ErrorAction Stop\n{indent_str}$script:CachedMonitorInstances = $monitors.InstanceName -replace '_0', ''"
        elif 'Set-RegistryValue -Path "HKCU\\System\\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Type REG_DWORD -Data "0"' in line:
            lines[i] = f"{indent_str}$path = \"HKCU\\System\\GameConfigStore\"\n{indent_str}Set-RegistryValue -Path $path -Name \"GameDVR_DXGIHonorFSEWindowsCompatible\" -Type REG_DWORD -Data \"0\""
        elif 'Set-RegistryValue -Path "HKCU\\System\\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Type REG_DWORD -Data "0"' in line:
            lines[i] = f"{indent_str}$path = \"HKCU\\System\\GameConfigStore\"\n{indent_str}Set-RegistryValue -Path $path -Name \"GameDVR_HonorUserFSEBehaviorMode\" -Type REG_DWORD -Data \"0\""
        elif 'Set-RegistryValue -Path "HKCU\\System\\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Type REG_DWORD -Data "1"' in line:
            lines[i] = f"{indent_str}$path = \"HKCU\\System\\GameConfigStore\"\n{indent_str}Set-RegistryValue -Path $path -Name \"GameDVR_DXGIHonorFSEWindowsCompatible\" -Type REG_DWORD -Data \"1\""
        elif 'Set-RegistryValue -Path "HKCU\\System\\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Type REG_DWORD -Data "1"' in line:
            lines[i] = f"{indent_str}$path = \"HKCU\\System\\GameConfigStore\"\n{indent_str}Set-RegistryValue -Path $path -Name \"GameDVR_HonorUserFSEBehaviorMode\" -Type REG_DWORD -Data \"1\""
        elif 'Set-RegistryValue -Path "HKCU\\Software\\Microsoft\\DirectX\\UserGpuPreferences" -Name "DirectXUserGlobalSettings" -Type REG_SZ -Data "VRROptimizeEnable=0;SwapEffectUpgradeEnable=1;"' in line:
            lines[i] = f"{indent_str}$path = \"HKCU\\Software\\Microsoft\\DirectX\\UserGpuPreferences\"\n{indent_str}$data = \"VRROptimizeEnable=0;SwapEffectUpgradeEnable=1;\"\n{indent_str}Set-RegistryValue -Path $path -Name \"DirectXUserGlobalSettings\" -Type REG_SZ -Data $data"
        elif 'Set-RegistryValue -Path "HKLM\\SOFTWARE\\Microsoft\\Windows\\Dwm" -Name "OverlayTestMode" -Type REG_DWORD -Data "5"' in line:
            lines[i] = f"{indent_str}$path = \"HKLM\\SOFTWARE\\Microsoft\\Windows\\Dwm\"\n{indent_str}Set-RegistryValue -Path $path -Name \"OverlayTestMode\" -Type REG_DWORD -Data \"5\""
        elif 'Set-RegistryValue -Path "HKCU\\Software\\Microsoft\\DirectX\\UserGpuPreferences" -Name "DirectXUserGlobalSettings" -Type REG_SZ -Data "VRROptimizeEnable=0;SwapEffectUpgradeEnable=0;"' in line:
            lines[i] = f"{indent_str}$path = \"HKCU\\Software\\Microsoft\\DirectX\\UserGpuPreferences\"\n{indent_str}$data = \"VRROptimizeEnable=0;SwapEffectUpgradeEnable=0;\"\n{indent_str}Set-RegistryValue -Path $path -Name \"DirectXUserGlobalSettings\" -Type REG_SZ -Data $data"
        elif '$dxSettings = Get-RegistryValueSafe -Path "HKCU:\\Software\\Microsoft\\DirectX\\UserGpuPreferences" -Name "DirectXUserGlobalSettings"' in line:
            lines[i] = f"{indent_str}$path = \"HKCU:\\Software\\Microsoft\\DirectX\\UserGpuPreferences\"\n{indent_str}$dxSettings = Get-RegistryValueSafe -Path $path -Name \"DirectXUserGlobalSettings\""
        elif 'Get-ChildItem "$Path" -Recurse -File -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue' in line:
            lines[i] = f"{indent_str}$items = Get-ChildItem \"$Path\" -Recurse -File -Force -ErrorAction SilentlyContinue\n{indent_str}$items | Remove-Item -Force -ErrorAction SilentlyContinue"
        elif 'Checkpoint-Computer -Description "$Description $(Get-Date -Format \'yyyy-MM-dd HH:mm\')" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop' in line:
            lines[i] = f"{indent_str}$desc = \"$Description $(Get-Date -Format 'yyyy-MM-dd HH:mm')\"\n{indent_str}Checkpoint-Computer -Description $desc -RestorePointType \"MODIFY_SETTINGS\" -ErrorAction Stop"
        elif 'Write-Host "    Failed to remove provisioned package $($package.DisplayName): $($_.Exception.Message)" -ForegroundColor Red' in line:
            lines[i] = f"{indent_str}$msg = \"    Failed to remove provisioned package $($package.DisplayName): $($_.Exception.Message)\"\n{indent_str}Write-Host $msg -ForegroundColor Red"
        elif "$edidHex = '02030400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f7'" in line:
            lines[i] = f"{indent_str}$edidHex = '02030400000000000000000000000000000000000000000000000000000000000000000000000000' +\n{indent_str}           '00000000000000000000000000000000000000000000000000000000000000000000000000000000' +\n{indent_str}           '000000000000000000000000000000000000000000000000000000000000000000000000000000f7'"
        elif '$regPath = "HKLM\\SYSTEM\\ControlSet001\\Enum\\$instanceID\\Device Parameters\\Interrupt Management\\MessageSignaledInterruptProperties"' in line:
            lines[i] = f"{indent_str}$basePath = \"HKLM\\SYSTEM\\ControlSet001\\Enum\\$instanceID\\Device Parameters\\Interrupt Management\"\n{indent_str}$regPath = \"$basePath\\MessageSignaledInterruptProperties\""
        elif '$regPath = "Registry::HKLM\\SYSTEM\\ControlSet001\\Enum\\$instanceID\\Device Parameters\\Interrupt Management\\MessageSignaledInterruptProperties"' in line:
            lines[i] = f"{indent_str}$basePath = \"Registry::HKLM\\SYSTEM\\ControlSet001\\Enum\\$instanceID\\Device Parameters\"\n{indent_str}$regPath = \"$basePath\\Interrupt Management\\MessageSignaledInterruptProperties\""
        elif "$steamPath = (Get-ItemProperty \"HKLM:\\SOFTWARE\\WOW6432Node\\Valve\\Steam\" -Name 'InstallPath' -ErrorAction SilentlyContinue).InstallPath" in line:
            lines[i] = f"{indent_str}$prop = Get-ItemProperty \"HKLM:\\SOFTWARE\\WOW6432Node\\Valve\\Steam\" -Name 'InstallPath' -ErrorAction SilentlyContinue\n{indent_str}$steamPath = $prop.InstallPath"
        elif "$steamPath = (Get-ItemProperty \"HKCU:\\Software\\Valve\\Steam\" -Name 'SteamPath' -ErrorAction SilentlyContinue).SteamPath" in line:
            lines[i] = f"{indent_str}$prop = Get-ItemProperty \"HKCU:\\Software\\Valve\\Steam\" -Name 'SteamPath' -ErrorAction SilentlyContinue\n{indent_str}$steamPath = $prop.SteamPath"
        elif "Get-Process -Name 'steam', 'steamwebhelper' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue" in line:
            lines[i] = f"{indent_str}$procs = Get-Process -Name 'steam', 'steamwebhelper' -ErrorAction SilentlyContinue\n{indent_str}$procs | Stop-Process -Force -ErrorAction SilentlyContinue"
        else:
            # Fallback for anything else
            pass

content = '\n'.join(lines)
content = content.replace('\n', '\r\n')

with open('Scripts/Common.ps1', 'wb') as f:
    f.write(b'\xef\xbb\xbf' + content.encode('utf-8'))
