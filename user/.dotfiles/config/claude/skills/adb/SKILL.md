---
name: adb
description: >
  Work with Android phones over adb from this Windows machine: device connection, package
  management (list, install, uninstall, debloat, restore), pm/cmd/dumpsys/settings/appops,
  logcat and crash diagnosis, file push/pull, background and RAM restrictions, and ART
  compiler-filter tuning (pm compile, speed/speed-profile/everything-profile, dexopt, cleanup).
  Use this skill whenever the user mentions adb, "adb shell", pm or cmd package commands,
  their phone or Android device, APKs, debloating, app compilation or dexopt, logcat, or wants
  to speed up, clean up, or inspect an Android phone, even without the word "adb".
---

# adb on this machine

The user's host is Windows 11 with adb in PATH. The usual device is a Nothing Phone
(model A142, codename Pacman, Android 16 / SDK 36, MediaTek), **not rooted**: `adb shell`
runs as `uid=2000(shell)`. Re-check with `adb devices -l` and `adb shell id` at the start of a
session because the device or root state can change.

For compiler filters, `pm compile`, and phone cleanup, read `references/art-tuning.md`.
A reusable script for that workflow lives at
`~/project/Win/Scripts/optimize-android-art.ps1`; prefer running it over retyping the loop.

## Start of every session

```sh
adb devices -l            # expect "device"; "unauthorized" = accept the prompt on the phone
adb shell getprop ro.build.version.sdk
```

- "no devices/emulators found": ask the user to connect USB or enable wireless debugging.
  Do not retry in a loop.
- Several devices: add `-s <serial>` to every command.
- Wireless: `adb pair <ip>:<pairport>` (code from phone), then `adb connect <ip>:<port>`.

## Shell quoting on Windows (the most common source of breakage)

Both the Bash tool (Git Bash) and PowerShell are available; they break adb commands in
different ways.

- **Git Bash path mangling.** MSYS rewrites arguments that look like POSIX paths:
  `adb shell ls /sdcard` or `adb push f.txt /sdcard/` sends `C:/Program Files/Git/sdcard`.
  Wrap the remote command in single quotes (`adb shell 'ls /sdcard'`) or prefix
  `MSYS_NO_PATHCONV=1` for push/pull.
- **Run loops on the device, in one adb call.** Single-quote the whole remote script in Bash
  so `$p` and `$(...)` expand on the phone, not locally:
  ```sh
  adb shell 'for p in $(pm list packages -3 | cut -d: -f2); do echo "$p"; done'
  ```
  One call with a device-side loop is far faster than one adb round trip per package.
- **PowerShell:** avoid double quotes inside the remote string (native argument quoting mangles
  them) and escape `$` with a backtick in double-quoted PowerShell strings. Under
  `$ErrorActionPreference = 'Stop'`, Windows PowerShell 5.1 throws on anything adb writes to
  stderr; set `'Continue'` around adb calls.
- Keep big outputs out of the conversation: redirect to a file in the scratchpad and grep,
  count, or diff it instead of printing hundreds of lines.

## Permissions without root

The shell user can: use `pm`, `cmd`, `am`, `dumpsys`, `settings`, `appops`, `logcat`, `sm`;
read and write `/sdcard` including `/sdcard/Android/data` (groups `ext_data_rw`,
`sdcard_rw`); write `/data/local/tmp`.

It cannot: read `/data/app`, `/data/data`, `/data/anr`, `/data/tombstones`,
`/data/system/dropbox`. Commands on those fail with "Permission denied". Say so up front
instead of running them, and offer the non-root alternative (`dumpsys dropbox`,
`logcat -b crash`, `bugreport`).

## Packages

