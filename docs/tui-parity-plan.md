# NilClaw TUI Parity Plan

## Reference Documents
- OpenClaw TUI spec: `openclaw.el/docs/openclaw-tui-spec.md`
- OpenClaw TUI user docs: `openclaw/docs/web/tui.md`

## Current State (Pre-Parity)
- Basic `tui-client` (remote, stub) and `local-tui-client` (in-process) structs
- Simple REPL loop with `/history` and `quit` commands
- No slash command surface beyond `/history`
- No agent/model/session switching or state tracking
- No status footer or connection state display
- No toggles (deliver, think, verbose, reasoning)
- Minimal history rendering (role only, no timestamps)

## Parity Gap Analysis

| Feature | OpenClaw TUI | NilClaw Status | Phase |
|---------|-------------|----------------|-------|
| `/help` | Shows commands | Missing | 1 |
| `/status` | Session/connection info | Missing | 1 |
| `/sessions` | List sessions | Missing | 1 |
| `/session <key>` | Switch session | Missing | 1 |
| `/agents` | List agents | Missing | 1 |
| `/agent <id>` | Switch agent | Missing | 1 |
| `/models` | List models | Missing | 1 |
| `/model <id>` | Set model | Missing | 1 |
| `/new` / `/reset` | Reset session | Missing | 1 |
| `/deliver <on\|off>` | Toggle delivery | Missing | 1 |
| `/think <level>` | Set thinking level | Missing | 1 |
| `/verbose <on\|full\|off>` | Set verbose mode | Missing | 1 |
| `/reasoning <on\|off\|stream>` | Set reasoning mode | Missing | 1 |
| `/exit` | Exit TUI | Missing | 1 |
| `/abort` | Abort active run | Missing | 1 |
| Agent/session/model state | Footer display | Missing | 1 |
| History w/ role+timestamp | `[HH:MM] role> text` | Partial | 1 |
| Status footer line | Connection+agent+session+model+toggles | Missing | 1 |
| `/context` | Show context info | Missing | 2 |
| `/usage` | Token usage display | Missing | 2 |
| `/elevated` | Elevated mode | Missing | 2 |
| `/activation` | Activation mode | Missing | 2 |
| `/settings` | Settings panel | Missing | 2 |
| `!` shell commands | Local shell exec | Missing | 2 |
| Streaming updates | In-place content update | Missing | 2 |
| Pickers (Ctrl+L/G/P) | Interactive overlays | Missing | 3 |
| Tool output cards | Collapsible tool cards | Missing | 3 |
| WebSocket remote client | Full WS transport | Missing | 3 |
| Reconnection handling | Auto-reconnect | Missing | 3 |
| Token count display | Footer token counts | Missing | 3 |

## Phase 1: Command Surface + State + Display (This PR)

### Scope
1. **Slash command surface** (16 commands): `/help`, `/status`, `/sessions`,
   `/session <key>`, `/agents`, `/agent <id>`, `/models`, `/model <id>`,
   `/new`, `/reset`, `/deliver`, `/think`, `/verbose`, `/reasoning`, `/exit`, `/abort`
2. **TUI state tracking**: current-agent, current-model, deliver, think-level,
   verbose-mode, reasoning-mode on `local-tui-client`
3. **Status footer**: connection state + agent + session + model + toggles
4. **History rendering**: `[HH:MM] role> content` format with timestamps
5. **Tests**: unit tests for all slash commands, state transitions, rendering

### Acceptance Criteria
- [ ] All 16 slash commands dispatch correctly and produce expected output
- [ ] State toggles persist across commands within a session
- [ ] `/status` displays current agent, session, model, and toggle states
- [ ] History shows `[HH:MM] role> content` format
- [ ] Status footer renders after each interaction
- [ ] All new tests pass
- [ ] No regressions in existing tests

## Phase 2: Extended Commands + Shell + Streaming
- `/context`, `/usage`, `/elevated`, `/activation`, `/settings`
- `!` local shell command execution
- Streaming in-place updates for assistant responses
- Token usage tracking and display

## Phase 3: Interactive UI + Remote Transport
- Picker overlays (model, agent, session)
- Tool output card rendering (collapsed/expanded)
- Full WebSocket remote client implementation
- Reconnection with event replay
- Keyboard shortcuts (Ctrl+L/G/P/T/O)
