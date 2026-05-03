# Implementation Plan
_Generated: 2026-05-03T09:00:00Z · 6 tasks · Est. M–XL_

## Summary
This plan synthesizes six pending work items from `TODO.md`, covering CI toolchain modernization (mise GitHub Action integration), security hardening (Code Scanning findings), game network QoS tuning, dotbot plugin ecosystem expansion, and PowerShell YAML module support. Task ordering respects the dependency that mise CI integration must precede its use in the setup-pwsh action.

## Task Index (topological order)

| # | ID | Title | Sev | Cat | Size | Blocks |
|---|-----|-------|-----|-----|------|--------|
| 1 | T001 | Integrate mise GitHub Action into CI workflows | medium | feature | M | T003 |
| 2 | T002 | Resolve all GitHub Code Scanning security findings | high | security | L | — |
| 3 | T003 | Migrate setup-pwsh action to use mise toolchain | medium | refactor | S | — |
| 4 | T004 | Add QoS 46 priority entries for Arc Raiders, BO6, and Fortnite | low | feature | S | — |
| 5 | T005 | Extend dotbot via plugin submodules and config | medium | feature | M | — |
| 6 | T006 | Install PowerShell YAML module for config handling | low | feature | S | — |

## Tasks

### T001 · Integrate mise GitHub Action into CI workflows

