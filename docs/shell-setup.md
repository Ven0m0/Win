# shell-setup.ps1

Bootstraps a personal PowerShell and tooling environment: Scoop, Chocolatey, WinGet, OpenSSH,
Git, aria2, Scoop buckets, a large set of Scoop/WinGet/Chocolatey packages, custom downloads into
`%USERPROFILE%\bin`, clink, the dotposh profile and PowerShell 7. It elevates individual steps
through UAC rather than requiring an elevated session.

**Deprecated package lists.** The inline WinGet, Scoop and Choco arrays duplicate and drift from
the canonical catalog in `Scripts\packages.psd1`. Use `Scripts\Install-Packages.ps1` for package
installs. `Setup-Win11.ps1` still references this script only as a winget-bootstrap fallback, and
the bulk install is slated for removal (per the script header).

## Usage

```powershell
.\Scripts\shell-setup.ps1
.\Scripts\shell-setup.ps1 -HomeWorkstation
```

Without `-HomeWorkstation` the script asks "Is this a workstation for Home use (y/n)?".

## Parameters

| Parameter | Default | Notes |
| --- | --- | --- |
| `-HomeWorkstation` | prompt | Adds media/emulation/gaming packages, Steam app launches and extra custom downloads |

No `-WhatIf`, `-Restore` or restore-point support. `Start-MainFunction` declares
`SupportsShouldProcess` but the script's own `param()` does not expose it.

## How it works

1. **Execution policy.** If the CurrentUser policy is not `RemoteSigned`, sets it via an
   elevated PowerShell, prints "Restart/Re-Run script required.", waits 10 s and returns. Run
   the script again afterward.
2. **Installers.** Scoop, Chocolatey and WinGet (App Installer) are installed when missing,
   using temporary scripts under `%TEMP%` that are deleted afterward. OpenSSH Client is added
   as a Windows capability.
3. **Git.** Installs `Git.Git` with `Invoke-Winget`, sets `credential.helper` to `manager-core`,
   sets the `GIT_SSH` user variable from `scoop which ssh`, and makes `ssh-agent` Manual.
4. **aria2.** Installs via Scoop, enables it in Scoop config, and registers an `Aria2RPC` startup
   scheduled task (elevated).
5. **Buckets and packages.** Adds `extras`, `nerd-fonts`, `java`, `nirsoft` and `foosel` buckets;
   installs the package arrays; installs VSCodium with a custom `--override`; creates symlinks
   for `busybox` and `tdmgr` with `sudo`.
6. **Custom apps.** Downloads with `aria2c`, extracts with `7z` (or WinRAR `UnRar.exe` for
   `.rar`) into `%USERPROFILE%\bin\<Folder>`, then deletes the download. Installers run
   elevated with `/S`.
7. **Environment.** Creates `%USERPROFILE%\go` and `GOPATH`, sets `TERM`, installs the clink
   autorun, imports the `solarized-dark` concfg theme, and adds a `scoop-tray` startup shortcut.
8. **Dotfiles and PowerShell 7.** Clones `mikepruett3/dotposh` to `%USERPROFILE%\dotposh`,
   symlinks its `profile.ps1` as the Windows PowerShell profile (replacing an existing one), and
   installs PowerShell 7 if `winget list` does not find it.

## Limitations

- Many steps use fixed, old download URLs and pinned versions (for example Go 1.19, Python 3.11,
  .NET 3.1/5/6/7 runtimes). Some links may be dead.
- Taskbar pinning uses `syspin` with command `c:5386`. Symlink steps need `sudo`.
- Steps are mostly not idempotent beyond "already installed" checks; re-running re-downloads
  custom apps and can overwrite files in `%USERPROFILE%\bin`.
- Several steps replace existing files or profiles, and a stage failure stops the run
  (`$ErrorActionPreference = 'Stop'`).
- Not verified by execution; behavior was read from the code only.
