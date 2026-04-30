---
name: mcp-server-management
description: "Configure and troubleshoot MCP servers for OpenCode/Kilo environments"
compatibility: opencode
---

# MCP Server Management Skill

Use this skill when adding, configuring, debugging, or optimizing MCP servers in OpenCode or Kilo. Covers local and remote servers, authentication, context budgeting, and per-agent scoping.

## Adding MCP Servers

MCP servers are defined in `opencode.json` (project or global `~/.config/opencode/opencode.json`) under the `mcp` key.

### Local MCP Servers

Use `type: local` for servers that run as a local process.

```json
{
  "mcp": {
    "my-local-mcp": {
      "type": "local",
      "command": ["bun", "x", "my-mcp-command"],
      "enabled": true
    }
  }
}
```

- `command` must be an array of strings (executable + args)
- Ensure the runtime (`bun`, `node`, `python`, etc.) is installed and in PATH
- Prefer project-local installs over global to avoid version drift

### Remote MCP Servers

Use `type: remote` for servers hosted over HTTP/S.

```json
{
  "mcp": {
    "my-remote-mcp": {
      "type": "remote",
      "url": "https://api.example.com/mcp",
      "headers": {
        "X-Custom-Header": "value"
      },
      "enabled": true
    }
  }
}
```

- `url` must be the MCP server endpoint
- `headers` are optional and passed with every request
- Verify TLS/certificate issues before enabling in CI

## Authentication Patterns

### OAuth (Default for Remote)

OpenCode automatically handles OAuth for remote MCP servers that require it. When the server signals an auth challenge, OpenCode opens a browser flow and stores tokens securely.

To disable automatic OAuth (e.g., when using API keys instead):

```json
{
  "mcp": {
    "jira": {
      "type": "remote",
      "url": "https://jira.example.com/mcp",
      "oauth": false,
      "enabled": true
    }
  }
}
```

### API Keys via Environment Variables

For servers that accept API keys, pass them through environment variables rather than hardcoding in config:

```json
{
  "mcp": {
    "exa": {
      "type": "remote",
      "url": "https://mcp.exa.ai/sse",
      "oauth": false,
      "enabled": true
    }
  }
}
```

```bash
# In shell profile or CI env
export EXA_API_KEY="your-key"
```

In PowerShell (Windows):

```powershell
$env:EXA_API_KEY = "your-key"
```

### Local Server Env Vars

For local MCP servers that read env vars, set them before starting OpenCode/Kilo or prefix the command:

```json
{
  "mcp": {
    "context7": {
      "type": "local",
      "command": ["env", "CONTEXT7_API_KEY=xxx", "node", "./mcp-server.js"],
      "enabled": true
    }
  }
}
```

## Context Budget Management

Each enabled MCP server consumes context budget. Disable servers that are not needed for the current task.

### Global Disable

```json
{
  "mcp": {
    "jira": {
      "enabled": false
    }
  }
}
```

### Glob Pattern Disable

Disable groups of servers by glob:

```json
{
  "tools": {
    "jira*": false,
    "github*": false
  }
}
```

### Per-Agent Enablement

If you have many MCP servers, disable them globally and enable only for specific agents:

```json
{
  "mcp": {
    "exa": {
      "type": "remote",
      "url": "https://mcp.exa.ai/sse",
      "enabled": true
    }
  },
  "tools": {
    "exa*": false
  },
  "agent": {
    "researcher": {
      "tools": {
        "exa*": true
      }
    }
  }
}
```

This keeps the default agent lean while giving the researcher agent full search capability.

## Debugging Failed MCP Connections

### Checklist

1. **Config syntax**: Validate `opencode.json` with `jsonlint` or an IDE
2. **Server reachable**: `curl -fsSL <url>/health` or `ping` the endpoint
3. **Local binary**: Verify `command[0]` exists in PATH (`Get-Command` in PowerShell, `which` in bash)
4. **Auth errors**: Check env vars are set; confirm `oauth: false` if using API keys
5. **Logs**: Run OpenCode with verbose logging to see MCP initialization output
6. **Permissions**: Ensure the agent has `tools` permission for the MCP namespace (e.g., `exa*`)

### Common Failures

| Symptom | Cause | Fix |
|---|---|---|
| `Connection refused` | Local server not running | Start the server or check `command` path |
| `401 Unauthorized` | Missing API key or OAuth disabled | Set env var or enable `oauth: true` |
| `MCP tool not found` | Tool disabled globally and not enabled per-agent | Add `"mcp-name*": true` to agent tools |
| `Timeout` | Server slow or network issue | Increase `timeout` in MCP config or check URL |

### Forcing a Reconnect

Restart the OpenCode/Kilo session. MCP servers initialize once per session; there is no hot-reload.

## Security & Best Practices

- Never commit API keys or tokens into `opencode.json`
- Use `$env:` or shell env vars for secrets
- Prefer read-only MCP scopes for agents that do not need write access
- Review MCP server permissions in the `permission` block of `opencode.json`
- Disable experimental or unused MCP servers in shared/project configs to reduce attack surface

## Related

- `opencode-migration` — migrating MCP configs from other tools
- `agent-delegation` — scoping MCP access per agent
