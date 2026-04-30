# Custom Commands Rules

These rules govern the creation, organization, and maintenance of custom commands in `.kilo/commands/` for the Ven0m0/Win repository. They apply to all command markdown files.

## Command vs Skill Distinction

| Aspect | Command | Skill |
|--------|---------|-------|
| Purpose | One-off prompt template | Reusable workflow or behavior |
| Invocation | Slash command (`/command-name`) | Loaded on demand via `skill` tool |
| Content | Single prompt with arguments | Multi-section instruction set |
| Lifespan | Executed once per invocation | Stays loaded for the session |
| Use case | "Run validation", "Create restore point" | "How to validate PowerShell", "Bootstrap deployment patterns" |

Rule of thumb: if the user would type the same prompt more than once, make it a **command**. If agents need reference material to complete tasks, make it a **skill**.

## Command File Structure

Commands are markdown files placed in `.kilo/commands/`. The filename (without `.md`) becomes the command name.

```markdown
---
description: Short description shown in the TUI command list
agent: powershell-expert
model: moonshotai/kimi-k2.6
---

Prompt template content goes here.
Use $ARGUMENTS or positional placeholders as needed.
```

Frontmatter options:

| Option | Required | Description |
|--------|----------|-------------|
| `description` | Recommended | Shown in TUI; keep it concise |
| `agent` | Optional | Agent to execute the command (defaults to current) |
| `model` | Optional | Override model for this command |

The markdown body after frontmatter is the **template** sent to the LLM.

## Named Argument Placeholders

Make commands dynamic with placeholders:

| Placeholder | Replaced With |
|-------------|---------------|
| `$ARGUMENTS` | All arguments as a single string |
| `$1`, `$2`, `$3` ... | Individual positional arguments |

Example — single argument:

```markdown
---
description: Explain a PowerShell script
---

Explain what $ARGUMENTS does, its parameters, and any safety considerations.
Focus on registry or system changes if present.
```

Usage: `/explain-file Scripts/debloat-windows.ps1`

Example — multiple positional arguments:

```markdown
---
description: Deploy a single config group
---

Deploy the config group "$1" using Scripts/Setup-Dotfiles.ps1.
Skip winget tools: $2
```

Usage: `/deploy-config "PowerShell profile" true`

Guidelines:

- Use `$ARGUMENTS` when the input is a free-form string (file path, search query)
- Use `$1`, `$2` when arguments have distinct semantic roles
- Do not mix `$ARGUMENTS` and positional placeholders in the same command
- Wrap JSON or complex arguments in quotes when invoking

## Organizing Commands in Subdirectories

For large command sets, organize into subdirectories under `.kilo/commands/`:

```
.kilo/commands/
  validation/
    Validate-Changes.md
    Invoke-ScriptAnalyzer.md
  setup/
    Setup-Win11.md
    Deploy-Configs.md
  maintenance/
    Backup-CurrentConfigs.md
    Sync-Configs.md
```

Subdirectory names are for human organization only; the command name is still derived from the filename. Keep subdirectory depth to one level.

## Integration with AGENTS.md Command Reference Table

Every command in `.kilo/commands/` should be discoverable from `AGENTS.md`:

1. Add the command to the **Quick Start** table or a dedicated **Commands** section
2. Include the exact invocation syntax (`/command-name`)
3. Cross-link to the markdown file for detailed parameter descriptions

Example `AGENTS.md` entry:

```markdown
| Task | Command or Reference |
|------|---------------------|
| Validate changes | `mise run validate` or Kilo: `/Validate-Changes` |
| Deploy single config | Kilo: `/Deploy-Configs <target>` |
```

## Command Naming Conventions

- Use **PascalCase** filenames matching the command purpose (`Validate-Changes.md`, `New-RestorePointSafe.md`)
- Avoid generic names like `run.md` or `fix.md`
- Do not override built-in commands: `/init`, `/undo`, `/redo`, `/share`, `/help`
- Keep names descriptive but concise (2–4 words)

## Validation

Before committing a new command:

1. Verify the markdown frontmatter is valid YAML
2. Confirm placeholders (`$ARGUMENTS`, `$1`, etc.) match the intended usage
3. Ensure the command is listed in `AGENTS.md`
4. Check that the command does not duplicate an existing command or skill

## References

- `.kilo/commands/` — project command directory
- `AGENTS.md` — canonical command reference table
- OpenCode docs: https://opencode.ai/docs/commands/
