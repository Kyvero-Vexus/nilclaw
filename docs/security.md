# Security

NullClaw follows secure-by-default behavior: local bind by default, pairing auth, sandbox isolation, and least privilege.

## Page Guide

**Who this page is for**

- Operators hardening a local or tunneled NullClaw deployment
- Reviewers checking whether config or runtime changes widen trust boundaries
- Contributors touching gateway, tool, sandbox, or exposure-sensitive paths

**Read this next**

- Open [Configuration](./configuration.md) when you need the exact keys behind the controls summarized here
- Open [Gateway API](./gateway-api.md) if your security review includes pairing, bearer tokens, or webhooks
- Open [Usage and Operations](./usage.md) for day-to-day checks after a security-related config change

**If you came from ...**

- [Usage and Operations](./usage.md): this page explains the hardening context behind gateway and service recommendations
- [Configuration](./configuration.md): come here when a config key has security impact and needs policy-level interpretation
- [Architecture](./architecture.md): return here if a subsystem design decision crosses a security-sensitive boundary

## Baseline Controls

| Item | Status | How |
|---|---|---|
| Gateway not publicly exposed by default | Enabled | Defaults to `127.0.0.1`; refuses public bind without tunnel/explicit override |
| Pairing required | Enabled | One-time 6-digit pairing code, exchanged via `POST /pair` |
| Filesystem scope limits | Enabled | `workspace_only = true` by default |
| Tunnel-aware exposure | Enabled | Public access expected via Tailscale/Cloudflare/ngrok/custom tunnel |
| Sandbox isolation | Enabled | Auto-selects Landlock/Firejail/Bubblewrap/Docker |
| Secret encryption | Enabled | Credentials encrypted at rest with ChaCha20-Poly1305 |
| Resource limits | Enabled | Configurable memory/CPU/subprocess limits |
| Audit logging | Enabled | Optional audit trail with retention policy |

## Channel Allowlists

- `allow_from: []`: deny all inbound messages.
- `allow_from: ["*"]`: allow all sources (high-risk).
- Otherwise: exact-match allowlist.

## Nostr-specific Rules

- `owner_pubkey` is always allowed even if `dm_allowed_pubkeys` is stricter.
- Private keys are stored encrypted (`enc2:`), decrypted in memory only while the channel runs.

## Recommended Security Config

```json
{
  "gateway": {
    "host": "127.0.0.1",
    "port": 3000,
    "require_pairing": true,
    "allow_public_bind": false
  },
  "autonomy": {
    "level": "supervised",
    "workspace_only": true,
    "max_actions_per_hour": 20
  },
  "security": {
    "sandbox": { "backend": "auto" },
    "audit": { "enabled": true, "retention_days": 90 }
  }
}
```

## High-risk Settings

These settings significantly widen trust boundaries and should be used only in controlled environments:

- `autonomy.level = "full"`
- `allowed_commands = ["*"]`
- `allowed_paths = ["*"]`
- `gateway.allow_public_bind = true`

## Next Steps

- Review [Configuration](./configuration.md) before applying any high-risk setting listed on this page
- Use [Gateway API](./gateway-api.md) when you need endpoint-level auth and exposure details
- Run the checks in [Usage and Operations](./usage.md) after changing gateway, channel, or autonomy settings

## Related Pages

- [Configuration](./configuration.md)
- [Usage and Operations](./usage.md)
- [Gateway API](./gateway-api.md)
- [Architecture](./architecture.md)
