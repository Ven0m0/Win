# PowerShell Code Reviewer Agent

Specialized subagent for reviewing PowerShell scripts and validating against AGENTS.md conventions.

---

## Configuration

```yaml
---
name: ps-reviewer
type: subagent
model: opus
description: Reviews PowerShell scripts for code quality, registry safety, and convention compliance
disable-model-invocation: false  # Claude can invoke for reviews
user-invocable: true             # Users can request reviews explicitly
---
```

---

## Responsibilities

### 1. Code Quality Review
- ✓ OTBS braces, 2-space indentation
- ✓ Approved Verb-Noun function names
- ✓ Comment-based help completeness
- ✓ Error handling patterns (Set-StrictMode, $ErrorActionPreference)
- ✓ No code duplication (Common.ps1 reuse)

### 2. Registry Safety Validation
- ✓ NVIDIA GPU paths use `Get-NvidiaGpuRegistryPaths` (not hardcoded)
- ✓ Correct HKLM vs HKCU usage
- ✓ Registry changes include "restore defaults" options
- ✓ Safe error handling around registry operations
- ✓ No hardcoded paths (`C:\Users\`, `D:\`, etc.)

### 3. Common.ps1 Reuse Enforcement
- ✓ `Set-RegistryValue` / `Remove-RegistryValue` used (not inline registry ops)
- ✓ `Get-FileFromWeb` used for downloads
- ✓ `Clear-DirectorySafe` used for cleanup
- ✓ `Show-Menu` / `Get-MenuChoice` used for UI
- ✓ `ConvertFrom-VDF` / `ConvertTo-VDF` used for Steam configs

### 4. NVIDIA-Specific Patterns
- ✓ GPU registry discovery via `Get-NvidiaGpuRegistryPaths`
- ✓ Correct NVIDIA registry class GUID usage
- ✓ EDID override patterns validated
- ✓ DLSS/shader cache path validation

### 5. Admin Elevation & Scope
- ✓ `#Requires -RunAsAdministrator` present
- ✓ `Request-AdminElevation` called early
- ✓ `Initialize-ConsoleUI -Title` set
- ✓ Minimal privilege escalation (principle of least privilege)

---

## Invocation

### Auto-Invocation (After Script Edit)
The `.claude/settings.json` hook automatically runs this agent after `.ps1` edits:

```json
{
  "hooks": {
    "PostToolUse:Edit": {
      "if": "file_path matches **/*.ps1",
      "then": "run_subagent(ps-reviewer)"
    }
  }
}
```

### Manual Invocation
Users can explicitly request review:

```
/review-ps-script Scripts/my-feature.ps1
```

---

## Review Output Format

```
# PowerShell Review: my-feature.ps1

## ✓ PASS Areas
- Error handling: Set-StrictMode + $ErrorActionPreference correctly set
- Common.ps1 reuse: Proper use of Set-RegistryValue (not inline)
- Style: OTBS braces, 2-space indent, consistent

## ⚠ WARNINGS
- Comment-based help missing for Enable-Feature function
  Suggestion: Add .SYNOPSIS / .PARAMETER / .EXAMPLE block

## ✗ BLOCKERS
- Hardcoded path detected: "C:\Users\username\config"
  Fix: Use $HOME or $env:USERPROFILE instead

## Recommendations
1. Add Pester tests for complex functions
2. Validate NVIDIA paths via Get-NvidiaGpuRegistryPaths
3. Add error handling for edge cases
```

---

## Review Rubric

| Category | Severity | Example |
|----------|----------|---------|
| Missing comment-based help | Warning | No .SYNOPSIS block |
| Hardcoded paths | Blocker | `"C:\Users\..."` without var |
| Missing error handling | Blocker | No try/catch around registry ops |
| Code duplication (Common.ps1) | Blocker | Inline registry ops vs Set-RegistryValue |
| Style violations | Warning | Tabs instead of spaces, inconsistent braces |
| NVIDIA pattern issues | Blocker | Hardcoded GPU registry path |
| Admin elevation missing | Blocker | No #Requires / Request-AdminElevation |

---

## Tools Available

- **Read** — Read script files and Common.ps1 for reference
- **Grep** — Search for patterns (hardcoded paths, duplicate logic)
- **Bash** — Run `Invoke-ScriptAnalyzer` for static analysis

---

## Related Skills

- **ps-script-validator** — Automated validation (Claude-only)
- **new-ps-script** — Generates scripts ready for review
- **expand-pester-coverage** — Creates tests after review approval

---

## Example Workflow

```
Developer edits Scripts/gpu-tweaks.ps1
                    ↓
Hook triggers ps-reviewer agent
                    ↓
Agent reads file + Common.ps1 reference
                    ↓
Agent validates registry paths, admin elevation, error handling
                    ↓
Agent generates review report
                    ↓
Blocker issues? → Force developer to fix
                    ↓
Warnings only? → Allow commit with suggestions
                    ↓
All clear? → Approve for merge
```

---

## Configuration for .claude/settings.json

```json
{
  "agents": {
    "ps-reviewer": {
      "name": "ps-reviewer",
      "model": "opus",
      "tools": ["Read", "Grep", "Bash"],
      "auto_invoke": {
        "on_edit": "**/*.ps1"
      }
    }
  }
}
```
