# pi4 Nextcloud server - host facts

Verified 2026-11-04. Re-verify with SKILL.md section 1 when anything looks off.
Full history: vault `Projects/pi4-nextcloud-server.md`.

## Host and stack

- SSH: alias `pi4` (192.168.178.81, user `dietpi`, key `~/.ssh/pi4`). Passwordless
  `sudo -n` works.
- OS: DietPi / Debian 13 (trixie), arm64. No SFTP subsystem, so `scp` fails - use
  `ssh pi4 'cat > path' < local`.
- Nextcloud 35.0.2 (seen 2026-11-03; 35.0.1 on 2026-10-13; DietPi 10.8.0, PHP 8.4.27 since 2026-11-03) at `/var/www/nextcloud`, data dir `/mnt/nextcloud-ssd`, log at
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
- `recognize` was removed 2026-09-18 (tables and config dropped; backup
  `/mnt/data/nextcloud-maint-backups/nextcloud-db-2026-09-18/`), but 13.2.0 was installed again
  by 2026-11-04. Since then: models downloaded, only `imagenet` (objects) and `landmarks` enabled,
  `nice_value=19`, faces/movinet/musicnn off. Native TensorFlow does not load on this arm64
  (`ERR_DLOPEN_FAILED` from `tfjs-node`), so `tensorflow.purejs` stays `true`. Recognize does
  tagging only, never OCR; OCR search is Findling (below).
- Previews (2026-11-04): `enabledPreviewProviders` is now an explicit list = the NC35 defaults
  (PNG JPEG GIF BMP XBitmap Krita WebP MarkDown TXT OpenDocument) plus `Movie` and `HEIC`;
  `preview_ffmpeg_path=/usr/bin/ffmpeg`. Preview Generator 5.15 runs on its default sizes. Coverage
  of ven0m0's `img-new` + `InstantUpload` is complete: 1716 images, 316 videos. Cron `PreviewJob`
  covers new uploads. Bulk run: `occ preview:generate-all -w 2 --path=/ven0m0/files/img-new
  --path=/ven0m0/files/InstantUpload` (leading slash required; run niced, about 20 min for the 8 GB of video).
  Set indexed config values from a script piped to `bash -s`: `OC\Preview\X` does not survive nested
  ssh quoting (it stored the literal text `OC\Preview$p` once).
- Maintenance backups (DB dumps, moved-out orphans) go to `/mnt/data/nextcloud-maint-backups/`,
  NEVER `/mnt/data/Backup/`: that is the `/Backup` external storage (group `shared`), so dumps
  there show up in ven0m0's synced folder. User asked for this 2026-11-03.
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
- Users: `ven0m0` (main), `admin`, `jesper`. Admin owns no files (2026-11-03): `img-new`
  and `InstantUpload` belong to ven0m0 and are shared to admin (share ids 2, 3).
  `InstantUpload` share is read-only (perms 17) since 2026-11-03 so admin's phone app cannot
  auto-upload duplicates into it. Legacy shares are not visible to NC35 `occ sharing:*`;
  edit them via `OCP\Share\IManager` in a `php` script run as www-data.
- Memories `timelinePath` for ven0m0 is `/img-new;/InstantUpload`. A path that does not
  exist makes `/apps/memories/api/days` return HTTP 500 ("Folder not found").
- NC35 `occ user:setting <u> <app> <key> <value>` fails on an existing string key with
  "conflict between new type (mixed) and old type (string)": `--delete` first, then set.

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

## Docker, HaRP and Findling (OCR / full-text search)

Added 2026-11-04. Findling Search (`findling` 1.6.1, app store) only holds the queue; indexing,
OCR (tesseract, de/en/fr) and embeddings run in the ExApp container `nc_app_findling_backend`
(`findling_backend` 1.6.1) that AppAPI deploys through HaRP. Recognize does not do OCR.

- Docker: Debian `docker.io` 26.1 (daemon only; the CLI is the separate `docker-cli` package).
  `/etc/docker/daemon.json` = `{"data-root":"/mnt/data/docker","log-driver":"local"}` (USB HDD,
  overlay2; not inside any Nextcloud mount), drop-in `docker.service.d/mounts.conf` with
  `RequiresMountsFor=/mnt/data`.
- Memory cgroup: Pi kernels disable it by default. `cgroup_enable=memory cgroup_memory=1` was
  appended to `/boot/firmware/cmdline.txt` (backup `.bak-2026-11-04`) and pi4 rebooted. AppAPI
  creates ExApp containers WITHOUT a memory limit (`HostConfig.Memory=0`), so the 2 GB cap is set
  by hand: `docker update --memory 2g --memory-swap 2g nc_app_findling_backend`. It is lost when
  AppAPI recreates the container (ExApp update or re-register): re-apply it then.
- HaRP: container `appapi-harp` (image `ghcr.io/nextcloud/nextcloud-appapi-harp:release`, arm64) on
  the user network `harp-net`, ports published to loopback only (`127.0.0.1:8780`, `:8782`),
  `--add-host ven0m0.dpdns.org:host-gateway`, `NC_INSTANCE_URL=http://ven0m0.dpdns.org/nextcloud`,
  shared key in `/root/harp.env` (mode 600; never print it; used again by `daemon:register`).
  Bridge layout on purpose: HaRP's host-network mode exposes Docker Engine control on
  `127.0.0.1:24000` to every local process.
