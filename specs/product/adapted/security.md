# Security Specification (Adapted from NullClaw docs)

> Frozen reference — do not modify. Source: NullClaw docs/en/security.md

## Overview

The system follows secure-by-default behavior: local bind, pairing auth,
sandbox isolation, and least privilege.

## Baseline Controls

| Control                            | Default State | Mechanism                                              |
|------------------------------------|---------------|--------------------------------------------------------|
| Gateway not publicly exposed       | Enabled       | Binds to `127.0.0.1`; refuses public bind without tunnel/override |
| Pairing required                   | Enabled       | One-time 6-digit code, exchanged via `POST /pair`      |
| Filesystem scope limits            | Enabled       | `workspace_only = true` by default                     |
| Tunnel-aware exposure              | Enabled       | Public access via Tailscale/Cloudflare/ngrok/custom    |
| Sandbox isolation                  | Enabled       | Auto-selects Landlock/Firejail/Bubblewrap/Docker       |
| Secret encryption                  | Enabled       | Credentials encrypted at rest with ChaCha20-Poly1305   |
| Resource limits                    | Enabled       | Configurable memory/CPU/subprocess limits              |
| Audit logging                      | Enabled       | Optional audit trail with retention policy             |

## Channel Allowlists

- `allow_from: []` — deny all inbound messages
- `allow_from: ["*"]` — allow all sources (high-risk)
- Otherwise — exact-match allowlist per sender identity

## Nostr-specific Rules

- `owner_pubkey` is always allowed even if `dm_allowed_pubkeys` is stricter.
- Private keys stored encrypted (`enc2:` prefix), decrypted in memory only
  while the channel is running.

## High-risk Settings

These settings significantly widen trust boundaries:

- `autonomy.level = "full"`
- `allowed_commands = ["*"]`
- `allowed_paths = ["*"]`
- `gateway.allow_public_bind = true`

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
