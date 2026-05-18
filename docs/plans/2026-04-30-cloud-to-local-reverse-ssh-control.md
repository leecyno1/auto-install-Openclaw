# Cloud-to-Local Reverse SSH Control Design

## Summary

When OpenClaw or Hermes runs on a cloud machine, it should not directly expose a local user's computer, desktop, or OpenClaw Gateway to the public internet. The recommended design is a local-initiated reverse SSH tunnel: the local machine dials out to the cloud host, the cloud agent connects back through a localhost-only port, and a forced-command gate on the local side restricts execution to a small whitelist.

This design supports command-level control only. It intentionally does not provide a full interactive shell, full desktop control, or public access to local services by default.

## Goals

- Let a cloud-hosted OpenClaw/Hermes instance trigger safe operations on a local machine.
- Work when the local machine is behind NAT or a corporate/home router.
- Avoid opening inbound firewall ports on the local network.
- Avoid exposing `~/.openclaw`, `~/.hermes`, SSH keys, browser sessions, or desktop control by default.
- Keep the feature opt-in: normal OpenClaw/Hermes installation only installs helpers when explicitly requested.

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

Current whitelist in `scripts/remote-local-control.sh`:

| Action | Local behavior |
| --- | --- |
| `status` | Return hostname, current user, and OS. |
| `openclaw-status` | Run safe OpenClaw status checks only. |
| `tail-log gateway|health|quota` | Print the last lines from approved logs. |
| `run-maintenance openclaw-doctor` | Run the predeclared OpenClaw doctor task. |
| `desktop-create-folder <safe-folder>` | Create one safe leaf folder on the local Desktop, or `~/OpenClawRemoteDesktop` when Desktop is absent. |
| `desktop-write-article <safe-folder> <safe-file.md|txt> <base64-content>` | Write base64-decoded article content into the safe Desktop folder. |
| `sync-inbox` | Rejected until explicitly implemented. |

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

1. On the cloud host, install the helper with `openclaw-setup config --remote-local-control`.
2. On the cloud host, create a key pair dedicated to local reverse-control operations.
3. On the cloud host, install the wrapper with `~/.openclaw/remote-local-control.sh install-cloud --identity ~/.ssh/openclaw-local-control --apply`.
4. After first registration, the website/control plane should generate a pairing JSON for the user.
5. On the local machine, run `~/.openclaw/remote-local-control.sh configure-local --pairing-file <pairing.json> --install-service`.
6. On the cloud host, run `openclaw-local-run status`.
7. Confirm the cloud port is localhost-only.

Recommended pairing JSON fields:

```json
{
  "cloudSshTarget": "root@203.0.113.10",
  "cloudSshPort": 5945,
  "reversePort": 24022,
  "cloudPublicKey": "ssh-ed25519 AAAA... openclaw-local-control"
}
```

The local helper resolves the cloud address in this order: explicit CLI flags, `OPENCLAW_REMOTE_LOCAL_PAIRING_FILE`, environment variables such as `OPENCLAW_REMOTE_LOCAL_CLOUD`, then interactive prompt. The local installer cannot reliably discover the newest server address by itself; the control plane must provide it through the registration result, a pairing file, or a copyable command.

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

Implemented integration order:

1. Normal installation remains unchanged and disabled.
2. `openclaw-setup config --remote-local-control` installs the standalone helper script only.
3. `configure-local` or `bootstrap-local` must be run explicitly on the local machine to install the forced-command gate and start the tunnel.
4. `configure-local --pairing-file` is the preferred path after website registration because it carries the latest cloud SSH target, SSH port, reverse port, and cloud public key.
5. `install-tunnel-service` can optionally install a macOS LaunchAgent or Linux systemd user service for tunnel recovery.

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

## Current Implementation

The implemented helper is `scripts/remote-local-control.sh`. It remains opt-in and separate from normal installation. The installer/config menu copies it into `~/.openclaw/remote-local-control.sh`; it does not silently enable a tunnel.

Use `configure-local --pairing-file` on the user's local machine for the preferred active setup path, or `bootstrap-local` when the cloud address and public key are supplied manually. Use `install-tunnel-service` only when the user wants persistence through macOS LaunchAgent or Linux systemd user services. Do not add automatic enablement to the main installer unless the command gate, logging, revocation, and recovery behavior have been tested in the target deployment environment.
