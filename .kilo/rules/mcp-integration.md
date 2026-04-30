# MCP Integration Rules

These rules govern how MCP servers are selected, configured, and used in the Ven0m0/Win repository. They apply to any agent invoking MCP tools or modifying `kilo.json` / `opencode.json` MCP configuration.

## When to Prefer MCP Tools Over Built-In Tools

| Scenario | Preferred Approach | Rationale |
|----------|-------------------|-----------|
| Querying external APIs (GitHub, Exa, Context7) | MCP tool | Built-in tools lack domain-specific filtering |
| Deep documentation lookup (library SDKs) | `context7` MCP | Structured docs with code examples |
| Live web search with recency requirements | `exa` MCP | Real-time crawling, date filtering |
| File operations inside the working directory | Built-in `read`/`write`/`edit` | Lower latency, no context overhead |
| Simple grepping or globbing | Built-in `grep`/`glob` | Faster, no server startup cost |
| Registry or PowerShell introspection | Built-in tools or `powershell` LSP | Native integration, no external dependency |

Default priority: built-in first, MCP only when the built-in tool cannot satisfy the query.

## Context Budget Awareness

Every enabled MCP server adds its tool definitions to the context window.

- GitHub MCP adds ~500–1500 tokens per session
- Context7 adds ~300–800 tokens depending on library count
- Exa adds ~200–400 tokens

Guidelines:

1. Keep only necessary MCP servers enabled in `kilo.json`
2. Disable MCP servers that are not relevant to the current task wave
3. Prefer one-shot MCP queries over chatty back-and-forth
4. If context limit warnings appear, disable non-essential MCP servers before continuing

## Per-Agent MCP Enablement Patterns

Some agents do not need MCP access. Configure per-agent tool control in agent frontmatter or `kilo.json`:

```yaml
---
description: PowerShell script reviewer
mode: subagent
tools:
  webfetch: false
  websearch: false
---
```

| Agent Type | Typical MCP Needs |
|------------|-------------------|
| `powershell-expert` | Usually none; disable to save tokens |
| `windows-system-agent` | May use `exa` for latest driver docs |
| `config-deployer-agent` | May use `github` MCP for dotbot upstream changes |
| `explore` | None; rely on built-in read/grep/glob |
| Primary / Orchestrator | All relevant MCP servers for routing |

## Authentication Patterns

### API Key via Headers

Use for remote MCP servers that accept static tokens:

```json
{
  "mcp": {
    "exa": {
      "type": "remote",
      "url": "https://mcp.exa.ai/mcp",
      "enabled": true,
      "headers": { "x-api-key": "{env:EXA_API_KEY}" }
    }
  }
}
```

### OAuth

Use for remote MCP servers requiring user-granted authorization:

```json
{
  "mcp": {
    "github": {
      "type": "remote",
      "url": "https://api.githubcopilot.com/mcp/",
      "enabled": true,
      "oauth": {
        "clientId": "{env:MCP_CLIENT_ID}",
        "clientSecret": "{env:MCP_CLIENT_SECRET}",
        "scope": "tools:read tools:execute"
      }
    }
  }
}
```

Rules:

- Never commit literal API keys or OAuth secrets into the repository
- Always use `{env:VAR_NAME}` substitution in `kilo.json`
- Document required environment variables in `AGENTS.md` or setup docs

## Local vs Remote MCP Server Selection

| Factor | Local MCP | Remote MCP |
|--------|-----------|------------|
| Network dependency | None | Requires stable connection |
| Startup latency | Higher (spawn process) | Lower (HTTP connection) |
| Data sensitivity | Keeps data on machine | Sends data to external endpoint |
| Context overhead | Usually smaller | Varies by provider |
| Example | `octocode`, `serena`, `playwright` | `context7`, `exa`, `github` |

Preference:

1. Use **local** MCP for operations involving local filesystem traversal, LSP, or browser automation
2. Use **remote** MCP for knowledge bases, search, and APIs that do not exist locally
3. If both exist for the same capability, prefer local for privacy and latency

## Error Handling When MCP Servers Are Unavailable

Always degrade gracefully:

1. **Timeout** — default MCP timeout is 5000 ms; increase only for known slow servers
2. **Fallback chain**:
   - If `context7` fails, fall back to built-in `codesearch` or `websearch`
   - If `exa` fails, fall back to built-in `websearch`
   - If `github` MCP fails, fall back to `git` CLI or built-in `read` of local `.git`
3. **Disable on failure** — if an MCP server repeatedly errors, set `"enabled": false` in config and retry without it
4. **Log the absence** — when returning results, note which MCP server was unavailable so the user understands reduced capability

Example fallback pattern in agent reasoning:

```
Context7 MCP unavailable (timeout). Falling back to built-in codesearch for React useState examples.
```

## Configuration Validation

After modifying `kilo.json` MCP settings:

1. Ensure JSON syntax is valid
2. Verify `{env:VAR_NAME}` placeholders reference documented variables
3. Confirm `enabled` flags reflect the intended active set for the task
4. Run `opencode mcp debug <name>` if the CLI is available to test connectivity

## References

- `kilo.json` — canonical MCP configuration for this project
- `AGENTS.md` — environment variable documentation
- OpenCode docs: https://opencode.ai/docs/mcp/
