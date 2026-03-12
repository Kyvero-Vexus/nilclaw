---
Layer: L1
Lane: operations
Spec ID: L1-ADP-usage
Status: draft
Last Updated: 2026-03-10
Traceability:
  L0: [F-UI-CLI, F-AGENT-SCHEDULING, C-SAFE-EXTERNAL-ACTION-GATING]
---

# Usage and Operations Specification (Adapted from NilClaw docs)

> Frozen reference — do not modify. Source: NilClaw docs/en/usage.md

## Overview

Covers day-to-day operation: first-run flow, service mode, gateway/pairing,
and troubleshooting.

## First-Run Flow

1. Run interactive onboarding to generate initial config.
2. Send a test message in single-message mode.
3. Start the long-running gateway.

## Operational Modes

### Single-Message Mode
Send one prompt, get one response, exit. Useful for scripting and quick checks.

### Interactive Mode
Start a persistent chat session in the terminal.

### Gateway Mode
Long-running process that listens for inbound messages from channels and
webhooks. Default bind: `127.0.0.1:3000`.

### Service Mode
Install as a system service for persistent deployment. Supports
install/start/stop/restart/status/uninstall lifecycle.

Recommendation: restart service after significant config changes.

## Gateway and Pairing

- Default endpoint: `http://127.0.0.1:3000`
- Pairing: one-time 6-digit code exchange at `POST /pair`
- Health check: `GET /health`
- For public access, use tunnel or reverse proxy — not direct public bind.

## Troubleshooting

### Config errors at startup
1. Run diagnostics for exact error details.
2. Compare with example config for key names and nesting.
3. Validate JSON syntax.

### Model call failures (401/403)
- API key invalid or expired
- Provider mismatch (wrong key for selected provider)
- Invalid model route format

### Channel receives no messages
- Check token/webhook/account settings
- Check `allow_from` is not empty array
- Check channel health status

### Gateway unreachable externally
- Still bound to `127.0.0.1`
- Tunnel/reverse proxy not configured
- Firewall port not opened

## Post-Change Validation Checklist

After config edits, run in order:
1. Diagnostics check
2. Status check
3. Channel health check
4. Test message
5. Gateway health endpoint (if applicable)
