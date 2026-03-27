# Code Style Rules

## PowerShell (`.ps1`, `.psm1`) — enforced by PSScriptAnalyzer CI

- **Brace style**: OTBS — opening `{` on the same line as the keyword. `function Foo {` not `function Foo\n{`
- **Indent**: 2 spaces. No tabs. `.editorconfig` sets `indent_style = space`, `indent_size = 2` for `*.ps1`/`*.psm1`
- **Line length**: 120 chars max (`.editorconfig` `max_line_length = 120`)
- **Line endings**: CRLF. `.editorconfig` `end_of_line = crlf` for `*.ps1`/`*.psm1`
- **Encoding**: UTF-8 with BOM for PowerShell files
- **Operators**: spaces around all binary operators — `$x = $a + $b`, `-eq`, `-ne`, `-lt`, `-gt`
- **Pipes**: space before and after `|` — `Get-Process | Where-Object { $_ -eq 'foo' }`
- **Trailing whitespace**: trimmed (except `.md` files)

## File naming

| Type | Convention | Example |
|---|---|---|
| PowerShell scripts | `lowercase-with-dashes.ps1` | `gaming-display.ps1` |
| Batch files | `lowercase-with-dashes.cmd` | `allow-scripts.cmd` |
| Important docs | `UPPERCASE.md` | `AGENTS.md`, `README.md` |
| Config files | Follow application convention | `settings.json` |
| Registry files | `lowercase-with-dashes.reg` | — |

## Comment-based help (required on all public functions)

```powershell
<#
.SYNOPSIS
    One-line description (required).
.DESCRIPTION
    Extended description.
.PARAMETER ParamName
    What this parameter does.
.EXAMPLE
    Verb-Noun -ParamName "value"
#>
```

## Banned PSScriptAnalyzer rules (CI will fail)

- `PSAvoidGlobalAliases` — no `ls`, `cd`, `rm` etc.; use `Get-ChildItem`, `Set-Location`, `Remove-Item`
- `PSAvoidUsingConvertToSecureStringWithPlainText` — never store plaintext secrets this way
- `PSAvoidUsingInvokeExpression` with variable input — injection risk

## Markdown

- Trailing whitespace allowed (`.editorconfig` `trim_trailing_whitespace = false` for `*.md`)
- `UPPERCASE.md` naming for important docs; `lowercase.md` for everything else