- AppAPI daemon `harp_local` (default): host `localhost:8780` (occ runs on the host), NC url
  `http://ven0m0.dpdns.org/nextcloud`, `--net harp-net`, `--harp_frp_address appapi-harp:8782`.
  The FRP address must be the container name: with `localhost:8782` the ExApp's own frpc dials
  itself and loops on "connection refused" while `app:register --wait-finish` hangs.
- Nextcloud is served under `/nextcloud/`, and AppAPI builds ExApp URLs from the daemon NC url,
  so heartbeats hit `/nextcloud/exapps/<id>/heartbeat`. `snippets/nextcloud-body.conf` therefore has
  two locations proxying to `http://127.0.0.1:8780/exapps/`: `^~ /exapps/` and
  `^~ /nextcloud/exapps/` (backups `.bak-2026-11-04`, `.bak2-2026-11-04`). Without the second one
  AppAPI logs "Failed heartbeat ... 404" in a loop.
- HaRP counts unauthenticated requests per source IP (log line "Recorded failure for IP ..."), so do
  not curl `/exapps/<id>/...` by hand in a loop. The `Certificate update command failed ...
  Permission denied` lines in the HaRP log are harmless.
- Findling status: `occ findling:index` (its `indexed` is always 0, the backend counts that),
  `occ findling:diagnose <fileid|user:path>`, backend log `docker logs nc_app_findling_backend`
  (`pass finished, claimed=.. indexed=..`), queue tables `oc_findling_queue` (column `kind`:
  content -> ocr / embed hand-over; `scheduled` stays constant while rows move between kinds),
  `oc_findling_file_state`. First text pass ran ~45-115 files/min, memory 0.2 -> 1.1 GiB
  once the embedding model loaded.
- Install flow if it ever has to be redone: `occ app:enable app_api`, `docker network create
  harp-net`, run HaRP, add the two nginx locations, `app_api:daemon:register ... --set-default`,
  `app_api:app:register findling_backend --wait-finish` (run it detached with a log; it can exceed
  10 min), `app_api:app:enable findling_backend`, then `docker update` the memory limit.

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
- nginx `snippets/nextcloud-body.conf` must still contain `location ^~ /exapps/` and
  `location ^~ /nextcloud/exapps/` (HaRP). `docker ps` shows `appapi-harp` healthy and
  `nc_app_findling_backend` up with `HostConfig.Memory` = 2 GiB; `occ app_api:app:list` shows
  `findling_backend [enabled]`. Docker comes from apt (`docker.io` + `docker-cli`); both containers
  have `--restart unless-stopped`; `appapi-harp` came back by itself after the 2026-11-04 reboot
  (the backend was installed after that reboot, so its restart behaviour is untested).
- `occ setupchecks` and a tail of `nextcloud.log` for new errors.
- `occ status` must show `needsDbUpgrade:false`. An app update can crash in its own
  repair step (Memories 11.0.1, 2026-11-03: `BinExt::detectVips()` undefined, because the old class
  was still loaded in the same process). That aborts `nc-update` (`set -e`) and leaves the
  "update required" page up. Since 2026-11-03 `nc-update` handles this itself: after
  `app:update --all` it runs `occ upgrade --no-interaction` in a fresh process (exit 0 when nothing is pending).
  Old script: `/usr/local/bin/nc-update.bak-2026-11-03`.
- `occ db:schema:check` exits 1 only because of the `memories_*` indexes on `oc_filecache` and
  `oc_systemtag_object_mapping`, which are expected. If a table is missing but its migration is recorded, re-run that
  one step with a www-data php script:
  `(new \OC\DB\MigrationService($app, \OC::$server->get(\OC\DB\Connection::class)))->executeStep($ver)`
  (NC35 has no `migrations:execute`; `markAsExecuted` uses insertIfNotExist, so no oc_migrations edit is needed).
  Done for cloud_federation_api `1016Date202502262004` (`oc_federated_invites`) 2026-11-03.
- Setupcheck "Database configuration: 1 database check is failing" comes from the serverinfo DB advisor.
  The warning is `innodb_log_file_size` 96 MB < 128 MB (needs a `50-server.cnf` edit plus a mariadb restart; not done).
  Its notices include the deliberate `innodb_flush_log_at_trx_commit=2`. To list the rules: php script calling
  `Advisor::run(RuleSet\Mysql, DatabaseProbe::snapshot())`.

## Standing decisions

- Google Keep notes go into `C:\Users\Ven0m0\Nextcloud\Notes\` through the Windows
  desktop client, never server-side writes.
- No scheduled WebP/JXL conversion of photos (2026-11-03). Only ~5 GiB of images, and replacing them
  changes fileids and triggers re-uploads. Imagick has no JXL delegate. `preview_format` only affects
  Imaginary. Vault: `Memory/nextcloud_pi4_no_scheduled_image_conversion`.
- Open item: an in-browser open/edit/save round trip of `.odt` and `.docx` through
  Nextcloud Office has never been confirmed.
