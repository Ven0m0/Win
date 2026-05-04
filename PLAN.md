# <plan id="win-repo-todo" v="1">
## <meta>
Update: 2026-05-04 | Scope: Address TODO.md items
Prev TODOs: 2 items found from TODO.md
</meta>

## <exec_order>
1. Submodule removal → TODO1
2. CodeQL fixes → TODO2
</exec_order>

---

## <tasks prio="critical">

<task id="TODO1">
<summary>Remove dotbot-plugins/rust submodule</summary>
<why>Submodule adds complexity and maintenance overhead; Rust plugins not currently used in core functionality</why>
<do>Remove the submodule using git rm and commit the change</do>
<files>dotbot-plugins/rust</files>
<effort>XS</effort>
</task>

<task id="TODO2">
<summary>Fix all codeql errors</summary>
<why>CodeQL errors indicate potential security or quality issues that need resolution</why>
<do>Review and fix all codeql errors shown in GitHub security tab for code scanning alerts</do>
<files>TBD based on codeql scan results</files>
<effort>M</effort>
</task>

</tasks>

## <xref>
| File | Tasks |
|---|---|
| dotbot-plugins/rust | TODO1 |
| TBD | TODO2 |
</xref>

## <legend>
Effort: XS = <1h, S = 1-4h, M = 4-16h, L = 16-40h
</legend>

</plan>