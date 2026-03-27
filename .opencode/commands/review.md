---
description: Diff-aware code review focused on PowerShell style, security, and Common.ps1 usage
agent: code
---

Review the staged/unstaged changes for correctness, style compliance, and security.

Changed files:
```
!`git diff HEAD --name-only 2>/dev/null | head -30`
```

Full diff:
```diff
!`git diff HEAD 2>/dev/null | head -300`
```

Review checklist — flag any violation:

**Style (enforced by .editorconfig + PSScriptAnalyzer CI)**
- [ ] OTBS braces: opening `{` on same line, never on new line
- [ ] 2-space indent — no tabs anywhere in `.ps1`/`.psm1`
- [ ] Spaces around operators (`=`, `+`, `-eq`, `|`)
- [ ] Max line length 120 chars for PowerShell files
- [ ] File named `lowercase-with-dashes.ps1`

**Architecture**
- [ ] New scripts are in `Scripts/`, not project root
- [ ] Configs go in `user/.dotfiles/config/`, not `.config/` (deprecated)
- [ ] No hardcoded paths — uses `$PSScriptRoot` or `$HOME`
- [ ] Logic repeated ≥2 times is extracted to `Common.ps1`, not duplicated

**Common.ps1 usage**
- [ ] Script imports `. "$PSScriptRoot\Common.ps1"` before using shared functions
- [ ] Uses `Set-RegistryValue`/`Remove-RegistryValue` — not direct `Set-ItemProperty`
- [ ] Uses `Get-FileFromWeb` — not raw `Invoke-WebRequest` inline
- [ ] Uses `Clear-DirectorySafe` for directory clearing (robocopy-backed)

**Security**
- [ ] No `Invoke-Expression` with variable input
- [ ] No `$ErrorActionPreference = "SilentlyContinue"` at global scope
- [ ] No hardcoded credentials, tokens, or personal paths
- [ ] No `.gitconfig.local`, `.ssh/` (except `config`), or `local.ps1` staged

**Comment-based help**
- [ ] Every new public function has `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`

Summarize: pass / fail per category. List each violation with file:line and suggested fix.
