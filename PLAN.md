# Implementation Plan: Ven0m0/Win Repository

## Current Status: Updated 2026-05-11

## Completed Items

### Steam Optimization (DONE )
- `Scripts/Optimize-Steam.ps1` - Cleans Steam redist installers and integrates NoSteamWebHelper
- `Scripts/New-SteamShortcut.ps1` - Creates optimized Steam desktop shortcut with launch args

### Parser Errors (STILL PENDING )
- `Scripts/arc-raiders/SkipVideosMod.ps1` - Line 29: `| Select-Object -Ex` is incomplete (empty pipe element)
- `Scripts/Network-Tweaker.ps1` - May have issues around line 2395-2396

---

## Remaining Tasks

### Priority 1: Fix Parser Errors

#### Task 1.1: Fix SkipVideosMod.ps1 Line 29
```powershell
# Current (broken):
$steamPath = Get-ItemProperty 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction Stop `
| Select-Object -Ex

# Fix options:
# Option A: Remove backtick, keep on one line
$steamPath = Get-ItemProperty 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction Stop

# Option B: Use splatting
$params = @{ Path = 'HKCU:\Software\Valve\Steam'; Name = 'SteamPath'; ErrorAction = 'Stop' }
$steamPath = Get-ItemProperty @params
```

#### Task 1.2: Verify/Fix Network-Tweaker.ps1
- Need to verify if parser error still exists
- File is 4233 lines - may have other issues

---

### Priority 2: Add Notepad Replacer
- **Reference:** https://www.binaryfortress.com/NotepadReplacer
- **Download:** `https://www.binaryfortress.com/Data/Download/?Package=notepadreplacer&Log=100`
- **Requires:** Notepad++ installed first
- **Action:** Add to `Scripts/Install-Packages.ps1` or winget config

---

### Priority 3: Implement chawyehsu Dotfiles Patterns

#### Task 3.1: Install Bootstrap
- **Reference:** https://github.com/chawyehsu/dotfiles/blob/main/install.ps1
- **Action:** Study and potentially incorporate patterns into `Scripts/Setup-Dotfiles.ps1`

#### Task 3.2: PowerShell Profile
- **Reference:** https://github.com/chawyehsu/dotfiles/blob/main/.config/powershell/profile.ps1
- **Action:** Review for useful aliases, prompt customizations

#### Task 3.3: WSL Configuration
- **Reference:** https://github.com/chawyehsu/dotfiles/tree/main/.config/wsl
- **Action:** Consider adding WSL config deployment to `user/.dotfiles/config/wsl/`

#### Task 3.4: Scoop Configuration
- **Reference:** https://github.com/chawyehsu/dotfiles/blob/main/.config/scoop/config.json
- **Action:** Review and update `user/.dotfiles/config/scoop/config.json`

---

## Validation Checklist

- [ ] SkipVideosMod.ps1 parses without error
- [ ] Network-Tweaker.ps1 parses without error
- [ ] Notepad Replacer added to package installation
- [ ] chawyehsu patterns evaluated and implemented where beneficial

---

## Open Questions

1. **Notepad Replacer:** Need to verify silent install support
2. **chawyehsu Patterns:** Which specific patterns are priority for adoption?