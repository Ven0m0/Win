---
name: code-cleanup
description: |
  Dead code removal, script merging, and repo-level cleanup for the Win dotfiles repository.
  Use when removing commented-out blocks, merging overlapping scripts, or doing a full repo janitor pass.
compatibility: opencode
---

# Code Cleanup

Load this skill for any of: removing commented-out code or unused variables, merging two scripts with >80% overlap, or a full repository cleanup pass.

## When to Load

- "Remove dead code / clean up commented-out blocks"
- "Merge `scripts/foo.ps1` and `scripts/bar.ps1` — they're almost identical"
- "Clean up the repo / remove legacy scripts / prune docs"
- "Dedupe helpers across Scripts/"

---

## 1. Dead Code Removal

### Patterns to target

```powershell
# Commented-out debug output
#Write-Host "Powershell"
#cls

# Commented-out fallback logic
#if ($null -eq $cb_Value.Text) { $cb_Value.Text = '65536' }
##Bypass
##Set-NetOffloadGlobalSetting -NetworkDirect $value

# Empty if-branch containing only comments → invert the condition
if ($cb_osrss.text -eq $current) {
    #Write-Host " same as Current, skipping."
} else {
    Set-NetOffloadGlobalSetting -ReceiveSideScaling $cb_osrss.text
}
# → becomes: if ($cb_osrss.text -ne $current) { ... }
```

### Search commands

```bash
# Commented function calls
rg "^\s*#\s*(Write-Host|Write-Verbose|Set-|Get-|Invoke-|Remove-)" --type ps1

# Commented conditionals
rg "^\s*#if\s*\(" --type ps1

# Double-commented lines (abandoned code)
rg "^##" --type ps1
```

### Cleanup checklist

1. Search with commands above; verify each match is truly dead (not a TODO or design note)
2. Remove the commented lines
3. Invert conditionals that now have an empty branch
4. Remove trailing blank lines left by deletions
5. Verify syntax: `pwsh -Command "[System.Management.Automation.PSParser]::Tokenize(...)"` 
6. Run `mise run lint`

### Safety rules

- Keep comments that explain **why** code exists
- Keep `TODO`/`FIXME` comments — they track pending work
- Remove comments that repeat what the code already says
- Remove commented-out code blocks (git history has them)

---

## 2. Script Merge (>80% overlap)

### Step 1: Identify differences

Document exactly what changes between the two scripts:
```powershell
# Example: steam.ps1 vs arc-raiders/steam.ps1
# $NoGPU: 1 (default) vs 0 (ArcRaiders)
# SmallMode: '1' vs '0'
# Launch args: -quicklogin present vs absent
```

### Step 2: Add a `-Mode` parameter

```powershell
[CmdletBinding()]
param(
  [Parameter()]
  [ValidateSet('Default', 'ArcRaiders')]
  [string]$Mode = 'Default'
)
```

### Step 3: Parameterize the differences

```powershell
$NoGPU     = if ($Mode -eq 'ArcRaiders') { 0 } else { 1 }
$SmallMode = if ($Mode -eq 'ArcRaiders') { '0' } else { '1' }
```

### Step 4: Update invocation guard

```powershell
if ($MyInvocation.InvocationName -ne '.') { Invoke-SteamOptimization -SteamMode $Mode; exit $LASTEXITCODE }
```

### Step 5: Delete merged source, update callers

```bash
rm Scripts/arc-raiders/steam.ps1
rg "arc-raiders.*steam|steam.*arc-raiders" --type ps1   # verify no orphaned imports
```

### Merge checklist

1. Document all differences
2. Create parameterized modes with `ValidateSet`
3. Merge duplicate helpers (`vdf_mkdir`, etc.)
4. Test all modes: `.\script.ps1 -Mode Default` and `.\script.ps1 -Mode ArcRaiders`
5. Delete merged source; verify no orphaned imports
6. Run `mise run lint` and relevant Pester tests

### Anti-patterns

- Don't merge scripts with fundamentally different purposes
- Don't create more than 3 modes — use separate scripts instead
- Don't delete source until all modes pass

---

## 3. Repository Cleanup Pass

### Inventory first

| Category | Examples | Action |
|---|---|---|
| Code | `.ps1`, `.bat`, `.ahk` | Keep; refactor if needed |
| Config | `.json`, `.yaml`, `.reg`, `.xml` | Keep; validate format |
| Tests | `*.Tests.ps1` | Keep; move to `tests/` if misplaced |
| Docs | `*.md` | Review for duplication/staleness |
| Build artifacts | `dist/`, `node_modules/` | Delete; add to `.gitignore` |

### Canonical layout (Ven0m0/Win)

- `Scripts/` — executable PowerShell automation
- `Scripts/Common.ps1` — shared helpers only (never duplicate)
- `Scripts/auto/` — unattended XML only (no flat scripts)
- `user/.dotfiles/config/` — tracked dotfiles
- `tests/` — Pester tests
- `.kilo/skills/` — skills as `<name>/SKILL.md`

### Remove legacy code — candidates

- Functions with no callers (search with `rg`)
- Scripts superseded by newer equivalents
- Commented-out blocks older than two releases
- Dead branches: `if ($false) { ... }`

Safety rule: if no tests and no clear caller, add a deprecation comment first; delete only after confirming no external dependencies.

### Prune documentation sprawl

- Consolidate overlapping README sections
- Delete empty or placeholder markdown files
- Ensure `AGENTS.md` is the single AI guidance source of truth
- Keep `.github/copilot-instructions.md` minimal
- Remove hyperbolic language (`comprehensive`, `ultimate`, `revolutionary`)

### Safety checks before any deletion

```bash
git checkout -b cleanup/$(date +%Y%m%d)   # checkpoint branch
git diff --stat                            # review before committing
```

1. Confirm working tree is clean before starting
2. Search for the file/symbol across the repo before deleting
3. Verify no tests import or invoke the target
4. Check `.github/workflows/` for references
5. Stage deletions in a single commit so revert is one command

### Invariants

- Do not delete code that has active callers unless you also refactor the callers
- Do not delete tests unless the tested code is also deleted
- Do not delete `AGENTS.md`, `README.md`, or `install.conf.yaml`
- Preserve native file formatting (JSON, YAML, REG) — no cosmetic re-serialization
- When in doubt, move to `archive/` instead of deleting

---

## 4. Validation After Cleanup

```powershell
# PowerShell linting (all changed files)
Invoke-ScriptAnalyzer -Path Scripts/<file>.ps1 -Settings PSScriptAnalyzerSettings.psd1

# Tests
Invoke-Pester -Path tests/ -Output Minimal

# XML
$xml = [xml]::new(); $xml.Load('Scripts/auto/autounattend.xml')
```

Structural checks:
- [ ] No orphaned files referenced in `install.conf.yaml` or `AGENTS.md`
- [ ] All `Scripts/**/*.ps1` pass `Invoke-ScriptAnalyzer`
- [ ] Bootstrap scripts still execute without error
- [ ] `install.conf.yaml` paths resolve
