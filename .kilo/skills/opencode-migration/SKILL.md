---
name: opencode-migration
description: "Migrate AI assistant configurations from Claude Code, Cursor, and other tools to OpenCode/Kilo"
compatibility: opencode
---

# OpenCode Migration Skill

Use this skill when migrating a project from Claude Code, Cursor, or another AI assistant tool to OpenCode or Kilo. Covers rules files, skill directories, MCP configs, agent definitions, and post-migration validation.

## Rules File Mapping

### AGENTS.md vs CLAUDE.md vs .cursorrules

| Source Tool | Source File | OpenCode Target | Notes |
|---|---|---|---|
| Claude Code | `CLAUDE.md` | `AGENTS.md` (preferred) | Copy content; remove Claude-specific hooks |
| Claude Code | `~/.claude/CLAUDE.md` | `~/.config/opencode/AGENTS.md` | Global rules migration |
| Cursor | `.cursorrules` | `AGENTS.md` | Rename; flatten MDC rules if present |
| Cursor | `.cursor/rules/*.md` | `.opencode/rules/*.md` or `AGENTS.md` | Consolidate or reference via `instructions` |
| Generic | `.github/copilot-instructions.md` | Keep + reference in `AGENTS.md` | Copilot file can coexist; import via `instructions` |

### Migration Steps for Rules

1. **Rename or create** `AGENTS.md` at project root
2. **Copy content** from `CLAUDE.md` or `.cursorrules`
3. **Remove persona framing**: OpenCode ignores "You are an expert..." prompts; use direct instructions
4. **Add `compatibility: opencode`** if frontmatter is used (optional)
5. **Symlink handling**: If `CLAUDE.md` must remain, symlink it to `AGENTS.md` (not the reverse)
6. **Update `opencode.json`** to reference additional instruction files if needed:

```json
{
  "instructions": [
    "AGENTS.md",
    ".cursor/rules/*.md"
  ]
}
```

## Skill Directory Migration Paths

### From Claude Code

Claude Code skills live in `~/.claude/skills/` as flat `.md` files or directories with `SKILL.md`.

| Source Path | OpenCode Target |
|---|---|
| `~/.claude/skills/*.md` | `~/.config/opencode/skills/*/` (directory with `SKILL.md`) |
| `~/.claude/skills/my-skill/` | `~/.config/opencode/skills/my-skill/` |
| Project-local `.claude/skills/` | `.opencode/skills/` or `.kilo/skills/` |

### From Cursor

Cursor does not have a native skill system. If skills were stored in `.cursor/skills/`, migrate the same way:

1. Create directory under `.opencode/skills/<name>/`
2. Move markdown content into `SKILL.md`
3. Add YAML frontmatter (`name`, `description`, `compatibility`)

### Frontmatter Template

```yaml
---
name: skill-name
description: "One-line description of what this skill does"
compatibility: opencode
---
```

## MCP Server Config Translation

### From Claude Code

Claude Code does not have a native `mcp` config block. If MCP servers were started manually or via shell scripts, translate them into `opencode.json`:

```json
{
  "mcp": {
    "my-mcp": {
      "type": "local",
      "command": ["node", "./claude-mcp-server.js"],
      "enabled": true
    }
  }
}
```

### From Cursor

Cursor uses `.cursor/mcp.json` (non-standard). Migrate keys to `opencode.json`:

| Cursor Key | OpenCode Key | Notes |
|---|---|---|
| `command` | `command` | Array format preferred |
| `args` | merged into `command` | `["node", "...", "arg1"]` |
| `env` | shell env vars | Set before launch or inline in `command` |
| `url` | `url` under `type: remote` | Add `type: remote` |

Example migration:

```json
// .cursor/mcp.json
{
  "mcpServers": {
    "exa": {
      "command": "node",
      "args": ["exa-mcp/dist/index.js"],
      "env": { "EXA_API_KEY": "..." }
    }
  }
}
```

Becomes:

```json
// opencode.json
{
  "mcp": {
    "exa": {
      "type": "local",
      "command": ["node", "exa-mcp/dist/index.js"],
      "enabled": true
    }
  }
}
```

