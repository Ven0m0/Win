---
name: nextcloud-remote
description: >
  Operate a Nextcloud server on another device (default: pi4, ssh alias `pi4`) and the
  local Windows sync client. Use for occ commands, app/config changes, log audits,
  updates, background jobs, Nextcloud Office/Collabora, the nginx/php-fpm/mariadb/redis
  stack, file scans and filecache repair, and desktop sync errors (case clashes, invalid
  filename, 400/403 on upload, sync-exclude.lst). Trigger without the word "Nextcloud"
  when the user means it: "my cloud", "the pi's files", "sync is broken", "office won't
  open docs", "ven0m0.dpdns.org", "check the server logs", "update the cloud".
---

# Nextcloud on a remote device

Connection rules (the `ssh-lan` skill is user-invocable only, so they are inlined here):
always `ssh -o BatchMode=yes -o ConnectTimeout=5 <host> '<cmd1> && <cmd2>'` (fail fast,
one round trip); pi4 has no SFTP subsystem, so transfer files with
`ssh pi4 'cat > path' < local` and `ssh pi4 'cat path' > local`, not `scp`.

Host facts for pi4 (paths, stack, known bugs, past fixes) live in `references/pi4.md`.
Read it before touching pi4; for any other host, discover them with section 1.

## 1. Orient first (one SSH round trip)

Nextcloud state drifts between sessions (updates, app changes, hand patches), so
re-check instead of trusting notes:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=5 pi4 'cd /var/www/nextcloud &&
  sudo -n -u www-data php occ status --output=json;
  sudo -n -u www-data php occ config:system:get datadirectory;
  sudo -n -u www-data php occ config:system:get logfile;
  systemctl is-active nginx php8.4-fpm mariadb redis-server 2>&1 | tr "\n" " "'
```

- Unknown host: locate the install with `ls -d /var/www/*/occ /var/www/html/occ` and
  the PHP version with `php -v`; the service names follow from that.
- Empty `logfile` means the default: `<datadirectory>/nextcloud.log`.
- If the version differs from `references/pi4.md`, an update happened - re-check the
  "after every update" items listed there.

## 2. Running occ

```bash
ssh -o BatchMode=yes pi4 'cd /var/www/nextcloud && sudo -n -u www-data php occ <cmd>'
```

- Always as the web-server user (`www-data`). Running occ as root creates root-owned
  cache/data files that later break the web process with permission errors.
- `sudo -n` fails fast instead of hanging on a password prompt, same reasoning as
  `BatchMode=yes`.
- Prefer `--output=json` and pipe to `jq` on the remote side, so only the answer
  comes back.
- Chain several occ calls in one SSH string with `;` or `&&` - each SSH setup costs a
  round trip.
- Interactive occ commands (`maintenance:install`, some `upgrade` prompts) need
  `--no-interaction` or `-n`.

Useful read-only commands: `status`, `app:list --shipped=false`, `config:list system`
(redacts secrets by default - never pass `--private`, it prints passwords),
`config:app:get <app> <key>`, `background-job:list`, `setupchecks`, `user:list`.
`files:scan` has no dry-run and `--all` rescans every user for a long time on a Pi;
scope it with `files:scan <user> --path=<user>/files/<dir>`.

## 3. Logs

`nextcloud.log` is one JSON object per line. Filter on the box, return summaries:

```bash
ssh pi4 'sudo -n tail -n 2000 /mnt/nextcloud-ssd/nextcloud.log |
  jq -r "select(.level>=3) | [.app,.message] | @tsv" | sed "s/[0-9]\{1,\}/N/g" |
  cut -c1-160 | sort | uniq -c | sort -rn | head -20'
```

Levels: 0 debug, 1 info, 2 warn, 3 error, 4 fatal. The `sed` collapses file ids and
paths so repeats of one error group together - one recurring error usually explains
dozens of lines. Then pull full entries (`.exception`, `.url`, `.user`) for the top
groups only.

Other sources worth checking together in a full audit: `/var/log/nginx/error.log`,
`/var/log/nginx/access.log` (real HTTP status for client errors that never reach
`nextcloud.log`), `journalctl -u php8.4-fpm -u mariadb -u coolwsd --since "1 day ago"`,
`dmesg | tail` (OOM kills).

## 4. Changing things safely

Most reads are safe to run directly. Confirm with the user before anything in this list,
because each can lose data or take the server down for all users:

- `maintenance:mode --on`, `upgrade`, `updater.phar`, `db:convert-*`
- `files:delete`, `trashbin:cleanup`, `versions:cleanup`, `user:delete`
- `app:remove` / `app:disable` on anything with stored data
- editing `config/config.php`, nginx vhosts, php-fpm pools, `coolwsd.xml`
- restarting mariadb or php-fpm during active syncs

Rules that come from real incidents on pi4:

- Back up any file before editing it: `sudo cp -a f f.bak-$(date +%F)`. Then validate
  (`php -l` for PHP, `nginx -t` for nginx) before reload.
- Change config through occ (`config:system:set`, `config:app:set`) rather than editing
  `config.php` by hand; occ writes atomically and keeps the file valid.
- Never `rm` inside the data directory. Nextcloud does not see the deletion and
  `oc_filecache` keeps orphaned rows. Use `occ files:delete` (goes to trashbin), or
  after an out-of-band change run `occ files:scan <user> --path=<user>/files/<dir>`
  or `occ files:cleanup`.
- Hand-patched core or app files are overwritten by every update. Record each patch in
  `references/pi4.md` under "Re-check after every update".
- Reload rather than restart where possible: `systemctl reload nginx php8.4-fpm`.

## 5. Updates

Check what is pending first: `occ app:update --showonly` for apps. `occ update:check`
only exists when the `updatenotification` app is enabled (it is not on pi4); otherwise
compare `occ status` against the latest release on nextcloud.com/changelog.
For core: `sudo -n -u www-data php updater/updater.phar --no-interaction` (add
`--no-backup` only when a separate backup exists), then `occ upgrade`,
`occ db:add-missing-indices`, `occ db:add-missing-columns`,
`occ db:add-missing-primary-keys`, `occ maintenance:repair --include-expensive`,
`occ setupchecks`. Afterwards run the post-update checks in `references/pi4.md`.

## 6. Windows desktop sync client (this machine)

Many "Nextcloud is broken" reports are client-side. Local facts:

- Config: `%APPDATA%\Nextcloud\nextcloud.cfg` (backed up automatically per client
  version), exclusions: `%APPDATA%\Nextcloud\sync-exclude.lst`, logs:
  `%APPDATA%\Nextcloud\logs\`.
- Sync journal: `.sync_<id>.db` (SQLite) in the root of each synced folder, e.g.
  `C:\Users\Ven0m0\Nextcloud\`. Its `blacklist` table holds items the client stopped
  retrying; clear the row after fixing the cause so the retry happens now.
- Check the client is running (`Get-Process nextcloud`) before debugging stalled sync -
  a stopped client once silently stalled sync for days.
- Map client errors to server causes: "invalid filename" / 400 on upload usually comes
  from `files_excludedirs`, case-clash files usually from `files_autorename`. Details
  and fixes are in `references/pi4.md`.
- Edit files that must land on the server through the synced folder, not over SSH, when
  the user wants the client to own the change (e.g. the Notes migration decision).

## 7. After the work

Nextcloud fixes on pi4 have been worth remembering every time. Update the vault notes
(`Projects/pi4-nextcloud-server.md` changelog and open items, or a new `Memory/` note
for a root-caused bug) and keep `references/pi4.md` in sync when a host fact changes
(version, paths, new hand patch, new gotcha).
