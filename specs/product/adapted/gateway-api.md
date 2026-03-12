---
Layer: L1
Lane: contracts
Spec ID: L1-ADP-gateway-api
Status: draft
Last Updated: 2026-03-10
Traceability:
  L0: [F-UI-GATEWAY, F-CH-WEBHOOK, C-SEC-AUTH-BOUNDARY]
---

# Gateway API Specification (Adapted from NilClaw docs)

> Frozen reference — do not modify. Source: NilClaw docs/en/gateway-api.md

## Overview

The gateway exposes an HTTP API for health checks, pairing, and inbound
message delivery. Default endpoint: `http://127.0.0.1:3000`.

## Endpoints

| Endpoint    | Method | Auth                       | Description                    |
|-------------|--------|----------------------------|--------------------------------|
| `/health`   | GET    | None                       | Health check                   |
| `/pair`     | POST   | `X-Pairing-Code` header    | Exchange pairing code for bearer token |
| `/webhook`  | POST   | `Authorization: Bearer <token>` | Send message payload      |
| `/whatsapp` | GET    | Query params               | Meta webhook verification      |
| `/whatsapp` | POST   | Meta signature             | WhatsApp inbound webhook       |

## Pairing Protocol

1. System generates a one-time 6-digit pairing code.
2. Client sends `POST /pair` with `X-Pairing-Code: <code>` header.
3. Server responds with a bearer token.
4. All subsequent webhook calls use `Authorization: Bearer <token>`.

## Webhook Message Format

```json
{
  "message": "<text>"
}
```

Content-Type: `application/json`

## Security Guidance

1. Keep `gateway.require_pairing = true`.
2. Bind to loopback (`127.0.0.1`) and expose externally through tunnel/proxy.
3. Treat bearer tokens as secrets — do not commit or log them.
