# L1 Gateway/Protocol Parity Verification Report

Status: **in progress (evidence-backed)**

This report consolidates L1 evidence that nilclaw's gateway/protocol surface
matches required OpenClaw production behavior for active clients.

## Scope

Required methods:
- `connect`
- `ping`
- `sessions.list`
- `agents.list`
- `chat.send`
- `chat.history`
- `models.list`

Required events:
- `connect.challenge`
- `chat` (delta/final/error streaming lifecycle)
- `chat.message`
- `sessions.update`

## Compatibility Evidence

### Implemented method/event surface
- Gateway method/event implementation exists in `src/gateway/gateway.lisp`.
- Method/event compatibility and envelope assertions are exercised in
  `tests/gateway-tests.lisp`.

### Envelope/field parity hardening
Current tests assert:
- snake_case + camelCase alias compatibility where required
- timestamp presence in relevant response/event envelopes
- content parity (`content-parts` and `contentParts` aliases)
- deterministic event ordering for `chat.send`
- reconnect/dedupe/ordering semantics in event stream tests

### Failure-mode parity
Current tests cover:
- malformed request rejection
- protocol type validation and mismatch handling
- invalid limit normalization for list/history endpoints
- chat error event emission path (`state=error`)

## Runtime validation snapshot

Latest validated baseline:
- `make test` => 593/593 pass
- `make traceability` => L0=28 L1=30 L2=24

## Remaining L1 closure work

- Final operator signoff pass against openclaw.el/openclaw-tui live call traces
  (method/event payload examples), then close L1 task gate.
- Keep this report updated if additional parity assertions are added.
