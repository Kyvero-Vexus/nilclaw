# Changelog

All notable changes to NilClaw will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- GitHub Pages documentation site
- Comprehensive user and agent-facing documentation

## [0.1.0] - 2026-03-12

### Added

#### Core Capabilities
- **Tool Execution Framework** — Registration, dispatch, iteration limiting, result plumbing
- **Provider HTTP Layer** — 429/backoff handling, error taxonomy, retry logic with Dexador backend
- **ACP Subagent System** — Task management with concurrency limits, state tracking, mutex-protected state
- **Channel System** — CLI and Web adapters with vtable protocol and permission system
- **Auto-Reply Engine** — Keyword/exact/regex matching, rate limiting, priority ordering, fallback responses

#### Infrastructure
- **Configuration System** — JSON parsing, validation, provider runtime construction
- **Security Policy** — Sandboxed execution, permission controls, allowlist/denylist
- **Memory System** — Contract-based storage with none, markdown, and LRU backends
- **Cron Scheduling** — Periodic task execution
- **Gateway Protocol** — HTTP/WebSocket API handler

#### Testing
- **838 tests** with 100% pass rate
- **Traceability validation** (L0=28, L1=30, L2=24)
- **E2E behavioral contracts** for channels, MCP, subagents

#### Documentation
- Architecture documentation
- Configuration reference
- API reference (Gateway API)
- Installation guide
- Security guide
- Development guide

### Migration Readiness

| Gate | Status | Evidence |
|------|--------|----------|
| L0 | ✅ Closed | 838/838 tests passing |
| L1 | ✅ Closed | Protocol parity verified, live call-trace signoff |
| L2 | ✅ Closed | All 5 capability children complete |
| L3 | ✅ Closed | CI active, SLOs defined, rollback drill passed |
| L4 | ⏳ Ready | Runbook complete, awaiting user sign-off |

### Technical Details

#### Type System
- SBCL strict type declarations throughout
- Structure slots with explicit types
- Function type declarations (ftype)
- Safety 3 optimization default

#### Error Handling
- Common Lisp condition system
- Custom condition types for domain errors
- Error-protected tool execution

#### Thread Safety
- Mutex-protected subagent manager state
- Thread-safe hash tables for task tracking

### Commits

- `3384765` docs(cutover): Add L4 cutover runbook and final checklist
- `4795fc3` docs(ops): Add L3 ops hardening report
- `385c954` feat(channel): Add auto-reply system for web channels
- `dfe4040` feat(channel): implement channel system infrastructure
- `7e305fa` feat(subagent): Add ACP task management subsystem
- `961d325` feat(provider): Add optional Dexador HTTP backend
- `a445ac2` feat(config): Add provider runtime construction from config
- `c908ac0` feat(provider): Add HTTP transport layer with 429 backoff
- `fee756e` feat(dispatcher): Add tool execution runtime
- `97cdc85` docs(provider): Add L2 HTTP parity plan
- `721bfda` feat(config): add gateway runtime flag parity + validation
- `6650ee0` docs(gateway): Add L1 protocol parity verification report

---

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 0.1.0 | 2026-03-12 | Initial migration-ready release |

---

[Unreleased]: https://github.com/Kyvero-Vexus/nilclaw/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Kyvero-Vexus/nilclaw/releases/tag/v0.1.0
