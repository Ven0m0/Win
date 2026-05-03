# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Security
- Added explicit warning header to `RegistryTweaks10.reg` noting UAC disablement (`EnableLUA=0`) significantly reduces security
- Replaced `Invoke-Expression` (`iex`) in `autounattend.xml` with `-File` execution for safer WinUtil launch

### Fixed
- Removed global `$ErrorActionPreference = 'SilentlyContinue'` from `ARCRaidersUtility.ps1`, `UltimateDiskCleanup.ps1`, and `Network-Tweaker.ps1`
- Replaced 19 silent empty `catch {}` blocks with `Write-Verbose`/`Write-Warning` diagnostics across 6 files
- Propagated `-WhatIf` / `-Confirm` in elevation relaunch for `Setup-Dotfiles.ps1`, `Setup-Win11.ps1`, `Install-Packages.ps1`, `gpu-display-manager.ps1`, and `game-boost.ps1`

### Added
- Centralized Arc Raiders shared helpers in `Scripts/arc-raiders/ArcRaidersCommon.ps1`
- Added smoke tests for previously uncovered scripts:
  - `tests/Fix-WindowsUpdates.Tests.ps1`
  - `tests/ARCRaidersUtility.Tests.ps1`
  - `tests/cleanup-arc-raiders.Tests.ps1`
  - `tests/game-boost.Tests.ps1`
  - `tests/SkipVideosMod.Tests.ps1`
  - `tests/start-arc-raiders.Tests.ps1`
- Added `deploy-dry-run` CI job to run `Setup-Dotfiles.ps1 -WhatIf` on every PR
- Added `[CmdletBinding()]` to `vdf_mkdir` and `sc-nonew` in `Common.ps1`
- Enabled `PSAvoidUsingEmptyCatchBlock` in `PSScriptAnalyzerSettings.psd1`

### CI/CD
- New `deploy-dry-run` job in `lint-format-test.yml` validates dotbot config integrity on pull requests

## [1.0.0] - 2025-??-??

### Added
- Initial Windows dotfiles suite with hash-based deployment, registry tweaks, and gaming optimization
- PowerShell bootstrap chain: `bootstrap.ps1` -> `install.conf.yaml` -> `Setup-Dotfiles.ps1`
- Arc Raiders game utility suite (`ARCRaidersUtility`, `game-boost`, `cleanup`, `start`, `SkipVideosMod`)
- Unattended Windows 11/10 USB installer (`autounattend.xml`)
