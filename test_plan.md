The PowerShell format CI check is still failing. Let's run it again to see what lines exceed the 120 character limit.

From the previous output:
## Formatting Issues Found
[tests/Common.Tests.ps1]:178: Line exceeds 120 characters (127)
[tests/Common.Tests.ps1]:214: Line exceeds 120 characters (130)

We missed some lines, let's fix them in `tests/Common.Tests.ps1`.
