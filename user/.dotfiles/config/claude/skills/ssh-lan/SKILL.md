---
name: ssh-lan
description: >
  Connect to, inspect, run commands on, or move files to/from a LAN device over SSH (Raspberry Pi, NAS,
  router, home server) by ~/.ssh/config alias, raw IP, or name like "the pi". Also LAN discovery, key-auth
  setup, and running one check across several hosts. Triggers without the word SSH, e.g. "restart the
  service on the pi", "grab logs off my nas", "copy this to my server".
---

# SSH / LAN device operations

Git Bash on Windows with `ssh`, `scp`, `ssh-keygen`, `ssh-keyscan`, `ssh-copy-id`. No `rsync`, no `nmap`: do not suggest installing them.

## 1. Pick the host

- Read `~/.ssh/config` first; use a matching alias (it carries user, key, port).
- Raw IP or hostname with no alias: `ssh user@host`. Create an alias only for hosts the user will reuse (section 5).
- Vague name ("the pi") that config and conversation do not resolve: ask for the host or IP. Do not guess.

## 2. Discover hosts

```bash
arp -a                          # hosts already talked to
ping -n 1 -w 500 192.168.1.1    # one host (Windows ping)
```

Full sweep (~254 pings, only on request):

```bash
for i in $(seq 1 254); do ping -n 1 -w 200 192.168.1.$i >/dev/null 2>&1 && echo "192.168.1.$i is up"; done
```

## 3. Run commands

```bash
ssh -o BatchMode=yes -o ConnectTimeout=5 user@host 'cmd1 && cmd2'
```

- `BatchMode=yes` fails fast instead of hanging on a password prompt; a permission error means key auth is not set up (section 5).
- Chain commands inside one quoted string with `&&`. One `ssh` call per host avoids repeated connection setup.
- First connection to a LAN IP asks to accept the host key. Accept it for the user's own devices.
- Embedded devices (Pi, routers, BusyBox): assume plain `sh` and no GNU-only flags. A "not found" on a new device means a minimal system, so simplify the command.
- Confirm with the user before anything destructive: `reboot`, `shutdown`, `rm -rf`, `dd`/flash, stopping a load-bearing service. Status checks, log reads, single-service restarts, and package installs run directly.

## 4. Move files

```bash
scp user@host:/remote/path ./local/path      # pull
scp ./local/path user@host:/remote/path      # push
scp -r user@host:/remote/dir ./local/dir     # directory
```

No `scp` binary on the device (dropbear): pipe through `ssh`.

```bash
ssh user@host 'cat /remote/path' > ./local/path
ssh user@host 'cat > /remote/path' < ./local/path
```

## 5. Key auth for a new device

Only for a device the user will return to, or on request.

```bash
ssh-keygen -t ed25519 -C "device-name" -f ~/.ssh/id_ed25519_devicename -N ""
ssh-copy-id -i ~/.ssh/id_ed25519_devicename.pub user@host
```

Then add to `~/.ssh/config`:

```
Host mypi
    HostName 192.168.1.50
    User pi
    IdentityFile ~/.ssh/id_ed25519_devicename
```

## 6. Same command on several hosts

```bash
for h in pi1 pi2 nas; do echo "== $h =="; ssh -o BatchMode=yes -o ConnectTimeout=5 "$h" 'uptime'; done
```

Use aliases so the loop stays readable; create missing ones first (section 5).
