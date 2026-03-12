# Usage and Operations

This page focuses on day-to-day commands, service mode, and troubleshooting.

## Page Guide

**Who this page is for**

- Users running NilClaw day to day from the CLI or service mode
- Operators checking health, restarts, and post-change validation steps
- Troubleshooters narrowing down common startup, model, channel, or gateway issues

**Read this next**

- Open [Commands](./commands.md) if you need a fuller CLI reference beyond the common paths here
- Open [Security](./security.md) before exposing the gateway or widening allowlists and autonomy
- Open [Gateway API](./gateway-api.md) if your operational flow depends on pairing or webhook calls

**If you came from ...**

- [Installation](./installation.md): this page picks up after the binary is installed and ready for first-run checks
- [Configuration](./configuration.md): come here to validate config changes with runtime commands and troubleshooting steps
- [Commands](./commands.md): return here when you want the operational sequence, not just the raw command list

## First-Run Flow

1. Initialize:

```bash
nilclaw onboard --interactive
```

2. Send a test message:

```bash
nilclaw agent -m "hello nilclaw"
```

3. Start long-running gateway:

```bash
nilclaw gateway
```

## Command Quick Reference

| Command | Purpose |
|---|---|
| `nilclaw onboard --api-key sk-... --provider openrouter` | Quick setup for provider and API key |
| `nilclaw onboard --interactive` | Full interactive setup |
| `nilclaw onboard --channels-only` | Reconfigure channels and allowlists only |
| `nilclaw agent -m "..."` | Single-message mode |
| `nilclaw agent` | Interactive mode |
| `nilclaw gateway` | Start long-running runtime (default `127.0.0.1:3000`) |
| `nilclaw service install` | Install background service |
| `nilclaw service start` | Start background service |
| `nilclaw service status` | Check service status |
| `nilclaw service stop` | Stop background service |
| `nilclaw service uninstall` | Uninstall background service |
| `nilclaw doctor` | Run diagnostics |
| `nilclaw status` | Show global status |
| `nilclaw channel status` | Show channel health |
| `nilclaw channel start telegram` | Start a specific channel |
| `nilclaw migrate openclaw --dry-run` | Dry-run OpenClaw migration |
| `nilclaw migrate openclaw` | Execute OpenClaw migration |

## Service Mode Recommendations

For long-running deployments:

```bash
nilclaw service install
nilclaw service start
nilclaw service status
```

After significant config changes, restart service:

```bash
nilclaw service stop
nilclaw service start
```

## Gateway and Pairing

- Default gateway: `127.0.0.1:3000`
- Recommended: keep `gateway.require_pairing = true`
- For public access, prefer tunnel/reverse proxy over direct public bind

Health check:

```bash
curl http://127.0.0.1:3000/health
```

## FAQ

### 1) Startup fails with config error

Steps:

1. Run `nilclaw doctor` for exact error details.
2. Compare with `config.example.json` for key names and nesting.
3. Validate JSON syntax (commas, quotes, braces).

### 2) Model calls fail (401/403)

Common causes:

- API key invalid/expired.
- Provider mismatch (for example, wrong key for selected provider).
- Invalid model route format/string.

Checks:

```bash
nilclaw status
```

Then re-run onboarding:

```bash
nilclaw onboard --interactive
```

### 3) Channel receives no messages

Check:

- `channels.<name>.accounts.*` token/webhook/account settings.
- `allow_from` accidentally set to empty array.
- `nilclaw channel status` health output.

### 4) Gateway starts but is unreachable externally

Common causes:

- Still bound to `127.0.0.1`.
- Tunnel/reverse proxy not configured.
- Firewall port not opened.

## Post-Change Checklist

After config edits:

```bash
nilclaw doctor
nilclaw status
nilclaw channel status
nilclaw agent -m "self-check"
```

For gateway scenarios:

```bash
nilclaw gateway
curl http://127.0.0.1:3000/health
```

## Next Steps

- Open [Commands](./commands.md) for less common CLI flows and a broader command catalog
- Review [Security](./security.md) before moving from local-only operation to wider exposure
- Use [Gateway API](./gateway-api.md) when your operational checks include pairing or webhook integrations

## Related Pages

- [Installation](./installation.md)
- [Configuration](./configuration.md)
- [Commands](./commands.md)
- [Security](./security.md)
