wsl setup:

```cmd
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
wsl --install
code ext install ms-vscode-remote.remote-wsl
```

```ps1
Install-Module -Name PSWindowsUpdate
Install-Module -Name PackageManagement
```
