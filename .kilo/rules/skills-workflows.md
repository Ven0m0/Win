# Skills and Workflows Rules

These rules govern how skills are discovered, loaded, authored, and maintained in the Ven0m0/Win repository. They apply to all `SKILL.md` files and skill-related configuration.

## Skill Naming Conventions

Skill names must be:

- **Lowercase alphanumeric with hyphens** only (e.g., `windows-dotfiles`, `bootstrap-deployment`)
- **1–64 characters** in length
- Free of consecutive hyphens (`--`) and leading/trailing hyphens
- **Identical to the containing directory name**

Good:

- `registry-tweaks`
- `powershell-ci`
- `win11-setup`

Bad:

- `Windows_Dotfiles` (uppercase and underscore)
- `bootstrap--deployment` (consecutive hyphens)
- `ps` (too vague)

## SKILL.md Frontmatter Requirements

Every `SKILL.md` must begin with YAML frontmatter wrapped in `---`:

```yaml
---
name: skill-name
description: |
  Specific, actionable description with trigger keywords.
  Include what the skill does, when to use it, and domain keywords.
license: MIT
compatibility: opencode
metadata:
  workflow: validation
  audience: developers
---
```

Required fields:

| Field | Requirement |
|-------|-------------|
| `name` | Must match directory name; lowercase alphanumeric with hyphens |
| `description` | 1–1024 characters; specific enough for agent selection; include trigger keywords and intent signals |

Optional fields:

| Field | Purpose |
|-------|---------|
| `license` | License identifier (e.g., `MIT`) |
| `compatibility` | Target platform (`opencode`) |
| `metadata` | Key–value string map for organizational tags |

Description guidelines:

- Start with an action verb (NOT "You are" or "[Role] expert")
- List specific capabilities; avoid vague "helps with X"
- Include "Use proactively when" trigger contexts
- Use `|-` literal block scalar for multi-line descriptions to avoid YAML parsing errors

## When to Create a New Skill vs Extend an Existing One

Create a **new skill** when:

- The workflow is unrelated to any existing skill (e.g., a new game-optimization workflow)
- The target audience or agent type differs significantly
- The content would bloat an existing skill beyond a single focused page

Extend an **existing skill** when:

- The workflow is a variation or sub-task of an existing one (add a section, not a new file)
- The same agents would load both skills together every time
- The description and triggers overlap heavily

Anti-pattern: creating `powershell-lint`, `powershell-style`, and `powershell-testing` as separate skills when one `powershell-ci` skill suffices.

## Skill Permission Patterns

Control skill access in `kilo.json` using pattern-based permissions:

```json
{
  "permission": {
    "skill": {
      "*": "allow",
      "internal-*": "deny",
      "experimental-*": "ask"
    }
  }
}
```

| Mode | Behavior |
|------|----------|
| `allow` | Skill loads immediately |
| `deny` | Skill is hidden and cannot be loaded |
| `ask` | User is prompted before loading |

Per-agent overrides are supported in agent frontmatter:

```yaml
---
permission:
  skill:
    "windows-*": allow
    "experimental-*": ask
---
```

## Companion Skills for Plugins

When a plugin requires specific knowledge to use correctly, provide a companion skill:

- Place the skill in `.kilo/skills/<plugin-name>/`
- Name it after the plugin (e.g., `opencode-bettergrep` → `bettergrep-usage`)
- Document the plugin's custom tools, arguments, and expected outputs
- Load the companion skill proactively when the plugin is installed

## Skill Discovery Paths

OpenCode discovers skills in the following priority order (first match wins):

1. `.kilo/skills/<name>/SKILL.md` — project-level (this repo)
2. `.claude/skills/<name>/SKILL.md` — Claude-compatible project level
3. `~/.config/kilo/skills/<name>/SKILL.md` — global user level
4. `~/.claude/skills/<name>/SKILL.md` — global Claude-compatible
5. `~/.agents/skills/<name>/SKILL.md` — global agent-compatible

Project-level skills override global skills with the same name.

## Skill Maintenance

- Keep skills **focused and minimal** — only what is needed for the task
- If a skill grows beyond one screen of content, split it or extract reference files
- Validate YAML frontmatter after any edit; malformed frontmatter causes the skill to be silently ignored
- Do not duplicate content between skills and `AGENTS.md`; cross-reference instead

## Troubleshooting

If a skill does not load:

1. Verify the file is named exactly `SKILL.md` (all caps)
2. Check that `name` and `description` are present in frontmatter
3. Ensure the skill name is unique across all discovery paths
4. Check permission rules — `deny` hides the skill entirely
5. Confirm the directory name matches the `name` field

## References

- `.kilo/skills/` — project skill directory
- `kilo.json` — skill path and permission configuration
- OpenCode docs: https://opencode.ai/docs/skills/
