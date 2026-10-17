# Network-Tweaker.ps1

WinForms GUI ("[St1cky] Network Pro - Tweaker v1.0a") for tuning a network adapter: RSS,
global TCP offload settings, advanced adapter properties, power saving, IP interface settings,
AFD registry values and interrupt (MSI mode, affinity) settings. It is a ~4400 line script; this
page covers its structure and safety behavior, not every field.

## Usage

```powershell
.\Scripts\Network-Tweaker.ps1
```

The script has no parameters and opens the form with `ShowDialog()` (it does not run when
dot-sourced). It does not self-elevate and has no `#Requires` or `Request-AdminElevation` call;
registry and adapter changes need an elevated shell in practice, so start it elevated.

Pick the adapter in the combo box at the top. The form then loads current values for that
adapter's registry key and NDIS version.

## Form sections

| Section | Controls | Applied by |
| --- | --- | --- |
| RSS Settings | Enable/disable RSS, queue count, profile, base/max processor, max processors, "Unlock RSSQueues" | `Apply` (`Set-NetAdapterRss`, `Enable/Disable-NetAdapterRss -NoRestart`) |
| Global Settings | ReceiveSideScaling, ReceiveSegmentCoalescing, Chimney, TaskOffload, NetworkDirect, NetworkDirectAcrossIPSubnets, PacketCoalescingFilter | `applyglobal` |
| Adv. Adapter | FlowControl, checksum offloads, LSO v1/v2, interrupt moderation and rate, PM ARP/NS offload, PriorityVLANTag, receive/transmit buffers | `applyadvsettings` |
| RSS Global | `RssBaseCpu` for TCP/IP and NDIS | Written as soon as the text changes |
| PowerSaving Settings | APM sleep states, dynamic and connected power gating, auto power save | `applypowersavingsettings` |
| IP interface | IPv4/IPv6 interface properties (enabled via the IPv4/IPv6 checkboxes) | `ApplyInterfaceSettings` |
| AFD registry | `DefaultReceiveWindow`, `DefaultSendWindow`, `DisableAddressSharing`, `BufferMultiplier` under `HKLM\System\CurrentControlSet\Services\AFD\Parameters` | `RegistryTweaks` |
| Interrupt | MSI mode (`MSISupported`), `DevicePriority`, `DevicePolicy` for the adapter's PnP device | `HWSettings` |

Other buttons: Restart Adapter (`Restart-NetAdapter`), Open (opens Regedit at the adapter key or
the AFD key by setting `LastKey`), window opacity toggle, and "Apply all", which runs the global,
RSS, power saving, IP interface (only if an IP version is selected) and advanced groups in order.

## How it works

- **Restore point.** `Invoke-NetworkTweakRestorePoint` creates one restore point per session
  ("Network-Tweaker - <date time>"), guarded by `$Script:RestorePointCreated`. It is called
  only from the two RSS base CPU text handlers, `applyadvsettings`, `bypassrssqueues` and
  `RegistryTweaks`, never at load. Other handlers (`applyglobal`, `applyrsssettings`,
  `applypowersavingsettings`, `ApplyInterfaceSettings`, `HWSettings`) do not call it directly,
  so a session that only uses those makes no restore point.
- **Registry helper.** Many writes use `Set-RegistryValue` from `Common.ps1`; others use
  `New-ItemProperty` directly.
- **AFD toggle behavior.** In `RegistryTweaks`, if an AFD value already exists the apply
  button removes it instead of setting it (the log says "Removing ..."). If it does not exist
  and the field has text, it is created.
- **"Skip" choices.** Several RSS combo boxes have a third "skip" index that leaves the setting
  unchanged.

## Limitations

- No `-WhatIf`, no dry run, and no built-in undo beyond removing AFD values and re-setting
  fields by hand. Use the restore point.
- Some labels and dropdown text are in German ("Paketpriorität") and one combo item
  duplicates "5000" for Medium and High.
- Code for locating the adapter, PnP device and registry key is outside the parts checked for
  this page; behavior on adapters without RSS or `*NumRssQueues` support was not verified.
