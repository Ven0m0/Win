---
name: win-patterns
description: Repo-specific workflow guide for Win. Use when editing PowerShell scripts, tracked config, bootstrap logic, or Copilot guidance.
allowed-tools: 'Read, Glob, Grep, Bash'
---

# Win repository patterns

Load this skill when the task touches repository conventions or spans multiple repo areas.

## Hotspots

- `Scripts/` for PowerShell automation
- `Scripts/Common.ps1` for shared helpers
- `Scripts/auto/autounattend.xml` for unattended Windows 11 USB install
- `user/.dotfiles/config/` for tracked config and game assets
- `install.conf.yaml` (dotbot) and `Scripts/Setup-Dotfiles.ps1` for bootstrap behavior
- `.github/` for Copilot guidance and workflow metadata

## Common workflows

### PowerShell script changes

- Open the target script and `Scripts/Common.ps1` together.
- Preserve the existing admin elevation, strict mode, and environment-based path patterns.
- Prefer shared helpers over new one-off functions.
- Run `Invoke-ScriptAnalyzer -Path <changed-script>` after edits.

### Bootstrap changes

Review these files together:

- `install.conf.yaml` (dotbot config)
- `Scripts/Setup-Dotfiles.ps1`
- `README.md`
- `AGENTS.md`

### Tracked config changes

- Keep new tracked config in `user/.dotfiles/config/`.
- Preserve the target application's native file format.
- If a script deploys the config, verify the deployment logic still points at the right source file.

### Guidance changes

- Keep `.github/copilot-instructions.md` short.
- Put broad repo rules in `AGENTS.md`.
- Put narrow rules in `.github/instructions/`.
- Put recurring workflows in `.github/skills/`.
- Run `npx -y @yawlabs/ctxlint --depth 3 --mcp --strict --yes` after guidance edits.

## autounattend.xml (Scripts/auto/)

`Scripts/auto/autounattend.xml` is **fully self-contained**. The `ExtractScript` mechanism (inside the `<Extensions>` block) extracts every embedded `<File path="...">` entry to `C:\Windows\Setup\Scripts\` during the specialize pass. No `$OEM$` folder is required.

- **USB deploy**: copy only `autounattend.xml` to the USB root — Windows Setup picks it up automatically.
- **Do not** add flat companion scripts alongside the XML; they become stale duplicates of what is embedded.
- **XML entity encoding**: content inside `<File>` blocks uses `&amp;` for `&`, `&gt;` for `>`, etc. `ExtractScript` uses `.InnerText` which XML-unescapes them, so the extracted `.ps1` files have correct PowerShell syntax.
- **Execution flow**: specialize → FirstLogon → `install.ps1` (winget, Windows Update, reboot) → `stage2.ps1` (WSL) → WinUtil RunOnce.
- **Validate XML** after any edit: `$xml = [xml]::new(); $xml.Load($path)`.

### WinUtil Win11 Creator compatibility

Place `autounattend.xml` at the USB root created by any tool (WinUtil, Rufus, Ventoy). The XML's `stage2.ps1` sets a `HKCU\RunOnce` entry so WinUtil (`christitus.com/win`) opens on the logon after WSL setup — matching the WinUtil Win11 Creator post-install flow.

## Validation reminders

- Current CI runs PSScriptAnalyzer from `.github/workflows/powershell.yml`.
- CI currently enforces `PSAvoidGlobalAliases` and `PSAvoidUsingConvertToSecureStringWithPlainText`.
- The repo does not currently ship a committed Pester suite, so add tests only when the change justifies them.
- After editing `Scripts/auto/autounattend.xml`, validate with: `$xml = [xml]::new(); $xml.Load($path)`
