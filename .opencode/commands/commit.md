---
description: Generate a conventional commit message from staged changes
agent: code
---

Generate a conventional commit message for the staged diff below.

Staged diff:
```diff
!`git diff --staged 2>/dev/null | head -200`
```

Rules for this repository:
- Format: `<type>: <subject>` (subject ≤72 chars, imperative mood)
- Valid types: `feat` · `fix` · `docs` · `refactor` · `style` · `chore`
- Body is optional; use it only when "why" isn't obvious from the subject
- Do NOT include a body that just restates what the diff shows
- PowerShell script additions: `feat: Add <script-name>.ps1 for <purpose>`
- Registry tweak changes: `feat:` if new, `fix:` if correcting a value
- Doc-only changes: `docs: Update AGENTS.md ...` or `docs: Update README.md ...`

Output: the exact commit message string, nothing else. No quotes, no markdown fences.