**File:** `.github/workflows/powershell.yml:68`, `.github/workflows/lint.yml` (new insertion point immediately after `actions/checkout`), `.github/workflows/lint-format-test.yml` (new insertion point immediately after `actions/checkout`)
**Severity:** medium · **Category:** feature · **Size:** M
**Blocks:** T003  **Blocked by:** —
**Context:**
> implement [mise action](https://github.com/jdx/mise-action) `jdx/mise-action@v4` in [workflows](.github/workflows/)
**Intent:** Replace ad-hoc tool installation in GitHub Actions with the mise action to ensure consistent, cacheable tool versions across CI.
**Acceptance criteria:**
- [ ] Add a `jdx/mise-action@v4` step to workflows `powershell.yml`, `lint.yml`, and `lint-format-test.yml` immediately after checkout
- [ ] The action installs toolchains defined in `mise.toml` automatically
- [ ] Remove explicit `pip install py-psscriptanalyzer` lines (now redundant)
- [ ] CI runs successfully with tools available on PATH
**Implementation:**
Insert into each workflow:
```yaml
- name: Set up mise
  uses: jdx/mise-action@v4
  with:
    cache: true
```
Remove the dedicated "Install py-psscriptanalyzer" step in `powershell.yml` (line~68–69). The action will run `mise install` under the hood.
**Estimated LOC delta:** +12 lines (4 per workflow) –20 lines removed (redundant install steps) → net ~ –8

### T002 · Resolve all GitHub Code Scanning security findings

**File:** `TODO.md:5` (source), code changes across repository
**Severity:** high · **Category:** security · **Size:** L
**Blocks:** —  **Blocked by:** —
**Context:**
> fix all findings/errors under "https://github.com/Ven0m0/Win/security/code-scanning"
**Intent:** Close every open Code Scanning (CodeQL, secret scanning, dependency review) alert to improve the project's security posture.
**Acceptance criteria:**
- [ ] All alerts listed under Security → Code scanning on GitHub are marked "Closed" (fixed or dismissed with justification)
- [ ] No new "Critical" or "High" alerts appear within 7 days of merge
- [ ] CI includes at least one secret-scanning step (gitleaks or GitHub native) as a preventative barrier
**Implementation:**
Use the Security alerts UI to identify each alert's type and location:
- CodeQL: Apply the suggested fix pattern; e.g., replace `Invoke-Expression` with safe alternatives, add input validation.
- Secrets: Rotate the exposed credential immediately, purge from history (BFG or filter-branch), and add pre-commit gitleaks hook.
- Dependency review: Raise vulnerable dependencies in `mise.toml` to patched versions.
Commit changes referencing the alert numbers (e.g., "Fix CodeQL #123: parameterized command").
**Estimated LOC delta:** 100–250 lines depending on findings

### T003 · Migrate setup-pwsh action to use mise toolchain

**File:** `.github/actions/setup-pwsh/action.yml:1`
**Severity:** medium · **Category:** refactor · **Size:** S
**Blocks:** —  **Blocked by:** T001
**Context:**
> use mise for `.github/actions/setup-pwsh/action.yml`
**Intent:** Simplify the custom setup-pwsh composite action by delegating tool installation to mise, reducing maintenance and ensuring version consistency.
**Acceptance criteria:**
- [ ] `action.yml` no longer contains distro-specific apt/yum/rpm install blocks for PowerShell
- [ ] The composite action runs `mise install` (or relies on top-level `jdx/mise-action`) and then executes PowerShell via `mise exec`
- [ ] Action still installs the requested PowerShell version (honors `inputs.version`) via mise tool version resolution
- [ ] Action runs faster due to mise caching and avoids redundant package manager calls
**Implementation:**
Replace lines 14–58 with a single step that leverages mise:
```yaml
- name: Set up PowerShell via mise
  shell: bash
  run: |
    # mise is already installed by jdx/mise-action at the workflow level
    mise use powershell@${{ inputs.version }}
    # Expose pwsh on PATH for subsequent steps; mise exec handles this
```
For Windows runners, ensure the top-level workflow has already installed mise (T001). The action becomes a thin wrapper around `mise exec`.
**Estimated LOC delta:** –30 lines (net removal)

### T004 · Add QoS 46 priority entries for Arc Raiders, BO6, and Fortnite

**File:** `Scripts/reg/priority.reg:35` (append at EOF)
**Severity:** low · **Category:** feature · **Size:** S
**Blocks:** —  **Blocked by:** —
**Context:**
> add Qos 46 to `Scripts/reg/priority.reg` for arc raiders, bo6 and fortnite
**Intent:** Assign DSCP value 46 (Expedited Forwarding) to network traffic from these competitive games to prioritize game packets and reduce latency.
**Acceptance criteria:**
- [ ] `priority.reg` contains three new `[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\QoS\<GameName>]` sections, one per game
- [ ] Each section sets `"Name"` to the game's `.exe` filename and `"DscpValue"=dword:0000002e` (46 decimal)
- [ ] File passes `regedit /s priority.reg` test import without errors
- [ ] Comment above each section documents the game and rationale
**Implementation:**
Append to `Scripts/reg/priority.reg`:
```registry
; === QoS for competitive games: DSCP 46 (Expedited Forwarding) ===
[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\QoS\ArcRaiders]
"Name"="PioneerGame.exe"
"DscpValue"=dword:0000002e

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\QoS\BlackOps6]
"Name"="cod24-cod.exe"
"DscpValue"=dword:0000002e

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\QoS\Fortnite]
"Name"="FortniteClient-Win64-Shipping.exe"
"DscpValue"=dword:0000002e
```
Deploy with `reg import Scripts/reg/priority.reg`. Verify under `HKLM\SOFTWARE\Policies\Microsoft\Windows\QoS\`.
**Estimated LOC delta:** +18 lines

### T005 · Extend dotbot via plugin submodules and config

**File:** `install.conf.yaml:57` (append), `.gitmodules` (new)
**Severity:** medium · **Category:** feature · **Size:** M
**Blocks:** —  **Blocked by:** —
**Context:**
> extend dotbot via its [plugins](https://github.com/anishathalye/dotbot/wiki/Plugins)
> ```bash
> git submodule add https://github.com/fundor333/dotbot-gh-extension.git
> git submodule add https://github.com/kurtmckee/dotbot-firefox.git
> git submodule update --init dotbot-firefox
> git submodule add https://github.com/alexcormier/dotbot-rust.git
> git submodule add https://github.com/JamJar00/dotbot-scoop.git
> git submodule add https://github.com/kurtmckee/dotbot-windows.git
> git submodule update --init dotbot-windows
> git submodule add https://github.com/zknx/dotbot-winget
> ```
**Intent:** Bring in third-party dotbot plugins as git submodules to enable new configuration targets (Firefox, Windows settings, Rust tools, Scoop, winget) without vendoring code.
**Acceptance criteria:**
- [ ] Run all `git submodule add` commands listed, creating entries in `.gitmodules` and submodule directories
- [ ] Execute `git submodule update --init --recursive` to clone submodule contents
- [ ] Modify `install.conf.yaml` to include `- plugin:` blocks for each plugin that will be immediately used (at least `dotbot-firefox` and `dotbot-windows` as examples)
- [ ] CI runs `dotbot -c install.conf.yaml` without plugin resolution errors
**Implementation:**
1. Add submodules from repo root:
```bash
git submodule add https://github.com/fundor333/dotbot-gh-extension.git dotbot-plugins/gh-extension
git submodule add https://github.com/kurtmckee/dotbot-firefox.git dotbot-plugins/firefox
git submodule add https://github.com/alexcormier/dotbot-rust.git dotbot-plugins/rust
git submodule add https://github.com/JamJar00/dotbot-scoop.git dotbot-plugins/scoop
git submodule add https://github.com/kurtmckee/dotbot-windows.git dotbot-plugins/windows
git submodule add https://github.com/zknx/dotbot-winget.git dotbot-plugins/winget
git submodule update --init --recursive
```
2. Append to `install.conf.yaml` (after line 57):
```yaml
- plugin: dotbot-firefox
  source: dotbot-plugins/firefox
- plugin: dotbot-windows
  source: dotbot-plugins/windows
```
Add more plugins as configuration needs arise. Keep plugin order independent.
**Estimated LOC delta:** +40 lines (6 submodule entries + 2–4 plugin config blocks)

### T006 · Install PowerShell YAML module for config handling

**File:** `mise.toml:33` (add to tools)
**Severity:** low · **Category:** feature · **Size:** S
**Blocks:** —  **Blocked by:** —
**Context:**
> add [powershell yaml](https://github.com/cloudbase/powershell-yaml) support via `Install-Module powershell-yaml`
**Intent:** Provide native PowerShell YAML parsing capabilities across scripts by installing the `powershell-yaml` module from PSGallery.
**Acceptance criteria:**
- [ ] `mise.toml` `[tools]` section includes a new tool entry `"pipx:powershell-yaml" = "latest"`
- [ ] `mise install` fetches and installs the module in the mise-managed environment
- [ ] Any script needing YAML can `Import-Module powershell-yaml` without errors
- [ ] Optional: add a fallback install to `Scripts/Setup-Dotfiles.ps1` in case mise is absent
**Implementation:**
Add to `mise.toml` after line 33:
```toml
"pipx:powershell-yaml" = "latest"
```
Optionally in `Scripts/Setup-Dotfiles.ps1` add:
```powershell
if (-not (Get-Module -ListAvailable powershell-yaml)) {
    Install-Module -Name powershell-yaml -Scope CurrentUser -Force
}
```
Prefer mise-managed installation to keep tooling consistent.
**Estimated LOC delta:** +2 lines (mise.toml)

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
