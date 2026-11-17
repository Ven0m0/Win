---
name: windows-update
description: >
  Scan for and install Windows updates with the PSWindowsUpdate module, handling the unelevated shell
  (UAC via Start-Process -Verb RunAs) and the unelevated scan undercount. Use when asked to check, run,
  install or verify Windows updates, or to audit update policy on this machine.
disable-model-invocation: true
allowed-tools: Read Bash PowerShell
metadata:
  version: "1.0.0"
  category: "domain"
  updated: "2026-11-14"
---

# Windows Update via PSWindowsUpdate

PSWindowsUpdate 2.2.1.5 is installed per-user (`~\Documents\PowerShell\Modules\PSWindowsUpdate`).
The Claude shell is not elevated, so installing needs a UAC prompt the user must accept.

Request: $ARGUMENTS (default: scan, then ask before installing)

## 1. Scan (works unelevated)

```powershell
Import-Module PSWindowsUpdate
Get-WindowsUpdate -Verbose 4>&1 | Out-String
```

Capture with `Out-String`; piping to `Select-Object` or `Format-Table` printed nothing here.
An unelevated scan can undercount (2026-11-10: it showed 2 updates, the elevated install found 3, the
extra one was a Defender definitions update). Treat the scan as a lower bound.

## 2. Install (needs UAC, ask the user first)

Tell the user a UAC prompt is coming, then:

```powershell
$log = "$env:TEMP\wu-install.log"
Start-Process pwsh -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList '-NoProfile','-Command',
  "Import-Module PSWindowsUpdate; Install-WindowsUpdate -AcceptAll -IgnoreReboot *>&1 | Out-File '$log'"
Get-Content $log
```

Never add `-AutoReboot`. Leave the reboot to the user.

## 3. Verify

```powershell
Get-WURebootStatus -Silent
Get-WindowsUpdate | Out-String
```

Report reboot-needed and what is still pending. Do not claim success without the second scan.

## Gotchas

- Large registry or policy dumps get swallowed by context-mode compression. Write the result to a file
  in the scratchpad and Read it.
- Policy audit baseline (2026-11-10, 25H2 build 26200.9711): no Windows Update policy, default service
  is Windows Update (not WSUS). `DontOfferThroughWUAU=1` under `HKLM\SOFTWARE\Policies\Microsoft\MRT`
  is a deliberate user tweak that blocks the monthly MRT. Do not remove it unprompted.
- Leftover `DeferQualityUpdates` / `DeferFeatureUpdates` = 1 flags in
  `HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings` have no deferral-day values (0 days in effect).
- Updates broken: `sfc /scannow`, then `DISM /Online /Cleanup-Image /RestoreHealth`, before anything
  heavier. Avoid reset batch files such as Fix-WinUpdates: they delete SoftwareDistribution/catroot2,
  force a reboot, and add `AllowOptionalContent=0` policy values that mark the PC "managed by organization".
