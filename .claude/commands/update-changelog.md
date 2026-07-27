---
description: Update CHANGELOG.md from recent commits/diff and close out matching TODO.md items
allowed-tools: Read, Edit, Bash, Glob, Grep
---

Update `CHANGELOG.md` to reflect recent work. $ARGUMENTS

If $ARGUMENTS names a commit range or PR, use that. Otherwise use commits since the last entry under `## [Unreleased]`:

```bash
git log --oneline -20
git diff --name-only HEAD~10..HEAD
```

**1. Categorize changes** into the Keep a Changelog sections already used in this file: `Added`, `Changed`, `Fixed`, `Removed`. Skip sections with nothing to report — don't add empty headers.

**2. Write entries** under `## [Unreleased]`:

- One line per notable change, present tense, no trailing period
- Reference the affected script/config path when it disambiguates (e.g. `Scripts/system-update.ps1`)
- Skip noise: formatting-only commits, merge commits, WIP/`update` commits with no discernible content

**3. Cross-check `TODO.md`:**

```bash
cat TODO.md
```

If a changelog entry resolves an item listed there, remove that item from `TODO.md` in the same edit. Do not remove unrelated or still-open items.

**4. Report** what was added to `CHANGELOG.md` and what (if anything) was removed from `TODO.md`. Do not commit — leave staging/commit to the user.
