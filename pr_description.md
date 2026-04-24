🧹 Replace Get-WmiObject with Get-CimInstance

🎯 **What:**
Replaced all occurrences of `Get-WmiObject` with `Get-CimInstance` across the codebase, including `Scripts/Common.ps1`, `Scripts/Network-Tweaker.ps1`, `Scripts/arc-raiders/ARCRaidersUtility.ps1`, and `user/.dotfiles/config/nvidia/NvidiaAutoinstall.ps1`.

💡 **Why:**
`Get-WmiObject` is deprecated and has been superseded by `Get-CimInstance` in newer versions of PowerShell (PowerShell Core / 7+). `Get-CimInstance` offers better performance and cross-platform compatibility by communicating over WS-Man or DCOM, while `Get-WmiObject` is strictly bound to Windows DCOM and is no longer being actively maintained. This change improves script robustness and future-proofs the codebase.

✅ **Verification:**
- Ran `pwsh -c "Invoke-ScriptAnalyzer"` against all modified files to ensure no syntax or formatting issues were introduced.
- Ran the test suite via `pwsh -c "Invoke-Pester"` to guarantee no new regressions occurred.
- Ensured file encodings (UTF-8 with BOM) and line endings (CRLF) were strictly preserved to prevent unintended formatting changes.

✨ **Result:**
The codebase now exclusively uses `Get-CimInstance` for WMI queries, bringing it inline with modern PowerShell best practices and ensuring better compatibility across different environments.
