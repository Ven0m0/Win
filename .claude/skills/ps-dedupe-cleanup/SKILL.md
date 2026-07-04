---
name: ps-dedupe-cleanup
description: >
  Finds and removes duplicated PowerShell code across Scripts/ in the Win repo,
  replacing reinvented helpers with the shared Common.ps1 equivalents, and
  cleans up slop (redundant definitions, missed imports, stale CMD scripts with
  PS equivalents). Uses PSScriptAnalyzer as the before/after quality gate.
  Invoke whenever the user says "dedupe", "clean up scripts", "remove duplicates",
  "consolidate helpers", "tidy up", mentions Common.ps1 redundancy, or asks to
  clean slop out of any Scripts/*.ps1. Also useful after a script merge or when
  adding a new function to Common.ps1 to find callers that can now drop their
  local copy.
---

# PS Dedupe & Cleanup

Systematically find duplicated code, replace it with Common.ps1 helpers, run
PSScriptAnalyzer as the quality gate, and delete stale non-PS equivalents.

---

## Step 1: Baseline PSScriptAnalyzer

Before touching anything, capture the current violation count per file in scope:

```powershell
Invoke-ScriptAnalyzer -Path Scripts/<file>.ps1 -Settings PSScriptAnalyzerSettings.psd1
```

This is your "do no harm" floor — changes must not introduce new violations.

---

## Step 2: Find duplicate function definitions

```powershell
# List every function defined across Scripts/ (excluding Common.ps1 itself)
rg "^function " Scripts/ --glob "*.ps1" --glob "!Common.ps1" -n

# Find scripts that do NOT import Common.ps1
rg -L "Common\.ps1" Scripts/*.ps1
```

Cross-reference against Common.ps1's public API (from AGENTS.md):

| Category     | Helpers                                                                                                                                                                                   |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Output       | `Write-ColorOutput`                                                                                                                                                                       |
| Admin / UI   | `Request-AdminElevation`, `Initialize-ConsoleUI`, `Show-Menu`, `Get-MenuChoice`, `Wait-ForKeyPress`                                                                                       |
| Registry     | `Set-RegistryValue`, `Remove-RegistryValue`, `Get-RegistryValueSafe`                                                                                                                      |
| Downloads    | `Get-FileFromWeb` — handles `$ProgressPreference` internally                                                                                                                              |
| Files / dirs | `Clear-DirectorySafe`, `Clear-PathSafe`, `Ensure-Directory`                                                                                                                               |
| System       | `New-RestorePoint`, `Remove-AppxPackageSafe`, `Invoke-ServiceOperation`, `Invoke-CommandChecked`, `Invoke-RegImport`, `Invoke-Winget`, `Wait-ForWinget`                                   |
| Logging      | `Add-Log`, `Get-Log`, `Clear-Log`                                                                                                                                                         |
| Utilities    | `ConvertFrom-VDF`, `ConvertTo-VDF`, `Get-FolderSize`, `Format-Size`, `Measure-Execution`, `Show-Summary`                                                                                  |
| NVIDIA       | `Get-NvidiaGpuRegistryPath`, `Get-NvidiaGpuPath`, `Set-NvidiaGpuRegistryValue`, `Set-NvidiaSignatureOverride`, `Get-NvidiaSignatureStatus`, `Set-FullscreenMode`, `Set-MultiPlaneOverlay` |

---

## Step 3: Classify each duplicate

| Situation                                                                | Action                                                                                                                      |
| ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| Exact or near-exact duplicate; script already imports Common.ps1         | Remove local definition                                                                                                     |
| Exact or near-exact duplicate; script does NOT import Common.ps1         | Add `. "$PSScriptRoot\Common.ps1"` after `$ErrorActionPreference`/`$ProgressPreference` setup, then remove local definition |
| Same function name, clearly different semantics                          | Leave it — dissimilar things must not be merged                                                                             |
| Locally scoped inside a function body with a different status vocabulary | Leave it — intentional scoping, not global pollution                                                                        |

**Why the locally-scoped rule matters:** `Install-Packages.ps1` and `Setup-Win11.ps1` define `Write-Status` _inside_ a function, with status codes like `'RUNNING'`, `'FAIL'`, `'SKIP'` that have no equivalent in Common.ps1. These are intentionally self-contained, not duplicates.

---

## Step 4: Apply the import + remove pattern

When adding a Common.ps1 import, place it immediately after the top-level variable setup block (after `$ErrorActionPreference`, `$ProgressPreference`, params):

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

. "$PSScriptRoot\Common.ps1"   # ← here
```

Then delete the duplicate function definition (and any extra blank lines it leaves behind — aim for one blank line between top-level items).

---

## Step 5: Common slop patterns to clean while you're in there

- **`Invoke-WebRequest` for downloads** — replace with `Get-FileFromWeb -URL $url -File $path`. Remove any `$ProgressPreference = 'SilentlyContinue'` that was only there to suppress the Invoke-WebRequest progress bar (Get-FileFromWeb handles this internally).
- **Hardcoded `C:\` prefixes** — replace with `$env:SystemDrive\`.
- **`.cmd` scripts with a `.ps1` equivalent in the same directory** — verify the `.ps1` is a superset, then delete the `.cmd`. Check for references first with `rg "\.cmd" --glob "*.ps1" --glob "*.yml" --glob "*.md"`.
- **Commented-out code blocks** — see the `code-cleanup` skill for patterns. Only remove blocks that are clearly abandoned (not `# TODO:`, not explanatory comments).

---

## Step 6: Validate

After every file change:

```powershell
# PSScriptAnalyzer must be clean (or no new violations vs baseline)
Invoke-ScriptAnalyzer -Path Scripts/<file>.ps1 -Settings PSScriptAnalyzerSettings.psd1

# If a Pester test exists, run it
Invoke-Pester -Path tests/<Script>.Tests.ps1 -Output Minimal
```

A completely silent PSScriptAnalyzer output is the definition of done for each file.
