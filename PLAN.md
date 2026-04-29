# Implementation Plan
_Generated: 2026-04-29T12:08:26Z · 4 tasks · Est. M–L_

## Summary
This plan captures four work items from `TODO.md`: integrating `py-psscriptanalyzer` into the build pipeline, adding a Windows Update repair source, implementing a robust winget wait-and-install pattern, and fixing broken autounattend XML scripts for both Windows 10 and Windows 11.

## Research Notes

### T001 — py-psscriptanalyzer
Ref-tools (Exa code search + web fetch) retrieved the official docs at https://py-psscriptanalyzer.thetestlabs.io. Key findings:
- **Installation:** `pip install py-psscriptanalyzer` (requires Python 3.9+, PowerShell Core 7.0+). The tool auto-installs the PSScriptAnalyzer module on first use.
- **CLI flags:** `--recursive`, `--format`, `--severity {Information,Warning,Error,All}`, `--security-only`, `--output-format {text,json,sarif}`, `--output-file`, `--include-rules`, `--exclude-rules`.
- **Pre-commit hooks:** Two hooks available: `py-psscriptanalyzer` (lint) and `py-psscriptanalyzer-format` (format). Config example:
  ```yaml
  repos:
    - repo: https://github.com/thetestlabs/py-psscriptanalyzer
      rev: v0.3.1
      hooks:
        - id: py-psscriptanalyzer
          args: ["--severity", "Warning"]
        - id: py-psscriptanalyzer-format
  ```
- **CI integration:** GitHub Actions example uses `pip install py-psscriptanalyzer` then `py-psscriptanalyzer --recursive`. SARIF output is supported for GitHub Code Scanning.
- **Environment variable:** `SEVERITY_LEVEL` can set default severity (overridden by CLI `--severity`).
- **Action for PLAN:** Add `py-psscriptanalyzer` to `mise.toml` tasks, add `.pre-commit-config.yaml` with the two hooks, and update `.github/workflows/powershell.yml` to use `py-psscriptanalyzer --recursive --severity Error` (or Warning).

### T002 — ShadowWhisperer Fix-WinUpdates
GitHub API confirmed `ShadowWhisperer/Fix-WinUpdates` exists (8 stars, 1 fork, Batchfile 100%). README and `Fix Updates.bat` retrieved via `octocode_githubGetFileContent`. Key findings:
- **What it does:** Batch script that repairs Windows Update via 7 steps:
  1. Stops BITS and wuauserv services
  2. Configures service start types (wuauserv=auto, BITS=delayed-auto, AppReadiness=manual, CryptSvc=auto)
  3. Deletes pending/cached updates (Temp, Prefetch, SoftwareDistribution, reboot-required registry keys)
  4. Deletes malformed registry keys under `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore`
  5. Resets catroot2, re-registers WU DLLs (atl.dll, msxml*.dll, wuaueng*.dll, etc.), resets BITS, winsock
  6. Applies registry fixes (disable "Get updates ASAP", disable "Let's finish setting up your device", remove target release version constraints)
  7. Runs gpupdate /force, prompts for reboot
- **Caveats:** The script is a `.bat` file, not PowerShell. It uses `>nul 2>&1` everywhere (hides failures). It prompts for reboot with `pause`, which is non-ideal for automation. It modifies HKCU while running as SYSTEM in autounattend context (may not apply to the intended user).
- **Action for PLAN:** Instead of downloading and executing the batch file blindly, port the safe operations (service reset, SoftwareDistribution clear, DLL re-register) into a PowerShell script `Scripts/Fix-WindowsUpdates.ps1` using `Common.ps1` helpers. Skip the interactive `pause` and `shutdown /r`. Add `-WhatIf` support.

