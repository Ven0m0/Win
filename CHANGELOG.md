# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Common.ps1: added `[CmdletBinding()]` to all 49 functions that lacked it
- RegistryTweaks10.reg: UAC-disabling keys (EnableLUA=0) commented out; must be explicitly uncommented to apply
- Global `$ErrorActionPreference` changed from `'Continue'` to `'Stop'` in 3 scripts (ARCRaidersUtility, Network-Tweaker, UltimateDiskCleanup)
- Deploy-Config.ps1: removed duplicate header; added relationship note to canonical Setup-Dotfiles.ps1

### Fixed
- CI summary job now includes `deploy-dry-run` result
- CI triggers now include `install.conf.yaml` changes

## [1.0.0] - 2025-??-??

### Added
- Initial Windows dotfiles suite with hash-based deployment, registry tweaks, and gaming optimization
- PowerShell bootstrap chain: `bootstrap.ps1` -> `install.conf.yaml` -> `Setup-Dotfiles.ps1`
- Arc Raiders game utility suite (`ARCRaidersUtility`, `game-boost`, `cleanup`, `start`, `SkipVideosMod`)
- Unattended Windows 11/10 USB installer (`autounattend.xml`)
