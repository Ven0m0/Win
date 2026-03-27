---
description: Audit registry changes in a script or .reg file for correctness and reversibility
agent: code
---

Audit the registry operations in: `$ARGUMENTS`

@$ARGUMENTS

For each registry key/value operation, verify:

1. **Path correctness**
   - Confirm `HKLM` vs `HKCU` is appropriate (system-wide vs per-user)
   - Flag any path that targets an undocumented or unofficial key

2. **Value type accuracy**
   - `REG_DWORD` must be a 32-bit integer (0–0xFFFFFFFF)
   - `REG_SZ` must be a plain string; use `REG_EXPAND_SZ` for paths with `%ENV%` vars
   - `REG_BINARY` values must be valid hex pairs

3. **Reversibility**
   - Every SET must have a corresponding documented restore value
   - Scripts must include a "Restore defaults" menu option

4. **Safety**
   - Flag any write to `HKLM\SYSTEM\CurrentControlSet\Services` — requires reboot and can brick the system
   - Flag any delete of a key rather than just a value

5. **Common.ps1 compliance**
   - All writes must use `Set-RegistryValue`, not raw `New-Item`/`Set-ItemProperty`
   - All deletes must use `Remove-RegistryValue`

Output: table of key | operation | verdict (OK / WARNING / ERROR) | reason.
