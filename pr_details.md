Title: 🧪 Add tests for Invoke-ServiceOperation

Description:
🎯 **What:** The testing gap addressed in `Invoke-ServiceOperation` within `Scripts/Common.ps1` by adding Pester 5 tests and transitioning the Github Actions CI jobs for formatting and linting to `windows-latest` as requested. Also fixed formatting bugs and empty parameter blocks detected by PSScriptAnalyzer.
📊 **Coverage:** Scenarios covered: Missing service, stopped service, normal start/stop sequence, skip restart parameter (`-Restart $false`), and handling exception errors in the provided scriptblock.
✨ **Result:** Improved test coverage and reliability for core service manipulation operations with safe dummy implementations of native Windows service cmdlets.
