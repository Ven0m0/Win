---
applyTo: "**/*.Tests.ps1"
---

# PowerShell Pester v5 Guidelines for Win

Use these rules when adding or updating PowerShell tests in this repository.

## Repository expectations

- The repository currently has no committed Pester test suite.
- Add tests only when the affected area already has tests or when the change introduces reusable logic that benefits from coverage.
- Keep tests narrow, readable, and safe on non-Windows CI runners.

## Placement and naming

- Name test files `*.Tests.ps1`.
- Place tests next to the script they cover inside `Scripts/` unless there is a strong reason to group them elsewhere.
- Dot-source the target script in `BeforeAll`.

## Test design

- Keep all test code inside `Describe`, `Context`, and `It` blocks.
- Use the Arrange, Act, Assert pattern.
- Mock external commands, registry calls, and destructive system operations.
- Prefer testing pure helper functions and decision logic over interactive menus or machine-specific side effects.
- Use descriptive test names that explain the behavior under test.

## Validation

- Run `Invoke-Pester -Path Scripts/ -Output Minimal` when tests exist for the changed area.
- If the change is documentation-only or the repo area has no tests, call that out instead of inventing coverage.