| Task | Command |
|---|---|
| User apps / system apps | `pm list packages -3` / `pm list packages -s` |
| Installed for user 0 only | `pm list packages --user 0` |
| Include uninstalled-but-known | `pm list packages -u` |
| APK path, version, state | `pm path <pkg>`, `pm dump <pkg> \| grep -E "versionName\|installed="` |
| Install / update | `adb install -r app.apk`; split APKs: `adb install-multiple *.apk` |
| Debloat system app (reversible) | `pm uninstall --user 0 <pkg>` |
| Restore debloated system app | `cmd package install-existing <pkg>` |
| Disable instead of remove | `pm disable-user --user 0 <pkg>` / `pm enable <pkg>` |

Package names are easy to mistype (`aoo.` vs `app.`). Before acting on a name the user typed,
confirm it with `pm list packages <fragment>`.

**Leftover entries.** `pm list packages -u` minus `--user 0` shows packages uninstalled for
the user. System apps there still have their APK on /system and restore fine with
`install-existing`. A non-system app there (installer `com.android.vending` etc.) that was
removed with `pm uninstall -k` has no APK any more: `install-existing` throws
`NameNotFoundException`, and it breaks `pm compile -a`. The only fixes are reinstalling from
the store (keeps data) or a full `pm uninstall <pkg>` (deletes the kept data).

## Destructive commands: ask first

Ask before running any of these, and name what gets lost:

- `pm uninstall <pkg>` without `--user 0` on a user app, or on a leftover entry: deletes app
  data permanently.
- `pm clear <pkg>`: wipes all app data, including logins and local databases.
- `rm -rf` on `/sdcard/...`: no recycle bin.
- Anything that touches authenticators (Google Authenticator, Aegis, Bitwarden
  Authenticator), password managers, banking apps, or medical apps: data loss here can lock
  the user out of accounts. **`com.freestylelibre3.app.de` is a glucose sensor app.** Never
  restrict its background execution, battery, or notifications.

Caches are safe to delete: `pm trim-caches 999G` (all internal app caches) and
`/sdcard/Android/data/*/cache`, `code_cache`. Leave `files/cache` alone because some apps
keep real data there.

## Diagnostics

```sh
adb shell dumpsys meminfo <pkg>                      # PSS/RSS; compare before/after
adb shell dumpsys meminfo | head -60                 # top processes by PSS
adb shell dumpsys battery; adb shell dumpsys batterystats <pkg>
adb logcat -d -t 500 > log.txt                       # dump recent log, don't stream
adb logcat -d -b crash                               # crash buffer, no root needed
adb shell 'logcat -d --pid=$(pidof <pkg>)'           # one app only
adb shell dumpsys dropbox --print | head -200        # ANR/crash records without root
adb bugreport bugreport.zip                          # full report, takes minutes
```

Never run `adb logcat` without `-d` in a tool call: it streams forever and hangs.

## Background, battery, RAM

| Task | Command |
|---|---|
| Block background execution | `cmd appops set <pkg> RUN_ANY_IN_BACKGROUND ignore` (`allow` to undo) |
| Standby bucket | `am set-standby-bucket <pkg> rare` (`active`/`working_set`/`frequent`/`rare`/`restricted`) |
| Doze whitelist | `cmd deviceidle whitelist +<pkg>` / `-<pkg>` |
| Kill app now | `am force-stop <pkg>` |
| Animation scales | `settings put global window_animation_scale 0.5` (also `transition_`, `animator_duration_scale`) |

Keep background restrictions off apps that must run in the background: authenticators and
password-manager autofill, GMS and microG (`app.revanced.android.gms`), weather widgets,
the launcher, the keyboard, WebView, and above all the Libre 3 sensor app.

## Files

```sh
MSYS_NO_PATHCONV=1 adb push local.txt /sdcard/Download/
MSYS_NO_PATHCONV=1 adb pull /sdcard/DCIM/Camera ./camera
adb shell 'du -sh /sdcard/Android/data/* | sort -h | tail -20'
```

## Reporting back

Report what actually happened, with numbers: packages succeeded vs. failed, bytes freed,
filter status after compiling, which commands were skipped and why (root, safety). Quote the
exact error line for failures. When a command "succeeded" but did nothing measurable (for
example `am broadcast` of an action no app listens to returns `result=0`), say so rather than
implying an effect.
