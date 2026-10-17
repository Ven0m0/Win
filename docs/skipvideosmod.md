# SkipVideosMod.ps1

Deletes the intro, match-launch and quest cutscene `.bk2` files from an Arc Raiders install so
the game skips them. Auto-detects the install path (Steam, then Epic, then the script's own
folder). Runs an interactive menu by default, or a single action when `-Option` is given.
Mod by TinyStormCloud (v1.15.0 in the script header).

The script permanently deletes game files. It has no `-WhatIf`, `-Restore` or `-Undo`.

## Usage

Interactive menu:

```powershell
pwsh -NoProfile -File Scripts\arc-raiders\SkipVideosMod.ps1
```

Skip the intro video only, non-interactive:

```powershell
pwsh -NoProfile -File Scripts\arc-raiders\SkipVideosMod.ps1 -Option 1
```

Apply all three (intro, match, quest), non-interactive:

```powershell
pwsh -NoProfile -File Scripts\arc-raiders\SkipVideosMod.ps1 -Option 4
```

Run the diagnostics screen:

```powershell
pwsh -NoProfile -File Scripts\arc-raiders\SkipVideosMod.ps1 -Option 5
```

## Parameters

| Parameter | Default | Notes |
| --- | --- | --- |
| `-Option` | none (menu) | `1` Intro, `2` Match, `3` Quest, `4` All, `5` Diagnostics, `6` Credit, `0` Exit. Any other value is rejected by `ValidateSet` |

Admin is not enforced. Diagnostics only warns when the process is not elevated or when a write
test in `Movies` fails. Run elevated if the game is under a protected path such as `C:\Program Files`.

## Files modified

All paths are under `<install>\PioneerGame\Content\Movies`:

| Option | File deleted |
| --- | --- |
| 1 | `FTUE\GAME_INTRO_SPERANZA_DESCEND_V5.bk2` |
| 2 | `Frontend\LaunchSequence_ToBlack_4k.bk2` |
| 3 | 11 files in `Quests\` (`Quest_Intro_*`, `QUEST_INTRO_*`, `QUEST_OUTRO_*`; see `$questFiles` in the script) |

## How it works

1. **Common.ps1.** The script dot-sources `Scripts\Common.ps1` (`$PSScriptRoot\..\Common.ps1`).
   The only shared helper it calls is `Test-IsAdmin`, used by the diagnostics screen.
   `ArcRaidersCommon.ps1` is not used.
2. **Install detection (`Find-ArcRaider`).** First hit wins:
   `HKCU:\Software\Valve\Steam` `SteamPath`, then `HKLM:\Software\Wow6432Node\Valve\Steam`
   `InstallPath`, each joined with `steamapps\common\Arc Raiders`; then
   `${env:ProgramFiles(x86)}\Steam\...`; then `$env:ProgramFiles\Epic Games\Arc Raiders`; then
   the script's own directory if it contains `PioneerGame`. A candidate counts only if its
   `PioneerGame` subfolder exists. If nothing matches, the script prints the search list and
   exits with code 1. Custom Steam library folders are not read.
3. **Single files (`Remove-VideoFile`).** Missing directory reports an error. Missing file
   reports "Already applied" (treated as success). Otherwise `Remove-Item -Force`.
4. **Quest videos (`Remove-QuestFile`).** Counts which of the 11 listed files exist, deletes
   them, and reports failure if the deleted count differs from the found count.
5. **Confirmation.** Only the interactive menu asks Y/N before options 3 and 4 (the quest
   skip is meant for players who finished the story and expedition). `-Option 3` and
   `-Option 4` run without a prompt.
6. **Dot-sourcing.** When dot-sourced (`InvocationName` is `.`), the script returns before the
   main block so Pester can load the functions (see `tests\SkipVideosMod.Tests.ps1`).

## Reverting

There is no backup. Restore by verifying game files (Steam: Properties, Installed Files,
Verify integrity; Epic: Verify) or reinstalling. A game update may also restore the files.
This is the standard launcher behavior, not something the script implements.

## Limitations

- Deleted files are not backed up or recorded.
- Hard-coded file names target game version 1.15.0 or later (per the script's own
  troubleshooting text). Renamed files in later patches are reported as "Already applied".
- Output uses ANSI escape codes via `[char]27`; a legacy console host may show them raw.
- Diagnostics warns when the install is on `C:\`; the script's own text says to restart the PC
  after applying.
