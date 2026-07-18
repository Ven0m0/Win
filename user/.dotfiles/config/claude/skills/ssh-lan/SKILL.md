---
name: ssh-lan
description: Use whenever the user wants Claude to connect to, inspect, run commands on, or move files to/from a device on the local network via SSH - a Raspberry Pi, home server, NAS, router, or any other LAN box, whether referenced by a ~/.ssh/config alias, a raw IP (e.g. 192.168.1.x), or a hostname like "the pi" / "my nas" / "the server in the closet". Also use for discovering what's alive on the LAN, setting up key-based auth to a new device, or running the same check across several LAN hosts. Trigger even if the user doesn't say "SSH" explicitly - e.g. "restart the service on the pi", "grab the logs off my nas", "what's running on 192.168.1.50", "copy this file to my server".
---

# SSH / LAN device operations

Claude Code runs on Windows (Git Bash) with OpenSSH client tools already available:
`ssh`, `scp`, `ssh-keygen`, `ssh-keyscan`, `ssh-copy-id`. No `rsync`, no `nmap` - don't
suggest installing them, the tools below cover the same ground for LAN-scale work.

## 1. Resolve what host to talk to

- Check `~/.ssh/config` first (`cat ~/.ssh/config`) - if an alias already matches what
  the user means, use it (`ssh mynas`). Aliases carry the right user/key/port already.
- If the user gives a raw IP or hostname with no alias, just `ssh user@host` directly.
  Don't invent an alias unless the user is clearly going to reuse this host - see
  section 5.
- If the user refers to a device vaguely ("the pi", "my nas") and neither the config
  nor recent conversation makes it unambiguous, ask which host/IP rather than
  guessing - LAN IPs aren't guessable and a wrong guess just wastes a round trip.

## 2. Discover what's on the LAN

No `nmap` needed for a home/small LAN:

```bash
arp -a                                   # hosts this machine has already talked to
ping -n 1 -w 500 192.168.1.1             # single host liveness check (Windows ping)
```

For a full subnet sweep when `arp -a` isn't enough, loop `ping` over the range instead
of reaching for a scanner dependency:

```bash
for i in $(seq 1 254); do
  ping -n 1 -w 200 192.168.1.$i >/dev/null 2>&1 && echo "192.168.1.$i is up"
done
```

This is slow (~254 pings) - only do it when the user actually wants a sweep, not as a
default first step.

## 3. Run remote commands

Always pass non-interactive flags so a hung prompt doesn't stall the session:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=5 user@host 'command here'
```

- `BatchMode=yes` fails fast instead of hanging on a password prompt - if it fails
  with a permission/password error, that tells you key auth isn't set up yet (see
  section 5) rather than silently waiting.
- Quote the remote command as a single string; multiple remote commands chain with
  `&&` inside that string, not as separate `ssh` calls, to avoid repeated connection
  setup.
- First-time connection to a LAN IP prompts to accept the host key. That's expected
  and fine to accept for devices on your own LAN - it's `StrictHostKeyChecking`
  doing its job, not an error.

**Embedded / IoT devices (Raspberry Pi, routers, BusyBox-based systems):** don't
assume GNU coreutils or `bash` are present. Use plain `sh`-compatible commands
(`ls`, `cat`, `grep` without GNU-only flags). If a command errors as
"not found" on a device you haven't used before, that's a BusyBox/minimal-shell
signal, not a typo - simplify the command rather than adding flags.

**Before running anything destructive** (`reboot`, `shutdown`, `rm -rf`, firmware
flash/`dd`, service stop on something load-bearing) - confirm with the user first.
Everything else (status checks, log reads, restarting a single service, installing
a package) is fine to run directly.

## 4. Move files

`scp` handles both directions and is already installed:

```bash
scp user@host:/remote/path ./local/path      # pull
scp ./local/path user@host:/remote/path      # push
scp -r user@host:/remote/dir ./local/dir     # directory, recursive
```

If `scp` fails specifically on a minimal/BusyBox device (some embedded SSH servers
run `dropbear` without an `scp` binary), fall back to piping through `ssh` and `cat`:

```bash
ssh user@host 'cat /remote/path' > ./local/path      # pull
ssh user@host 'cat > /remote/path' < ./local/path    # push
```

## 5. Setting up key-based auth to a new device

Only do this when the user is clearly going to come back to this device repeatedly,
or asks for it directly - a one-off command doesn't need a permanent key or alias.

```bash
ssh-keygen -t ed25519 -C "device-name" -f ~/.ssh/id_ed25519_devicename -N ""
ssh-copy-id -i ~/.ssh/id_ed25519_devicename.pub user@host
```

Then add an alias to `~/.ssh/config` so future references ("the pi") resolve without
re-asking for user/IP:

```
Host mypi
    HostName 192.168.1.50
    User pi
    IdentityFile ~/.ssh/id_ed25519_devicename
```

## 6. Same command across several LAN hosts

For a handful of hosts, a plain loop is enough - don't reach for a fleet-management
tool for this:

```bash
for h in pi1 pi2 nas; do
  echo "== $h =="
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$h" 'uptime'
done
```

Use host aliases here so the loop stays readable; resolve/add them first (section 5)
if they don't exist yet.
