### 1
extend py-psscriptanalyzer integration and include it in @mise.toml

```bash
# format
py-psscriptanalyzer --format example.ps1
# lint recursively
py-psscriptanalyzer --recursive
```
also ensure the pre-commit hooks of py-psscriptanalyzer work correctly

### 2

add to system fix:
- https://github.com/ShadowWhisperer/Fix-WinUpdates
