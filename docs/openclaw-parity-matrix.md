# OpenClaw ↔ Nilclaw Required-Path Parity Matrix (L0)

Status: in progress (blocking L0 closure)
Last updated: 2026-03-11 00:53 UTC

## Scope

Required production paths for cutover readiness:
- Sessions
- Chat
- Tools
- Cron
- Memory
- Agent runtime behavior

## Matrix (required semantics → nilclaw evidence)

| Path | Required semantics (OpenClaw-compatible) | Nilclaw evidence (tests) | Parity status | Gap / next action |
|---|---|---|---|---|
| Sessions | Request envelope validation, unknown command handling, spawn/send flow safety | `tests/agent-root-tests.lisp` (`agent-handle-request-behavior`), `tests/e2e-smoke-tests.lisp` (`e2e-subagent-system`) | Partial | Add explicit session lifecycle semantics (create/list/history/send error mapping) as executable tests; currently only command-dispatch-level behavior is proven |
| Chat | `chat.send` command success + malformed payload + unknown command mapping | `tests/agent-root-tests.lisp` (`agent-handle-request-behavior`), `tests/e2e-smoke-tests.lisp` (`e2e-agent-core`) | Partial | Add protocol-level chat response/event envelope parity (streaming chunks, terminal event codes, metadata fields) |
| Tools | Tool-call parse/dispatch, malformed payload handling, result formatting | `tests/agent-dispatcher-tests.lisp` (XML/JSON/native parsing + result formatting), `tests/e2e-smoke-tests.lisp` (`e2e-tool-system`) | Partial | Add parity cases for OpenClaw production tool protocol fields (id correlation + multi-tool ordering + tool error envelope semantics) |
| Cron | Due-task execution, retry on transient faults, terminal failure after retry budget, pending future tasks | `tests/cron-tests.lisp` (`cron-run-due-tasks-behavior`), `tests/e2e-smoke-tests.lisp` (`e2e-cron-heartbeat`) | Partial+ | Add production-equivalent backoff policy semantics (delay progression/jitter contract) and event/reporting parity |
| Memory | Shared backend contract basics/CRUD/recall/list/count/forget; noop + markdown append-only behavior | `tests/memory-contract-tests.lisp` (all 4 tests), `tests/e2e-smoke-tests.lisp` (`e2e-memory-system`) | Partial+ | Map OpenClaw memory_search/memory_get semantics and metadata/citation behavior to explicit nilclaw assertions |
| Agent runtime | Runtime entrypoint availability, command dispatch success/failure (`:malformed-request`, `:unknown-command`) | `tests/agent-root-tests.lisp` (both tests), `tests/e2e-smoke-tests.lisp` (`e2e-agent-core`, `e2e-streaming-voice`, `e2e-subagent-system`) | Partial | Extend from availability/dispatch to full protocol behavior parity for long-running subagent lifecycle and streaming/error edge cases |
| Gateway/protocol surface (supporting L0 breadth) | Ping happy-path, unknown method rejection, malformed request rejection | `tests/gateway-tests.lisp` (`gateway-handle-request-success-and-errors`), `tests/e2e-smoke-tests.lisp` (`e2e-gateway-control-plane`) | Partial | Add required production method matrix (openclaw.el/openclaw-tui used methods/events) with one-to-one test evidence |
| Provider failure modes (supporting L0 breadth) | Retry transient errors; stop on malformed payload | `tests/providers-compatible-tests.lisp` (`provider-complete-retries-transient-errors`, `provider-complete-stops-on-malformed-payload`), `tests/e2e-smoke-tests.lisp` (`e2e-provider-abstraction`) | Partial+ | Add explicit HTTP/auth/rate-limit/error-map parity against OpenClaw production adapter behavior |

## Objective evidence snapshot

- `make test` → 340/340 passing (2026-03-11 00:52 UTC)
- `make traceability` → `L0=28 L1=30 L2=24`

## Remaining L0 blocker statement

L0 denominator ambiguity is closed; current blocker is **breadth/depth protocol parity proof** against required OpenClaw production semantics (especially sessions/chat/tools event envelopes and agent runtime lifecycle semantics), expressed as explicit executable tests and/or linked implementation tasks.

## Immediate burn-down steps

1. Produce a required-method/event inventory for production-used session/chat/tool/gateway surfaces.
2. Bind each inventory line item to an existing nilclaw test ID; mark uncovered items explicitly.
3. For each uncovered semantics cluster, open discovered-from child issues under L0 and attach failing tests first.
4. Implement until matrix has no uncovered required semantics for L0 scope.
5. Re-run `make test` + traceability and attach evidence to beads issues.
