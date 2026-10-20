# pi4 Nextcloud server - host facts

Verified 2026-10-13. Re-verify with SKILL.md section 1 when anything looks off.
Full history: vault `Projects/pi4-nextcloud-server.md`.

## Host and stack

- SSH: alias `pi4` (192.168.178.81, user `dietpi`, key `~/.ssh/pi4`). Passwordless
  `sudo -n` works.
- OS: DietPi / Debian 13 (trixie), arm64. No SFTP subsystem, so `scp` fails - use
  `ssh pi4 'cat > path' < local`.
- Nextcloud 35.0.1 (updated 2026-10-13; DietPi 10.8.0, PHP 8.4.26) at `/var/www/nextcloud`, data dir `/mnt/nextcloud-ssd`, log at
  `/mnt/nextcloud-ssd/nextcloud.log` (logfile config unset, default location).
- Services: `nginx`, `php8.4-fpm`, `mariadb`, `redis-server`, `coolwsd`, `cloudflared`.
- Storage: despite the name, `/mnt/nextcloud-ssd` is a btrfs subvolume on a 1.8 TB USB
  **HDD** (TOSHIBA MQ04, `/dev/sda1`, also mounted whole at `/mnt/data`). Mount with
  `nossd`, never `ssd`. Previews are bind-mounted from the SD card
  (`/var/lib/nextcloud-preview`); MariaDB datadir is on the SD card
  (`/mnt/dietpi_userdata/mysql`) with `innodb_flush_log_at_trx_commit = 2` in
  `50-server.cnf` (chosen 2026-09-18: SD fsync per commit was the write bottleneck).
  `innodb_buffer_pool_size = 1G` since 2026-10-13 (was 512M; MariaDB 11.8 caps live resizing at
  `innodb_buffer_pool_size_max`, so a change needs a mariadb restart). Backup: `50-server.cnf.bak-2026-10-13`.
  btrfs scrub of `/mnt/data` ran clean 2026-10-13 (17 min, 125 GiB); no schedule set.
- Retention: `background_jobs_expiration_days=7` (NC34 `oc_job_runs` history, 60 days by
  default grew to 140k rows), `trashbin_retention_obligation="auto, 14"`.
- `recognize` was removed; its tables and config were dropped 2026-09-18. Backup:
  `/mnt/data/Backup/nextcloud-db-2026-09-18/`.
- Kernel cmdline (`/boot/firmware/cmdline.txt`) is hand-tuned (`mitigations=off`,
  `init_on_alloc=0`, THP `madvise`, ...). `threadirqs` was removed 2026-09-18. The USB HDD
  enclosure only supports Bulk-Only transport, so it cannot use UAS and a quirk would not
  help. zswap is off and zram is used instead.
- `/var/log` is a 25 MB tmpfs (DietPi RAMlog): nginx logs cover only the last hour or so.
  nginx access log uses `log_format timed` (combined + `$request_time` as last field).
- Remote tools present: `jq`, `sqlite3`, `mysql`, `python3`.
- Cron: `www-data` crontab, single `*/5 * * * * php -f /var/www/nextcloud/cron.php`.
  It was once duplicated (silent double run) - keep it at one line.
- Update script: `/usr/local/bin/nc-update` (repo copy dotfiles-pi `RaspberryPi/Scripts/nc-update.sh`),
  run by topgrade `[commands] "Nextcloud"` in `~/.config/topgrade.toml`. `NC_SKIP_CORE=1` = apps only.
- PHP ini overrides: `/etc/php/8.4/mods-available/dietpi-nextcloud.ini`
  (`memory_limit` 1024M).
- Users: `ven0m0` (main), `admin`, `jesper`.

## Network and Office

- Public name `ven0m0.dpdns.org`; TLS terminates at Cloudflare (`cloudflared` tunnel).
  nginx listens on `:80` locally.
- `/etc/hosts` maps `ven0m0.dpdns.org` to both `127.0.0.1` and `::1`. The `::1` line
  matters: coolwsd and richdocuments resolve IPv6-first, and without it they hit
  Cloudflare's public IPv6 and fail with `cURL error 7`.
- DNS resolver pinned to AdGuard (`94.140.14.14`, `94.140.15.15`) via
  `supersede domain-name-servers` in `/etc/dhcp/dhclient.conf`. The FritzBox resolver
  could not resolve the domain. For "server cannot reach its own domain", run
  `getent hosts ven0m0.dpdns.org` first.
