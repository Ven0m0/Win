### 1
implement [mise action](https://github.com/jdx/mise-action) `jdx/mise-action@v4` in [workflows](.github/workflows/)

### 2
fix all findings/errors under "https://github.com/Ven0m0/Win/security/code-scanning"

### 3
use mise for `.github/actions/setup-pwsh/action.yml`

### 4
add Qos 46 to `Scripts/reg/priority.reg` for arc raiders, bo6 and fortnite

### 5
extend dotbot via its [plugins](https://github.com/anishathalye/dotbot/wiki/Plugins)

```bash
git submodule add https://github.com/fundor333/dotbot-gh-extension.git
git submodule add https://github.com/kurtmckee/dotbot-firefox.git
git submodule update --init dotbot-firefox
git submodule add https://github.com/alexcormier/dotbot-rust
git submodule add https://github.com/JamJar00/dotbot-scoop.git
git submodule add https://github.com/kurtmckee/dotbot-windows.git
git submodule update --init dotbot-windows
```