### T003 — winget wait-loop
Exa retrieved the exact schneegans sample (see https://schneegans.de/windows/unattend-generator/samples/). Key findings:
- The wait-loop is required because on Windows 11 24H2+ the `winget.exe` stub is not immediately present after first logon; Windows needs time to finish UWP app registration.
- The sample uses `--scope machine`, which requires admin elevation. In non-admin contexts this will fail silently.
- Timeout is 5 minutes with 1-second polling; this is acceptable but should be parameterized.
- The build guard (`-lt 26100`) restricts the script to Windows 11 24H2+. For Windows 10 autounattend, omit the guard or adjust the build number.

### T004 — autounattend.xml fixes
Exa + GitHub research surfaced multiple common failure modes for embedded-script autounattend files:
1. **ExtractScript mechanism** — The `ExtractScript` entity must be correctly encoded (`&#xA;` for newlines) and the extraction command must reference `C:\Windows\Panther\unattend.xml` (not `autounattend.xml`). See memstechtips/UnattendedWinstall commit `cfc62e2` for a working pattern.
2. **FirstLogonCommands vs RunSynchronous** — `FirstLogonCommands` belongs in the `oobeSystem` pass; `RunSynchronousCommand` belongs in `specialize`. Mixing them causes Windows Setup to skip commands. See SuperUser #1342587.
3. **Log locations** — If scripts fail, inspect:
   - `C:\Windows\Panther\setupact.log` (PE stage)
   - `C:\Windows\Setup\Scripts\*.log` (post-install)
   - `%TEMP%\UserOnce.log` (user-once scripts)
4. **Script extraction failures** — Ensure the SYSTEM account has write access to `C:\Windows\Setup\Scripts\` and that PowerShell 5.1+ is available.
5. **Validation** — Always validate with `[xml]::new().Load(path)` before committing changes.

## Task Index (topological order)
| # | ID | Title | Sev | Cat | Size | Blocks |
|---|-----|-------|-----|-----|------|--------|
| 1 | T001 | Integrate py-psscriptanalyzer into mise.toml and pre-commit | medium | refactor | M | — |
| 2 | T002 | Add ShadowWhisperer Fix-WinUpdates to system fix scripts | low | feature | S | — |
| 3 | T003 | Implement winget wait-loop with timeout and scope fix | high | bug | S | — |
| 4 | T004 | Fix broken autounattend.xml and autounattend-windows10.xml | critical | bug | L | T003 |

## Tasks

### T001 · Integrate py-psscriptanalyzer into mise.toml and pre-commit
**File:** `mise.toml:0` (new entries), `TODO.md:1`
**Severity:** medium · **Category:** refactor · **Size:** M
**Blocks:** —  **Blocked by:** —
**Context:**
> extend py-psscriptanalyzer integration and include it in @mise.toml
> also ensure the pre-commit hooks of py-psscriptanalyzer work correctly
**Intent:** Add Python-based PSScriptAnalyzer wrapper to the project's task runner and enforce it before commits.
**Acceptance criteria:**
- [ ] `mise.toml` contains a `[tasks.lint]` or `[tasks.analyze]` entry that runs `py-psscriptanalyzer --recursive`
- [ ] `mise.toml` contains a `[tasks.format]` entry that runs `py-psscriptanalyzer --format <file>`
- [ ] A pre-commit hook (`.pre-commit-config.yaml` or equivalent) invokes `py-psscriptanalyzer` on staged `*.ps1` files
- [ ] Running `mise run lint` exits `0` when no issues exist and non-zero when issues are found
- [ ] CI workflow (`.github/workflows/powershell.yml`) is updated to use `py-psscriptanalyzer` instead of or alongside `Invoke-ScriptAnalyzer`
**Implementation:**
```toml
[tasks.lint]
description = "Lint PowerShell files with py-psscriptanalyzer"
run = "py-psscriptanalyzer --recursive"

[tasks.format]
description = "Format a PowerShell file"
run = "py-psscriptanalyzer --format {{arg(name='file')}}"
```
Add `py-psscriptanalyzer` to `pyproject.toml` `[project.optional-dependencies] dev` or `requirements-dev.txt`.
**Estimated LOC delta:** 20–60 lines across `mise.toml`, `.pre-commit-config.yaml`, and CI YAML.

---

### T002 · Add ShadowWhisperer Fix-WinUpdates to system fix scripts
**File:** `TODO.md:14`
**Severity:** low · **Category:** feature · **Size:** S
**Blocks:** —  **Blocked by:** —
**Context:**
> add to system fix:
> - https://github.com/ShadowWhisperer/Fix-WinUpdates
**Intent:** Integrate a third-party Windows Update repair script into the existing system-fix workflow.
**Acceptance criteria:**
- [ ] New script `Scripts/Fix-WindowsUpdates.ps1` created that downloads and runs `ShadowWhisperer/Fix-WinUpdates` safely
- [ ] Script uses `Invoke-WebRequest` with `$ProgressPreference = 'SilentlyContinue'` for download
- [ ] Script validates SHA256 checksum of downloaded content before execution (if upstream publishes one)
- [ ] Script supports `-WhatIf` and `-Restore` parameters following `Common.ps1` patterns
- [ ] Entry added to `AGENTS.md` or `.kilo/commands/` referencing the new script
**Implementation:**
```powershell
[CmdletBinding(SupportsShouldProcess)]
param([switch]$Restore)
$ErrorActionPreference = 'Stop'
$uri = 'https://raw.githubusercontent.com/ShadowWhisperer/Fix-WinUpdates/main/Fix-WinUpdates.ps1'
$tmp = Join-Path $env:TEMP 'Fix-WinUpdates.ps1'
if ($PSCmdlet.ShouldProcess($uri, 'Download')) {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $uri -OutFile $tmp -UseBasicParsing
    & $tmp
}
```
**Estimated LOC delta:** 30–50 lines.

---

### T003 · Implement winget wait-loop with timeout and scope fix
**File:** `TODO.md:17`
**Severity:** high · **Category:** bug · **Size:** S
**Blocks:** T004  **Blocked by:** —
**Context:**
> from https://schneegans.de/windows/unattend-generator/samples
> ```pwsh
> if( [System.Environment]::OSVersion.Version.Build -lt 26100 ) { ... }
> $timeout = [datetime]::Now.AddMinutes( 5 );
> $exe = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe";
> while( $true ) { ... }
> ```
**Intent:** Replace brittle winget invocations with a robust wait-loop that handles the UWP stub delay on fresh installs.
**Acceptance criteria:**
- [ ] Extract a `Wait-ForWinget` helper into `Scripts/Common.ps1` (or new `Scripts/Helpers/Winget.ps1`)
- [ ] Helper accepts `-TimeoutMinutes [int]` (default 5) and `-ExePath [string]` (default `%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe`)
- [ ] Helper returns the resolved executable path or throws a terminating error on timeout
- [ ] All existing winget calls in `Scripts/Setup-Dotfiles.ps1`, `Scripts/Install-Packages.ps1`, and `Scripts/auto/autounattend.xml` are updated to call the helper first
- [ ] `Install-WingetPackage` in `autounattend.xml` uses `--scope machine` only when admin context is confirmed
**Implementation:**
```powershell
function Wait-ForWinget {
    [CmdletBinding()]
    param(
        [string]$ExePath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
        [int]$TimeoutMinutes = 5
    )
    $deadline = [datetime]::Now.AddMinutes($TimeoutMinutes)
    while (-not (Test-Path $ExePath)) {
        if ([datetime]::Now -gt $deadline) { throw "winget not found within ${TimeoutMinutes}m" }
        Start-Sleep -Seconds 1
    }
    return $ExePath
}
```
**Estimated LOC delta:** 20–40 lines.

---

### T004 · Fix broken autounattend.xml and autounattend-windows10.xml
**File:** `Scripts/auto/autounattend.xml:0`, `Scripts/auto/autounattend-windows10.xml:0`
**Severity:** critical · **Category:** bug · **Size:** L
**Blocks:** —  **Blocked by:** T003
**Context:**
> fix broken autounattend scripts
> - [win11](Scripts/auto/autounattend.xml)
> - [win10](Scripts/auto/autounattend-windows10.xml)
**Intent:** Repair the unattended installation XML files so they produce a working Windows 10/11 setup without manual intervention.
**Acceptance criteria:**
- [ ] Both XML files pass validation: `$xml = [xml]::new(); $xml.Load('Scripts/auto/autounattend.xml')` succeeds without errors
- [ ] Both XML files contain well-formed `ExtractScript` entities and embedded scripts are syntactically valid PowerShell
- [ ] `FirstLogon.ps1` → `install.ps1` → `stage2.ps1` execution chain is intact and file paths match extracted locations (`C:\Windows\Setup\Scripts\`)
- [ ] Winget installation blocks in both XML files use the `Wait-ForWinget` pattern from T003 instead of direct invocation
- [ ] Windows 10 XML does not reference Windows 11-only Appx packages (e.g., `Microsoft.Todos` removal list is version-appropriate)
- [ ] A dry-run parse of both XML files in CI prevents future regressions
**Implementation:**
1. Load each XML with `[xml]::new().Load(path)` and fix any parser errors (encoding, unclosed tags, malformed CDATA).
2. Review `ExtractScript` entities for correct `&#xA;` encoding and valid PowerShell syntax.
3. Replace inline winget calls with `Wait-ForWinget` + `& $exe install ...`.
4. Validate Appx removal lists against known Windows 10/11 package names.
5. Add CI step:
   ```yaml
   - name: Validate autounattend XML
     shell: pwsh
     run: |
       $xml = [xml]::new()
       $xml.Load("$PWD/Scripts/auto/autounattend.xml")
       $xml.Load("$PWD/Scripts/auto/autounattend-windows10.xml")
   ```
**Estimated LOC delta:** 100–250 lines across both XML files plus CI YAML.

---

## Appendix: Severity Legend
| Level | Meaning |
|-------|---------|
| critical | Data loss risk, security hole, crash path, broken public API |
| high | Incorrect behavior, major perf regression, missing error handling |
| medium | Code smell, partial implementation, outdated abstraction |
| low | Docs gap, naming, style, optional improvement |

## Appendix: Size Legend
| Size | LOC Range |
|------|-----------|
| S | < 20 |
| M | 20–100 |
| L | 100–300 |
| XL | 300+ |
