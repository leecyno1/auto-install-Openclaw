# Cloud-to-Local Reverse SSH Control Design

## Summary

When OpenClaw or Hermes runs on a cloud machine, it should not directly expose a local user's computer, desktop, or OpenClaw Gateway to the public internet. The recommended design is a local-initiated reverse SSH tunnel: the local machine dials out to the cloud host, the cloud agent connects back through a localhost-only port, and a forced-command gate on the local side restricts execution to a small whitelist.

This design supports command-level control only. It intentionally does not provide a full interactive shell, full desktop control, or public access to local services by default.

## Goals

- Let a cloud-hosted OpenClaw/Hermes instance trigger safe operations on a local machine.
- Work when the local machine is behind NAT or a corporate/home router.
- Avoid opening inbound firewall ports on the local network.
- Avoid exposing `~/.openclaw`, `~/.hermes`, SSH keys, browser sessions, or desktop control by default.
- Keep the initial deliverable as documentation and review guidance, not an automatic installer feature.

## Non-Goals

- No default public SSH exposure from the local machine.
- No default VNC/RDP/full GUI control.
- No default OpenClaw Gateway exposure beyond `127.0.0.1`.
- No unrestricted shell for the cloud agent.
- No automatic enablement during normal OpenClaw/Hermes installation.

## Recommended Architecture

```text
┌─────────────────────────────┐
│ Local computer              │
│                             │
│ local-agent SSH user        │
│ forced command gate         │
│ 127.0.0.1:22                │
└─────────────┬───────────────┘
              │ local initiates
              │ ssh -N -R 127.0.0.1:24022:127.0.0.1:22 cloud
              ▼
┌─────────────────────────────┐
│ Cloud computer              │
│                             │
│ 127.0.0.1:24022             │
│ openclaw-local-run wrapper  │
│ cloud OpenClaw/Hermes       │
└─────────────────────────────┘
```

The local computer starts and maintains the reverse tunnel:

```bash
ssh -N \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -R 127.0.0.1:24022:127.0.0.1:22 \
  cloud-user@cloud.example.com
```

The cloud side connects only to its own localhost:

```bash
ssh -p 24022 local-agent@127.0.0.1 status
```

## Security Model

### Local User

Create a dedicated local account such as `local-agent`. Do not use the primary desktop user. The account should have:

- no password login,
- no sudo by default,
- access only to specific directories or scripts,
- a forced command in `authorized_keys`,
- audit logging for every requested action.

Example `authorized_keys` entry on the local machine:

```text
command="/usr/local/bin/openclaw-local-command-gate",no-agent-forwarding,no-X11-forwarding,no-pty ssh-ed25519 AAAA... cloud-openclaw
```

### Forced Command Gate

`openclaw-local-command-gate` should read `SSH_ORIGINAL_COMMAND`, parse the first token as an action, validate all arguments, execute only approved commands, and log the result.

Initial whitelist:

| Action | Local behavior |
| --- | --- |
| `status` | Return hostname, OS, uptime, and agent version. |
| `openclaw-status` | Run safe OpenClaw status checks only. |
| `tail-log <name>` | Print the last lines from approved logs. |
| `run-maintenance <task>` | Run predeclared maintenance scripts by task name. |
| `sync-inbox` | Pull files from a local staging directory if explicitly enabled. |

Rejected by default:

- `bash`, `sh`, `zsh`, `python -c`, `node -e`, and arbitrary interpreters,
- file deletion outside approved maintenance scripts,
- access to `~/.ssh`, browser profiles, keychains, password stores, and API key files,
- port forwarding requested by the cloud side,
- interactive TTY allocation.

### Cloud Wrapper

Cloud OpenClaw/Hermes should call a wrapper, not raw SSH commands:

```bash
openclaw-local-run status
openclaw-local-run openclaw-status
openclaw-local-run tail-log gateway
```

The wrapper should:

- always connect to `127.0.0.1:<reverse_port>`,
- use a dedicated cloud-side identity key,
- pass a single whitelist action,
- apply command timeout,
- emit structured exit codes,
- avoid printing secrets from local output.

