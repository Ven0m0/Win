# TODO.md - Ven0m0/Win

## Pending

### Reference-Repo Evaluation — Completed 2026-07-06

Evaluated all five repos per `PLAN.md`; findings gate approved via `AskUserQuestion`, adopted items implemented on
`feature/reference-repo-eval-adoptions`. Full findings tables are in the session transcript. Summary:

- **chawyehsu/dotfiles**: adopted telemetry env vars (`profile.ps1`), `.wslconfig` `defaultVhdSize`, scoop
  `use_isolated_path`. Bootstrap/manifest/symlink patterns and file-layout reorg skipped — already covered or a
  worse fit than the existing hash-copy deploy.
- **WinRice**: adopted WPAD disable, LLMNR disable, WDigest hardening, Reserved Storage disable,
  powerdown-after-shutdown, NumLock-on-startup, Autorun disable, Edge Copilot sidebar disable, AI-in-Photos disable,
  AI-in-Notepad HKCU key (`system-settings-manager.ps1` + `RegistryTweaks11.reg`). Skipped PrintScreen->Snipping
  Tool, SHA256 hash context-menu, SEHOP, IFEO LSA audit level, Office OLE, WSH disable (low-value/narrow/out of
  scope).
- **after-format**: adopted OneDrive full sync disable, SmartScreen disable, Location/Sensors disable, WiFi Sense
  disable, Delivery Optimization disable, clipboard history disable, diagnostic log limits, password-reveal
  disable, background-app restriction (`debloat-windows.ps1` Phase 5); Win11 sudo enable, Recall feature disable,
  UEFI-firmware context menu (`system-settings-manager.ps1`, `debloat-windows.ps1`, new `.reg` pair). Skipped
  Defender/System-Restore/UAC disables and MachineGuid rewrite (security regressions / out of scope).
- **Windows-Repair-Tool**: `fix-system.ps1` was already a superset (CHKDSK/WMI/network breadth, dry-run,
  restore-point support). Adopted TrustedInstaller service start, stopping msiserver/appidsvc, re-registering
  urlmon.dll/mshtml.dll, and a new `-Action DriverCleanup` (pnpclean.dll). Also fixed a pre-existing inconsistency
  where the WindowsUpdate path deleted `SoftwareDistribution`/`catroot2` while System renamed them — both now rename.
- **win-config**: mostly a documentation/reference wiki, not a tweak repo. Adopted SMB1 disable, SMB signing
  enforcement (`system-settings-manager.ps1` Security Hardening), plus opt-in SMB AES-256 cipher preference and
  admin-share disable (off by default), and two small QoL registry values (`CursorDeadzoneJumpingSetting`,
  `MouseWheelRouting`). Everything else was internals documentation (WinDbg, USB VID/PID hack flags, NVIDIA private
  API hex values) not meant to be ported as scripts.

### Feature Ideas
- [ ] `Watch-GpuMetrics` helper in `Common.ps1` — real-time nvidia-smi/WMI GPU dashboard
- [ ] `Start-OptimizedGame.ps1` — generalize `start-arc-raiders.ps1` launch patterns for any game
- [ ] `Test-SystemHealth` command — proactive health checks (disk, updates, services, temp dirs, startup)