Move the API key to an environment variable: `$env:EXA_API_KEY = "..."`

## Agent Definition Migration

### Markdown Agent Definitions

OpenCode/Kilo agents can be defined as markdown files with YAML frontmatter.

#### From Claude Code Subagent Prompts

If agents were defined inline in `CLAUDE.md` or as separate prompt files:

1. Create `.opencode/agents/<agent-name>.agent.md` (or `.kilo/agents/`)
2. Add frontmatter with `name`, `description`, `model`, `tools`
3. Move the system prompt into the markdown body

Template:

```markdown
---
name: windows-system-agent
description: Windows optimization and registry specialist
model: anthropic/claude-sonnet-4-20250514
tools:
  - bash
  - registry
permissions:
  read: true
  write: true
  bash: true
---

# Windows System Agent

You specialize in Windows registry tweaks, debloating, and gaming optimization...
```

#### From Cursor Agents

Cursor agents are usually not file-based. If they exist in `.cursor/agents/`, migrate to `.opencode/agents/` and add the frontmatter block above.

### JSON Agent Definitions

Agents can also be defined in `opencode.json`:

```json
{
  "agent": {
    "powershell-expert": {
      "model": "anthropic/claude-sonnet-4-20250514",
      "instructions": [".kilo/agents/powershell-expert.agent.md"],
      "permissions": {
        "read": true,
        "write": true,
        "bash": true
      }
    }
  }
}
```

## Validation Checklist After Migration

### Rules & Instructions

- [ ] `AGENTS.md` exists at project root and loads without YAML syntax errors
- [ ] `CLAUDE.md` is either removed or symlinked to `AGENTS.md` (not duplicate content)
- [ ] `.cursorrules` renamed or referenced in `opencode.json` `instructions`
- [ ] No stale tool-specific instructions that reference unavailable tools

### Skills

- [ ] All skill directories contain a `SKILL.md` file
- [ ] Each `SKILL.md` has valid YAML frontmatter (`name`, `description`)
- [ ] Skill paths referenced in `opencode.json` or `AGENTS.md` resolve correctly

### MCP Servers

- [ ] `opencode.json` has a top-level `mcp` object (not `mcpServers`)
- [ ] Local MCP `command` arrays are valid and binaries exist in PATH
- [ ] Remote MCP `url` values are reachable
- [ ] API keys moved to environment variables; none hardcoded in JSON
- [ ] OAuth explicitly set to `false` when using API keys

### Agents

- [ ] Agent files live in `.opencode/agents/` or `.kilo/agents/`
- [ ] Each agent has `name` and `description` in frontmatter
- [ ] Permissions are narrowed to the minimum required for the agent's role
- [ ] No legacy `tools:` blocks remain; converted to `permissions:`

### Config Syntax

- [ ] `opencode.json` is valid JSON (run `jsonlint` or `jq empty opencode.json`)
- [ ] No trailing commas
- [ ] All referenced files exist (`instructions`, `rules`, `skills`)

### Functional Test

- [ ] Start a new OpenCode/Kilo session in the project
- [ ] Verify `AGENTS.md` content appears in the system context
- [ ] Test one MCP tool call to confirm connectivity
- [ ] Run a simple agent delegation to confirm subagent spawning works

## Common Pitfalls

- **Duplicate rules**: keeping both `AGENTS.md` and `CLAUDE.md` with different content. OpenCode prefers `AGENTS.md`; `CLAUDE.md` is ignored if both exist.
- **Flat skills**: leaving skills as flat `.md` files. OpenCode expects `<skill>/SKILL.md` directories.
- **`mcpServers` vs `mcp`**: Cursor uses `mcpServers`; OpenCode uses `mcp`.
- **Missing `type`**: remote MCP servers must have `"type": "remote"`.
- **String `command`**: OpenCode requires `command` as an array, not a space-separated string.

## Related

- `mcp-server-management` — configuring and debugging migrated MCP servers
- `agent-delegation` — using migrated agents in multi-agent workflows
