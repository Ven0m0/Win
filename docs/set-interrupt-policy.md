# set-interrupt-policy.ps1

Sets the per-device interrupt affinity policy (`DevicePolicy` under `Enum\<PnP id>\Device Parameters\Interrupt Management\Affinity Policy`) for present PCI devices. Closes the policy table in issue #107.

| Device class | Policy |
| --- | --- |
| Display (GPU) | `5` SpreadMessagesAcrossAllProcessors |
| Network adapter | `5` SpreadMessagesAcrossAllProcessors |
| NVMe controller | `1` AllCloseProcessors |
| USB host controller | `1` AllCloseProcessors |

## Usage

```powershell
.\Scripts\set-interrupt-policy.ps1             # preview, changes nothing
.\Scripts\set-interrupt-policy.ps1 -Apply      # elevated: restore point, backup, then write
.\Scripts\set-interrupt-policy.ps1 -Restore    # elevated: put the saved values back
```

`-Apply` saves each device's previous value to `-BackupPath` (default `%USERPROFILE%\interrupt-policy-backup.json`) before writing. `-Restore` rewrites those values and deletes the value for devices that had none. Reboot for either to take effect. `-NoRestorePoint` skips the restore point.

## Limits

- No MSI-X detection: a NIC without MSI-X gets Spread too, which the issue says helps only with MSI-X.
- Only the four classes above; other devices are untouched.
- Running `-Apply` twice overwrites the backup with the already-changed values; `-Restore` then restores those, not the originals. Restore before re-applying.
