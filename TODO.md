use PSIni powershell module for ini like config file modifications

add Psmodule pester

add 
- https://github.com/ChrisTitusTech/winutil/blob/main/.github/workflows/unittests.yaml

```pwsh
dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase /RestoreHealth
```

- https://github.com/emylfy/Winrift


- Add "PowerShell-Beautifier" module and use it to format ps1 files: `Install-Module -Name PowerShell-Beautifier`
- Consider "PSParallel" for bulk operations
- "Refactor" When you need to rename functions/commands across multiple script files

- Fix "Scripts/arc-raiders/SkipVideosMod.ps1" error: 
```pwsh
ParserError: C:\Users\Ven0m0\projects\Win\Scripts\arc-raiders\SkipVideosMod.ps1:34
Line |
  34 |      -Name InstallPath -ErrorAction Stop |
     |                                           ~
     | An empty pipe element is not allowed.
```
- Fix "Scripts\Network-Tweaker" errpr:
```pwsh
ParserError: C:\Users\Ven0m0\projects\Win\Scripts\Network-Tweaker.ps1:2398
Line |
2398 |        Write-Host "Path found at ($KeyPath)."
     |                    ~~~~
     | Unexpected token 'Path' in expression or statement.
```

fix .github/workflows/powershell.yml and ensure psscriptanalyzer hasno issues or warnings for the repo

---

- clean steam redist installers:
  ```text
  C:\Program Files (x86)\Steam\steamapps\common\Steamworks Shared\_CommonRedist\DirectX
  C:\Program Files (x86)\Steam\steamapps\common\Steamworks Shared\_CommonRedist\vcredist
  ```
- download [umpdc.dll](https://github.com/Aetopia/NoSteamWebHelper) to disable Steam's CEF/Chromium Embedded Framework. Move it to "C:\Program Files (x86)\Steam"
- Create desktop shortcut with these steam launch arguments: `"C:\Program Files (x86)\Steam\Steam.exe" -nofriendsui -nointro -nobigpicture -cef-single-process -cef-disable-breakpad -cef-disable-gpu-compositing -cef-disable-gpu -cef-disable-js-logging -noconsole +open steam://open/minigameslist`
