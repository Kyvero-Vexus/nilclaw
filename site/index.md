---
layout: home
title: NilClaw Documentation
nav_order: 1
---

# NilClaw

**Statically typed Common Lisp agent harness.**

NilClaw is a clean-room Common Lisp implementation of an AI agent harness with strict static typing via SBCL declarations and optional Coalton integration.

## Quick Links

- [Installation](installation.html) — Install, run, and deploy
- [Getting Started](getting-started.html) — First steps with NilClaw
- [Configuration](configuration.html) — Configuration reference
- [API Reference](api-reference.html) — Gateway API documentation

## Features

{: .fs-6 .fw-300 }

### Core Capabilities

| Feature | Description |
|---------|-------------|
| **Tool Execution** | Registration, dispatch, iteration limiting, result plumbing |
| **Provider HTTP** | 429/backoff handling, error taxonomy, retry logic |
| **ACP Subagents** | Task management with concurrency limits and state tracking |
| **Channels** | CLI and Web adapters with permission system |
| **Auto-Reply** | Keyword/exact/regex matching, rate limiting, fallbacks |

### Infrastructure

| Feature | Description |
|---------|-------------|
| **Configuration** | JSON-based with validation and provider runtime construction |
| **Security** | Sandboxed execution, permission controls |
| **Memory** | Contract-based storage with multiple backends |
| **Cron** | Periodic task execution |
| **Gateway** | HTTP/WebSocket API for external clients |

## Status

{: .fs-4 .fw-300 }

| Gate | Status | Evidence |
|------|--------|----------|
| L0 | ✅ Closed | 838/838 tests passing |
| L1 | ✅ Closed | Protocol parity verified |
| L2 | ✅ Closed | All capabilities shipped |
| L3 | ✅ Closed | CI active, SLOs defined |
| L4 | ⏳ Ready | Awaiting user sign-off |

## License

AGPL-3.0-or-later. See [LICENSE](https://github.com/Kyvero-Vexus/nilclaw/blob/main/LICENSE).

## Credits

Developed by [Kyvero Vexus](https://github.com/Kyvero-Vexus).