## Operational Flow

### First-Time Setup

1. On the cloud host, create a key pair dedicated to local reverse-control operations.
2. On the local machine, create `local-agent` and install the cloud public key with a forced command.
3. Install `openclaw-local-command-gate` on the local machine.
4. Start the reverse tunnel from local to cloud.
5. On the cloud host, run `openclaw-local-run status`.
6. Confirm the cloud port is localhost-only.

### Persistent Tunnel

For Linux local machines, run the reverse SSH command under a systemd user service or `autossh`. For macOS local machines, use a LaunchAgent or `autossh` installed through Homebrew.

Minimum reliability settings:

- `ExitOnForwardFailure=yes`
- `ServerAliveInterval=30`
- `ServerAliveCountMax=3`
- restart on failure through systemd, launchd, or autossh

### Port Binding Rule

Use:

```bash
-R 127.0.0.1:24022:127.0.0.1:22
```

Do not use:

```bash
-R 0.0.0.0:24022:127.0.0.1:22
```

The second form exposes the local SSH path to the internet if the cloud SSH server allows gateway ports.

## Relationship To OpenClaw/Hermes

This design is separate from the OpenClaw Gateway. The current installer keeps the Gateway local by default, which is the correct posture for cloud-to-local control.

Recommended integration order:

1. Keep this as documentation and manual review guidance.
2. If validated, add a standalone helper script, not a default install step.
3. If still useful, add an opt-in `openclaw-setup config remote-local-control` menu entry.
4. Keep the default installation unchanged and disabled.

Hermes and OpenClaw can both use the same cloud wrapper because the local bridge is SSH-based and command-level. The cloud runtime does not need to know whether the local machine runs OpenClaw, Hermes, or neither.

## Failure Modes And Mitigations

| Failure mode | Mitigation |
| --- | --- |
| Local network changes or sleeps | Use autossh/systemd/launchd restart; show stale tunnel status on cloud. |
| Cloud host compromised | Forced command, low-privilege local user, no TTY, no sudo, audit logs. |
| Key leaks | Dedicated key, easy revocation, no password fallback. |
| Port accidentally exposed | Bind reverse port to `127.0.0.1`; verify with `ss`/`lsof`. |
| Command injection | Parse actions strictly; reject shell metacharacters; avoid `eval`. |
| Secret leakage through logs | Log allowlist, redact env-like values, cap output length. |

## Validation Checklist

Run these checks before considering the setup usable:

```bash
# On cloud: port should listen on localhost only
ss -ltnp | grep 24022 || lsof -nP -iTCP:24022 -sTCP:LISTEN

# On cloud: allowed action works
ssh -p 24022 local-agent@127.0.0.1 status

# On cloud: shell access is blocked
ssh -p 24022 local-agent@127.0.0.1 bash
ssh -p 24022 local-agent@127.0.0.1 'cat ~/.ssh/id_rsa'
ssh -p 24022 -tt local-agent@127.0.0.1

# On local: audit log records all attempts
tail -50 /var/log/openclaw-local-command-gate.log
```

Acceptance criteria:

- `status` succeeds.
- unauthorized shell/file commands fail.
- the reverse port is not reachable from outside the cloud host.
- all attempts are logged locally.
- killing the tunnel process results in automatic recovery if persistence is enabled.

## Future Implementation Options

### Option A: Documentation Only

Keep the setup manual. This is the safest near-term path and is suitable before a public release.

### Option B: Standalone Script

Add a script such as `scripts/setup-local-reverse-ssh-control.sh` that generates the forced-command gate and service templates. The script remains opt-in and separate from normal installation.

### Option C: Config Menu Integration

Add an advanced menu entry after real-world validation. The menu should generate instructions and templates, not silently enable remote control.

## Recommended Default

Use Option A for now. If real users need it, implement Option B as a standalone opt-in script. Do not add automatic enablement to the main installer until the command gate, logging, revocation, and recovery behavior have been tested on both Linux and macOS.
