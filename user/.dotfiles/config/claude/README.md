# Claude Code config

Deploys to `$HOME\.claude` via `Scripts/Setup-Dotfiles.ps1` (manifest entry `Claude Code config`,
directory mode, recursive, SHA256 hash-based copy). Marketplaces, plugins, and MCP servers are
installed separately by `Scripts/Setup-ClaudeCode.ps1`, which reads `settings.json`
(`extraKnownMarketplaces` + `enabledPlugins`) and `mcp-servers.json`.

## Tracked here

| Path | Purpose |
| --- | --- |
| `settings.json` | Global Claude Code settings: env, permissions, hooks, plugins, marketplaces |
| `CLAUDE.md` | Global instructions (OMC orchestration, code standards, memory protocol) |
| `RTK.md` | `@RTK.md` import target referenced from `CLAUDE.md` |
| `mcp-servers.json` | MCP server manifest consumed by `Setup-ClaudeCode.ps1`; `%VAR%` tokens in `command`/`args`/`env` are expanded at install time |
| `hooks/validate-edit.ps1` | PostToolUse validator: PSScriptAnalyzer, ruff, biome, XML, YAML |
| `hooks/guard-bedrock-db.ps1` | PreToolUse guard against editing Bedrock LevelDB binaries |
| `hooks/rtk-advisor.ps1` | PreToolUse advisor for command shapes `rtk` cannot rewrite |
| `hooks/context-mode-no-webfetch.mjs` | SessionStart: removes context-mode's WebFetch matcher so native WebFetch works |
| `agents/` `commands/` `rules/` `skills/` | User-level agent, command, rule, and skill definitions |

LSP servers ship as plugins (`*@claude-code-lsps`, `rust-analyzer-lsp`, `jdtls-lsp`), so they are
covered by `enabledPlugins`; there is no separate user-level LSP file. The repo-root `.lsp.json` is
project-scoped.

Skills installed by plugins are not copied here (`caveman`, `megacave`, `ultracave` come from the
`caveman` plugin; `cli-hub-meta-skill` is a symlink managed by `cli-anything`).

## Deliberately not tracked

These are generated or machine-local; a tracked copy would go stale and get redeployed over the
fresh one.

| Path | Recreated by |
| --- | --- |
| `hud/omc-hud.mjs` | `/oh-my-claudecode:omc-setup` |
| `hooks/context-mode-cache-heal.mjs` | the `context-mode` plugin on install |
| `.omc-config.json` | `/oh-my-claudecode:omc-setup` |
| `plugins/`, `projects/`, `sessions/`, `history.jsonl`, `.credentials.json`, `settings.local.json` | runtime state and credentials |

`settings.json` guards every machine-dependent entry point (status line, context-mode hooks, the
`caveman-proxy`/`caveman` hooks, `rtk`, `codegraph`), so each no-ops on a fresh system instead of
erroring.

Machine-local overrides stay out of `settings.json`. In particular `ANTHROPIC_BASE_URL`
(`http://127.0.0.1:8787/w/claude`, the local caveman proxy) and its companion
`_CLAUDE_CODE_ASSUME_FIRST_PARTY_BASE_URL=1` belong in `~/.claude/settings.local.json`; a tracked
copy would break every machine without the proxy running. The deploy never touches that file.

## Fresh-system order

1. `mise run bootstrap` (or `Scripts/Setup-Win11.ps1`) - installs tooling and deploys this directory
2. `pwsh -File Scripts/Setup-ClaudeCode.ps1` - marketplaces, plugins, MCP servers
3. `claude` then `/oh-my-claudecode:omc-setup` - regenerates the HUD and OMC config

## Hook prerequisites

`validate-edit.ps1` dispatches on file extension and skips any branch whose tool is missing, so a
partial toolchain degrades quietly rather than failing edits.

| Extension | Tool | Install |
| --- | --- | --- |
| `.ps1` `.psm1` `.psd1` | PSScriptAnalyzer, Pester | `Install-Module` (see `Scripts/packages.psd1` `PsModules`) |
| `.py` `.pyi` | `ruff` | `uv tool install ruff` |
| `.json` `.jsonc` | `biome` | `winget install BiomeJS.Biome` |
| `.yaml` `.yml` | `yq` | `winget install MikeFarah.yq` |
| `.xml` and XML dialects | none (.NET `XmlReader`) | - |
