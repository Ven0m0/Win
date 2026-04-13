# Workflow State
Objective: Fix steam.ps1 crashing on run and fix the "copy path" context menu entry so that the terminal popus is hidden & silent and remove the first "\".

Mode: autopilot
Cycles: 3 / 5

## Acceptance Criteria
- [x] steam.ps1 runs without crashing due to elevation requirements.
- [x] "Copy path" context menu command executes silently without popping up a terminal.
- [x] "Copy path" context menu output no longer includes a leading backslash.