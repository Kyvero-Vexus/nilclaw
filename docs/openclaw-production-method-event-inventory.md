# OpenClaw Production Method/Event Inventory (L0 Denominator)

Status: in progress
Updated: 2026-03-11 04:02 UTC

## Source scope used for this denominator

- `openclaw.el/openclaw.el` gateway request/event usage in production UI paths
- `openclaw.el/docs/openclaw-tui-spec.md` event/method surface expected for TUI parity
- Nilclaw gateway/runtime method handlers and tests

This inventory converts the remaining L0 parity blocker into a finite line-item denominator for production-used method/event semantics.

## Required methods/events from openclaw.el

| Surface | Method/Event | Observed usage in openclaw.el | Nilclaw implementation/test evidence | Coverage status | Gap |
|---|---|---|---|---|---|
| Handshake | `connect` | Initial authenticated handshake on websocket open | `src/gateway/gateway.lisp` (`handle-connect`), `tests/gateway-tests.lisp` (`gateway-connect-*`, `gateway-full-handshake-flow`) | Pass-backed | Need explicit field-level parity checks vs OpenClaw challenge payload metadata |
| Keepalive | `ping` | Periodic keepalive + liveness checks | `src/gateway/gateway.lisp`, `tests/gateway-tests.lisp` (`gateway-ping-returns-pong`, request validation) | Pass-backed | None at method level |
| Sessions | `sessions.list` | Session picker/list/bootstrap refresh | `src/gateway/gateway.lisp`, `tests/gateway-tests.lisp` (`gateway-sessions-list-*`) | Pass-backed | Add parity assertion for optional sort/filter semantics if required by clients |
| Agents | `agents.list` | Agent picker/list | `src/gateway/gateway.lisp`, `tests/gateway-tests.lisp` (`gateway-agents-list-*`) | Pass-backed | None on core method contract |
| Chat send | `chat.send` | Primary message send + slash command transport | `src/gateway/gateway.lisp`, `tests/gateway-tests.lisp` (`gateway-chat-send-*`, ordering tests), `tests/agent-root-tests.lisp` | Pass-backed | Expand to strict response envelope + metadata parity |
| Chat history | `chat.history` | Session history fetch on switch/refresh | `src/gateway/gateway.lisp`, `tests/gateway-tests.lisp` (`gateway-chat-history-*`) | Pass-backed | Add parity assertions for timestamp/content part shape with OpenClaw payload forms |
| Models | `models.list` | Model picker | `src/gateway/gateway.lisp`, `tests/gateway-tests.lisp` (`gateway-models-list-*`) | Pass-backed | Confirm optional model metadata fields required by openclaw.el UI |
| Event | `chat.message` | Incoming message event handling; streaming duplicate suppression path | Emitted by gateway (`src/gateway/gateway.lisp`), tested in `tests/gateway-tests.lisp` (`gateway-chat-send-emits-events`, ordering tests) | Pass-backed | Add explicit event envelope parity assertions (`role/content/timestamp` shape) |
| Event | `sessions.update` | Session list refresh trigger on updates | Emitted by gateway, tested in `tests/gateway-tests.lisp` (emit/order checks) | Pass-backed | Add client-facing semantic parity for update payload fields |
| Event | `chat` | Streaming lifecycle event consumed by TUI/openclaw.el (`state=delta|final|error` + `message.content`) | Implemented in `src/gateway/gateway.lisp` (`handle-chat-send` emits `event:"chat"` frames with `state=delta`, `state=final`, and explicit `state=error` on internal failures). Verified by `tests/gateway-tests.lisp` (`gateway-chat-send-emits-chat-streaming-events`, `gateway-chat-send-emits-chat-error-event`) | Pass-backed | Next depth: strict envelope parity assertions for timestamp/content-part shape across all lifecycle states |
| Event stream semantics | ordering/dedupe/reconnect replay | openclaw.el handles streaming/reconnect state | `tests/gateway-tests.lisp` stream tests (`stream-emit-*`, `stream-replay-*`, `stream-dedupe-*`) | Pass-backed | Tie stream semantics to exact openclaw.el expectations for state transitions |

## Method/event denominator summary

- Production-used methods identified from openclaw.el + TUI parity spec: **7**
- Production-used events identified from openclaw.el + TUI parity spec: **3**
- Cross-cutting stream semantics clusters: **1**
- Total denominator line-items in this inventory: **11**

Current status against denominator:
- Pass-backed: **11/11**
- Remaining work is now parity depth/hardening (field-level/event-envelope strictness, especially timestamp/content-shape assertions and cross-client envelope fidelity checks).

## Notes

- This inventory now includes openclaw.el runtime usage plus TUI parity-spec surface audit.
- Audit result: no additional RPC methods beyond existing set; the additional required event surface (`event:"chat"` streaming lifecycle) is now implemented and test-backed.
- Next denominator move: assert strict envelope field parity (`sessionKey`, content-part shape, timestamp semantics) for all pass-backed event/method items, including explicit `state=error` streaming semantics.
