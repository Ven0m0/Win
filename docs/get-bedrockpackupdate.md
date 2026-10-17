# Get-BedrockPackUpdate.ps1

Reports which Minecraft Bedrock behavior/resource packs and native mods installed in
LeviLauncher have a newer upstream release, and with `-Update` installs the updates. Packs are
matched to a source URL through the hand-maintained map `Scripts\bedrock-packs.psd1`. Read-only
unless `-Update` is given. Does not require Administrator.

## Usage

Report for the newest installed instance:

```powershell
.\Scripts\Get-BedrockPackUpdate.ps1
```

Preview an update run, then run it:

```powershell
.\Scripts\Get-BedrockPackUpdate.ps1 -Update -WhatIf
.\Scripts\Get-BedrockPackUpdate.ps1 -Update
```

Specific instance, or list packs still lacking a source:

```powershell
.\Scripts\Get-BedrockPackUpdate.ps1 -Version 1.26.33.01
.\Scripts\Get-BedrockPackUpdate.ps1 -AsObject | Where-Object Status -eq 'UNMAPPED'
```

## Parameters

| Parameter | Default | Notes |
| --- | --- | --- |
| `-Version` | newest instance | LeviLauncher instance, for example `1.26.40.05`; the newest version-shaped folder under `versions` |
| `-PackRoot` | resolved | Full path to a `com.mojang` folder; skips instance lookup |
| `-ModRoot` | `<instance>\mods` | Full path to the mods folder |
| `-SourceMap` | `Scripts\bedrock-packs.psd1` | Source map; missing file makes every pack `UNMAPPED` |
| `-AsObject` | off | Emit result objects instead of a table |
| `-Update` | off | Auto-map new packs and install available updates |
| `-BackupPath` | `$env:USERPROFILE\Documents\bedrock-pack-backup` | One timestamped folder per run (`-Update`) |
| `-SkipWorlds` | off | Do not rewrite world pack references (`-Update`) |

Supports `-WhatIf` / `-Confirm` (`SupportsShouldProcess`, `ConfirmImpact = Medium`).

## Status values

| Status | Meaning |
| --- | --- |
| `OUTDATED` | Upstream release date is later than the manifest timestamp |
| `current` | Not newer upstream |
| `CHECK` | Source URL is not CurseForge or GitHub; visit manually |
| `ERROR` | Lookup threw |
| `CANDIDATE` | Low-confidence CurseForge search hit; never installed |
| `UNMAPPED` | No source found |

## How it works

- **Instance.** Reads `%APPDATA%\levilauncher.exe\config.json` `base_root` if present, then
  `versions\<Version>\Minecraft Bedrock\Users\Shared\games\com.mojang`.
- **Source matching.** Map entry by pack UUID (mods by manifest name), else the manifest's
  project URL, else a same-named map entry (re-release), else a CurseForge search. Search needs
  `$env:CURSEFORGE_API_KEY` or the `curseforge` field on the Bitwarden item `api-keys` when
  `$env:BW_SESSION` is set.
- **Lookups.** CurseForge through `api.cfwidget.com` (up to 3 tries while it queues a project);
  GitHub through the latest-release API. Results are cached per URL.
- **Comparison.** By release date versus the manifest file's last-write time, because version
  strings are not comparable across sources.
- **`-Update`.** (1) Appends auto-matched packs to the `.psd1`, preserving comments, and restores
  the file if the edit stops it from parsing. (2) Downloads each outdated project once and
  unpacks `.mcaddon`/`.mcpack`/`.zip`, including nested archives. (3) Matches by UUID, then pack
  type plus name, then by being the only pack of that type. (4) Moves the old folder into the
  backup and copies the new one in; on copy failure restores the old folder. (5) Rewrites
  `world_*_packs.json` pack ids and versions, backing each file up first.

## Limitations

- Mods, `CHECK` URLs and `CANDIDATE` hits are never installed.
- A replacement that cannot be matched unambiguously is skipped with a warning.
- Dates only: a re-uploaded file with a newer date is reported `OUTDATED` even without a
  content change.
- Network lookups need internet access; failures show as `ERROR`.
