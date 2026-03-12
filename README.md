# NilClaw

[![CI](https://github.com/Kyvero-Vexus/nilclaw/actions/workflows/ci.yml/badge.svg)](https://github.com/Kyvero-Vexus/nilclaw/actions/workflows/ci.yml)
[![License: AGPL v3+](https://img.shields.io/badge/License-AGPL%20v3+-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

**Statically typed Common Lisp agent harness.**

NilClaw is a clean-room Common Lisp implementation of an AI agent harness, emphasizing:

- **SBCL strict type declarations** across the entire codebase
- **Coalton** for strongly typed core logic where appropriate  
- **Spec-driven development** from frozen behavioral specifications
- **Libre software** under **AGPL-3.0-or-later**

## Status

NilClaw is **migration-ready** for OpenClaw cutover.

| Gate | Status | Evidence |
|------|--------|----------|
| L0 | ✅ Closed | 838/838 tests passing |
| L1 | ✅ Closed | Protocol parity verified |
| L2 | ✅ Closed | All capabilities shipped |
| L3 | ✅ Closed | CI active, SLOs defined |
| L4 | ⏳ Ready | Awaiting user sign-off |

## Features

### Core Capabilities
- **Tool Execution Framework** — Registration, dispatch, iteration limiting, result plumbing
- **Provider HTTP Layer** — 429/backoff handling, error taxonomy, retry logic
- **ACP Subagent System** — Task management with concurrency limits, state tracking
- **Channel System** — CLI and Web adapters with permission system
- **Auto-Reply Engine** — Keyword/exact/regex matching, rate limiting, fallback responses

### Infrastructure
- **Configuration** — JSON-based with validation and provider runtime construction
- **Security Policy** — Sandboxed execution, permission controls
- **Memory System** — Contract-based storage with multiple backends
- **Cron Scheduling** — Periodic task execution
- **Gateway Protocol** — HTTP/WebSocket API for external clients

## Quick Start

### Prerequisites

- **SBCL** 2.5.2+ (Steel Bank Common Lisp)
- **Quicklisp** (Common Lisp package manager)

### Installation

```bash
# Clone the repository
git clone https://github.com/Kyvero-Vexus/nilclaw.git
cd nilclaw

# Install dependencies via Quicklisp
sbcl --load ~/quicklisp/setup.lisp \
     --eval '(ql:quickload (list :alexandria :cl-json :cl-ppcre :fiveam))'

# Load the system
make load

# Run tests
make test
```

### Basic Usage

```lisp
;; Load NilClaw
(asdf:load-system "nilclaw")

;; Create a channel manager
(defparameter *manager* (nilclaw/channel:make-channel-manager))

;; Register a CLI channel
(nilclaw/channel:register-channel *manager* "cli" 
  (nilclaw/channel:make-cli-channel))

;; Start all channels
(nilclaw/channel:start-all-channels *manager)
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Gateway API                         │
│              (HTTP/WebSocket Protocol)                   │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                    Agent Core                            │
│         (Session management, message routing)            │
└──┬──────────┬──────────┬──────────┬──────────┬──────────┘
   │          │          │          │          │
   ▼          ▼          ▼          ▼          ▼
┌─────┐  ┌─────────┐  ┌─────┐  ┌─────────┐  ┌─────┐
│Tools│  │Channels │  │ MCP │  │Provider │  │ ACP │
│     │  │CLI+Web  │  │     │  │  HTTP   │  │     │
└─────┘  └─────────┘  └─────┘  └─────────┘  └─────┘
   │          │          │          │          │
   ▼          ▼          ▼          ▼          ▼
┌─────────────────────────────────────────────────────────┐
│               Infrastructure Layer                       │
│  Config │ Security │ Memory │ Cron │ Auto-Reply         │
└─────────────────────────────────────────────────────────┘
```

### Modules

| Module | Purpose |
|--------|---------|
| `src/config/` | Configuration parsing, validation, provider runtime |
| `src/dispatcher/` | Tool call parsing, execution framework |
| `src/provider/` | HTTP transport, retry logic, error taxonomy |
| `src/channel/` | Channel adapters (CLI, Web), permissions, auto-reply |
| `src/subagent/` | ACP task management with concurrency limits |
| `src/memory/` | Contract-based storage backends |
| `src/security/` | Policy enforcement, sandboxing |
| `src/cron/` | Scheduled task execution |
| `src/gateway/` | HTTP/WebSocket protocol handler |

## Documentation

- **[Getting Started](docs/installation.md)** — Installation and first run
- **[Configuration](docs/configuration.md)** — Config reference
- **[Commands](docs/commands.md)** — CLI reference
- **[Architecture](docs/architecture.md)** — System design
- **[Gateway API](docs/gateway-api.md)** — HTTP API reference
- **[Security](docs/security.md)** — Security policy
- **[Development](docs/development.md)** — Contributing guide

## Testing

```bash
# Run full test suite
make test

# Validate traceability
make traceability

# Load system only
make load
```

Current test coverage: **838 tests, 100% pass rate**

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

All contributions must:
- Follow the KVC commit standard (see `docs/COMMITS.md`)
- Include GPG signature
- Pass all 838 tests
- Maintain traceability (L0=28, L1=30, L2=24)

## License

**AGPL-3.0-or-later**

This is libre software. See [LICENSE](LICENSE) for details.

## Credits

**NilClaw** is developed by [Kyvero Vexus](https://github.com/Kyvero-Vexus).

Inspired by the agent harness problem space, implemented as a clean-room Common Lisp solution with strict static typing.
