---
name: repo-janitor
description: "Orchestrates repository and file system cleanup through sequential phases: separating code from docs, organizing folder structure (both repos and general directories), removing legacy code, removing script clutter, pruning documentation sprawl, cleaning documentation content (emojis, hyperbole, 'comprehensive'), and eliminating duplicate files. Use when cleaning repositories, organizing projects, removing legacy code, pruning AI-generated docs, organizing Downloads/Documents/project folders, finding duplicates, restructuring folder hierarchies, or establishing organizational systems. Triggers on: 'clean up repo', 'janitor', 'organize', 'repository cleanup', 'remove legacy', 'prune docs', 'find duplicates', 'organize folder', 'project structure', 'tidy workspace', 'folder cleanup', 'downloads organization'."
---

# Repo Janitor

<overview>
Seven-step sequential cleanup for repositories and file systems. Each step must complete before the next — parallel execution causes conflicts. Works for code repos, project folders, and general directories (Downloads, Documents, Projects). Ask before deleting.
</overview>

## Steps

<steps>
**1. Separate Code from Docs** (Repos only) — Non-deployable content at different top-level path from code. Confirm before touching deployment paths.

**2. Organize Structure** — Assess hierarchy, group logically. Repos: verify moves don't break functionality. General folders: sort by Type (documents, images, videos, archives, code, spreadsheets), Purpose (work/personal, active/archive, project-specific), or Date (year/month for photos). Use standards: clear names, hyphens not spaces, specific descriptors ("client-proposals" not "docs").

**3. Find & Remove Duplicates** — Hash exact duplicates, list by name. Show paths, sizes, dates; recommend keeping (newest in correct location). Always ask before deleting.

**4. Remove Legacy Code** (Repos) — From main entry point, identify abandoned code paths, delete with confirmation.

**5. Remove Script Clutter** (Repos) — Delete single-purpose diagnostic scripts, consolidate/refactor first, ask if uncertain.

**6. Remove Documentation Sprawl** — Delete AI-generated docs (edit descriptions, time-limited info, activity logs). Integrate useful content into README. Eliminate root-level sprawl first.

**7. Clean Documentation & Metadata** — On all remaining markdown (skip prompts, instructions): remove emojis, "comprehensive", hyperbolic language. Minimize whitespace: strip trailing, collapse 2+ blanks to one, remove leading/trailing blanks. Never alter structure.
</steps>

## Rules

<rules>
- Sequential only — never run steps in parallel
- Ask before deleting if any doubt about safety
- Verify refactoring before any structural move
- Extra caution on deployment-affecting changes
- Report completion of each step to user
- Final summary: enumerate every change made
</rules>

## Best Practices

**Naming**: Use "YYYY-MM-DD - Description.ext" for timestamped files, hyphens not spaces, kebab-case folders, specific names ("client-proposals" not "docs").

**Organization Patterns**: By Type (documents, images, videos, archives, code), by Purpose (work/personal, active/archive, project-specific), by Date (year/month chronologically).

**Archive Strategy**: Move instead of delete if hesitant. Archive projects untouched 6+ months, completed work, old versions, uncertain files.

**Maintenance**: Weekly sort Downloads, monthly review/archive projects, quarterly check duplicates, yearly archive old files.

## Identifying Documentation vs Prompt Files

<doc-detection>
Documentation: README.md, docs/, any public-facing .md describing features, setup, or API.
Skip (do not clean content): files in prompts/, .claude/commands/, .claude/agents/, any file whose content is instructions to an LLM agent.
</doc-detection>
