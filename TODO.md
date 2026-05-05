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
