---
applyTo: "**/*.ahk"
---

# AutoHotkey v2 Guidelines

<Goals>
- Target AutoHotkey v2 only
- Keep new scripts minimal and clearly scoped
- Prefer repo-relative paths built from `A_ScriptDir`
- Avoid introducing shared helpers until there is a second real use
</Goals>

<Standards>
**Repository status**: The repo currently has no tracked `.ahk` files, so any new AutoHotkey addition should stay small and self-contained.

**Directives**: `#Requires AutoHotkey v2.0`, `#SingleInstance Force`, `SendMode "Input"`, `SetWorkingDir A_ScriptDir`

**Paths**: Use `A_ScriptDir` and repo-relative paths. Do not hardcode drive letters or machine-specific locations.

**Naming**: Functions in `PascalCase()`, locals in `camelCase`, constants in `UPPER_SNAKE_CASE`.

**Errors**: Wrap risky operations in `try` and `catch as e`, then surface actionable errors with `MsgBox()` or `TrayTip()`.

**Dependencies**: Prefer native AutoHotkey solutions over external binaries when possible.
</Standards>

<Limitations>
- No AutoHotkey v1 syntax
- No legacy `%var%` expansions
- No hardcoded local machine paths
- No admin elevation unless the task truly requires it
</Limitations>
