# Lint-Guidance

**Category:** Validation / AI Guidance
**Scope:** Validate AGENTS.md and `.kilo/` configuration files

## Synopsis

Run linting and structural validation on repository AI guidance: `AGENTS.md`, `.kilo/` skills, agents, rules, and `.github/instructions/`.

## Description

This workflow command validates AI guidance files for syntax errors, broken symlinks, invalid frontmatter, and structural inconsistencies:

1. **ctxlint** — Run `@yawlabs/ctxlint` on `.github/instructions/`, `.github/skills/`, `.github/workflows/`, and `.kilo/` configuration
2. **Symlink check** — Verify `CLAUDE.md` remains a valid symlink to `AGENTS.md`
3. **JSON/YAML validation** — Parse `.kilo/skills/`, `.kilo/agents/`, `.kilo/rules/` and workflow files for syntax errors
4. **Skill frontmatter** — Verify each skill file has valid metadata and referenced paths exist
5. **Cross-reference check** — Ensure paths and commands referenced in guidance files actually exist in the repository

## Steps

```bash
# 1. Run ctxlint on guidance files
npx ctxlint --depth 3 --mcp --strict --fix --yes .github/instructions/ .github/skills/ .kilo/

# 2. Check symlink status
ls -la CLAUDE.md

# 3. Validate JSON/YAML syntax
# YAML
cat .github/workflows/powershell.yml | python3 -c "import yaml,sys; yaml.safe_load(sys.stdin)"
# JSON
find .kilo/ -name '*.json' -exec python3 -m json.tool {} \;

# 4. Verify skill frontmatter and references
grep -r '^applyTo:' .github/instructions/
grep -r '^description:' .github/skills/

# 5. Cross-reference paths mentioned in AGENTS.md
grep -oE '[A-Za-z0-9_./-]+\.md' AGENTS.md | xargs -I {} test -f {} && echo "OK" || echo "MISSING: {}"
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Fix` | Switch | False | Auto-fix safe issues with ctxlint |
| `-Strict` | Switch | False | Fail on warnings |
| `-Path` | String | `'.'` | Repository root containing guidance files |

## Usage

```powershell
# Run all guidance checks
.\Lint-Guidance.ps1

# Auto-fix where safe
.\Lint-Guidance.ps1 -Fix

# Strict mode
.\Lint-Guidance.ps1 -Strict

# Validate only .kilo/ config
.\Lint-Guidance.ps1 -Path .kilo/
```

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | All guidance files valid |
| `1` | Lint or validation failures found |
| `2` | Tool execution error (e.g., ctxlint not installed) |

## Notes

- This markdown file is Kilo command reference only. Implement as `Scripts/Lint-Guidance.ps1` if needed.
- Install `ctxlint` with: `npm i -g @yawlabs/ctxlint`
- Expected output is a lint report markdown file listing errors, warnings, and fixed items.
- Always run this after editing any `.github/` or `.kilo/` guidance.

## Related

- `AGENTS.md` — canonical repository guide
- `.kilo/skills/` — agent-facing workflow knowledge
- `.kilo/agents/` — agent identity definitions
- `.kilo/rules/` — coding and system standards
- `Validate-Changes.md` — broader validation workflow
