1. **Understand Task**: User wants to add tests for `Invoke-ServiceOperation` in `tests/Common.Tests.ps1` and also ensures the github actions workflows simply use `windows-latest` when running tests.
2. **Current state**:
   - Wrote tests for `Invoke-ServiceOperation` covering all conditions (service not found, not running, running, restart false, restart with exception).
   - Mocked compiled Windows cmdlets so they work locally and don't interfere with real services. Used `$global:` variables inside scriptblocks since standard mocking scopes evaluate expressions globally.
   - Updated `.github/workflows/lint-format-test.yml` and `.github/workflows/powershell.yml` to use `windows-latest` instead of `ubuntu-latest`.
   - Fixed pre-existing formatting and test execution issues on Linux caused by bad string termination parsing (`ConvertTo-VDF edge cases`).
3. **Execution**:
   - Run Pre-commit checks.
   - Wait for pre-commit instructions, run those.
   - Use submit tool.