- Nextcloud Office = native `coolwsd` package (Collabora `CODE-arm64-ubuntu1804` apt
  repo) on `127.0.0.1:9980`, chrooted and seccomp-filtered. nginx proxies
  `^/(?:browser|cool|hosting)` there. The old `richdocumentscode_arm64` AppImage app is
  gone; do not reinstall it.
- `wopi_url` must be a URL the browser can also load. richdocuments uses discovery's
  `urlsrc` verbatim as the editor iframe URL, so a `localhost` `wopi_url` breaks the
  browser even though server-side checks pass. Verify with
  `occ richdocuments:activate-config`.
- coolwsd admin password: not stored anywhere. Reset with
  `sudo coolconfig set-admin-password --user=admin --password=...`.

## Known app behaviors (root-caused)

- `files_excludedirs` matches bare rules (`logs`, `Backup`, `dist`, `build`, `env`,
  `venv`, `.cache`) against every path segment, on every storage. Symptom: client
  "invalid filename" or HTTP 400, `nextcloud.log` silent, message says "Dot files are
  not allowed". Check `occ config:app:get files_excludedirs exclude` and nginx
  access log. Client-side fix: since 2026-09-23 `sync-exclude.lst` ends with a commented
  mirror of the full server `exclude` list, so blocked names show as ignored rather than
  400. Update that block whenever the server list changes; clear stale journal
  `blacklist` rows. Vault: `Memory/nextcloud_files_excludedirs_...`.
- `files_autorename` lowercases every filename via per-user
  `/mnt/nextcloud-ssd/<user>/files/.rename.user.conf`. The rule carries
  `@ConflictKeepBothIfDifferent` and a `(?!CLAUDE\.md$)` exclusion; for `ven0m0` it is
  `(?!(?:CLAUDE|SKILL)\.md$)` since 2026-10-10. The `ven0m0` conf is synced by the desktop
  client (`C:\Users\Ven0m0\Nextcloud\.rename.user.conf`): edit it there, and re-check the
  last rule and annotation after every edit, they were silently lost once. Case-clash files on
  Windows mean this app re-triggered: look for `renamed_self` after `file_created` in
  `oc_activity`. Any case-changing rule needs an explicit conflict annotation.
  Since 2026-09-18 the group's first (trigger) line is
  `^(?!InstantUpload/)(?=.*[^a-z0-9._/-][^/]*$):` in all three user confs: renaming
  auto-uploads made the Android app re-upload them and show stale entries (slow deletes,
  deleted photos coming back). Rules match the path relative to `files/`, and a group only
  fires if its first pattern matches, so that line is where folder exemptions go.
  Vault: `Memory/nextcloud_files_autorename_...`.
- `duplicatefinder` runs with `disable_filesystem_events=true`; without it the app
  stalled every cron slot.
- `occ app:remove` refuses shipped apps (`suspicious_login`, `circles`,
  `files_downloadlimit`, `files_lock`, `related_resources`, `files_reminders`). Disabled
  is their intended final state.
- `CodeIntegrity: core/js/mimetypelist.js INVALID_HASH` is expected (apps regenerate
  that file). Not a defect.

## Re-check after every update

- `lib/private/Preview/Db/PreviewMapper.php`: hand patch aliases the WHERE columns as
  `p.file_id` (upstream nextcloud/server#63229). Check with
  `grep -n "p\.file_id" /var/www/nextcloud/lib/private/Preview/Db/PreviewMapper.php`.
  If missing and the log shows `Column 'file_id' in WHERE is ambiguous`, reapply - or
  drop the patch if upstream merged the fix. Present in 34.0.4 (2026-09-18) and still in 35.0.1 after the core update (2026-10-13).
- nginx vhost `/etc/nginx/sites-available/nextcloud`: static-asset locations are
  anchored to `^/nextcloud/.*\.(?:...)$`. Unanchored regexes route scanner probes into
  `index.php` and spam ERROR logs.
- `occ setupchecks` and a tail of `nextcloud.log` for new errors.

## Standing decisions

- Google Keep notes go into `C:\Users\Ven0m0\Nextcloud\Notes\` through the Windows
  desktop client, never server-side writes.
- Open item: an in-browser open/edit/save round trip of `.odt` and `.docx` through
  Nextcloud Office has never been confirmed.
