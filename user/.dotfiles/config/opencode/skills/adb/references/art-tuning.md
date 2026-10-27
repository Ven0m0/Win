# ART compiler filters, pm compile, and cleanup

Read this when the user wants apps faster, less RAM, "compile", "dexopt", or a phone cleanup.
Facts below were verified on the user's Android 16 phone (ART Service), not rooted.

## Contents
- Filters and which to pick
- pm compile syntax
- Pitfalls (verified)
- Verify
- Cleanup commands and what they really do
- Reusable script

## Filters and which to pick

| Filter | What it does | Use for |
|---|---|---|
| `verify` | No AOT code; interpreter + JIT | What profile-guided filters fall back to without a profile |
| `speed-profile` | AOT for hot methods from the profile + app image | Default for everything; GMS; rarely used apps |
| `speed` | AOT for nearly all methods, no app image, no profile needed | Daily apps without a profile |
| `everything-profile` | AOT for all methods + app image from the profile | Daily apps with a profile: best cold start |
| `everything` | Like speed plus rarely useful methods | Skip: bigger, no measurable gain over speed |

How to explain the RAM question honestly: the filter barely changes RAM. Background RAM is
mostly Java heap and native allocations, which no filter touches. AOT code is file-backed
clean pages the kernel can drop; JIT code is dirty anonymous memory, so more AOT means
slightly less dirty RAM. The real RAM lever is restricting background execution (see
SKILL.md).

The user's chosen setup: all packages `speed-profile`; about 28 daily apps
`everything-profile`, falling back to `speed` when there is no profile; GMS
`speed-profile` (huge, updated weekly, full AOT would cost hundreds of MB and get reset).

## pm compile syntax

```sh
pm compile [--full] [-r REASON] [-p PRIORITY] [-m FILTER] [-f] (-a | PACKAGE)
```

- One package per call, or `-a` for all. There is no multi-package syntax; loop on the device.
- `--full`: also secondary dex files and dependencies (matters for GMS modules).
- `-r cmdline -p PRIORITY_INTERACTIVE_FAST`: the user's standard flags.
- Without `-f`, ART skips a package whose current filter is already better or equal.
- App updates and OTA updates reset the filter. The user reruns the script after updates.
- `pm bg-dexopt-job` is roughly `compile -a -m speed-profile` with system flags. Don't run
  both back to back.

## Pitfalls (verified)

1. **`pm compile -a` aborts on the first leftover package** (uninstalled for the user with
   `pm uninstall -k`, APK gone): `Error: Unable to get package <pkg>`, and everything after it
   is skipped. On 2026-09-18 it stopped after 82 of 329. Loop over `pm list packages --user 0`
   instead, or remove the leftover entry after asking the user (see SKILL.md).
2. **Profile-guided filters without a profile fall back to `verify`** (no AOT code at all),
   and `pm compile` still prints `Success`. Always check the status afterwards. For
   `everything-profile` → `verify`, recompile with `speed`.
3. `eu.darken.sdmse` (SD Maid SE) stays `run-from-apk` and returns `Failure` on every compile;
   cause unknown. Report it; don't loop on it.
4. GMS always shows one `speed-profile` entry plus ~30 `verify` entries (secondary module
   dex). This is normal.
5. Compiling `com.android.systemui` can make the screen flicker or restart SystemUI.

## Verify

```sh
adb shell pm art dump <pkg>          # look for [status=...] on the base.apk line
adb shell 'for p in $(pm list packages --user 0 | cut -d: -f2); do s=$(pm art dump $p 2>/dev/null | grep -o "status=[a-z-]*" | head -1); echo "${s:-none} $p"; done' > status.txt
```

Then tally `status.txt`. Expected: overlays and resource packages show `none` or `unknown`
(no code); many system packages show `verify` (no profile); the tuned apps show their target.

Safe dry run for `-a`: `pm compile -a -r cmdline -m verify` without `-f` changes nothing
(every package already has a better or equal filter) and proves that `-a` gets through all
packages.

## Cleanup commands and what they really do

| Command | Effect |
|---|---|
| `sm fstrim` | TRIM on data partition. Fine. |
| `sm idle-maint run` | Triggers idle maintenance (fstrim, etc.). Fine. |
| `pm art cleanup` | Deletes ART artifacts of removed apps/dex files. Fine. |
| `pm trim-caches 999G` | Clears all internal app caches. Apps rebuild them; first launches are slower. |
| `rm -rf /sdcard/Android/data/*/cache/* .../code_cache/*` | External caches. Safe. |
| `am broadcast -a com.android.systemui.action.CLEAR_MEMORY` / `android.intent.action.ACTION_OPTIMIZE_DEVICE` | Not documented AOSP actions, but the user confirms they work, so the script keeps sending them. `result=0` only means "sent". |
| `rm /data/anr/* /data/tombstones/* /data/system/dropbox/*` | Needs root. Fails without root. |

On the user's phone the whole cleanup freed almost nothing (51 KB, then 0 bytes), so don't
promise gains from it.

## Reusable script

`~/project/Win/Scripts/optimize-android-art.ps1` (Win repo, Pester test in
`tests/optimize-android-art.Tests.ps1`) does cleanup → per-package `speed-profile` (every package except the
tuned lists, which the next step recompiles anyway) →
`everything-profile` with `speed` fallback for the tuned list → GMS `speed-profile` →
status table, exit 1 on unexpected status.

```powershell
pwsh -NoProfile -File ~/project/Win/Scripts/optimize-android-art.ps1                         # after OTA, ~5 min
pwsh -NoProfile -File ~/project/Win/Scripts/optimize-android-art.ps1 -SkipCleanup -SkipBase  # after app updates
pwsh -NoProfile -File ~/project/Win/Scripts/optimize-android-art.ps1 -WhatIf
```

To change which apps get full AOT, edit `$FullAotPackages` / `$ProfileOnlyPackages` at the top
of the script, then run its Pester test.
