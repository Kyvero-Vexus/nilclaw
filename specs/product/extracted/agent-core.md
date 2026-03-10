---
Layer: L1
Lane: behavior-e2e
Spec ID: L1-EXT-agent-core
Status: draft
Last Updated: 2026-03-10
Traceability:
  L0: [F-UI-CLI, F-AGENT-SESSIONS, F-ROUTING-AGENT, C-SAFE-PRIORITY]
---

# Agent Core & Session Management Specification

## Overview

The agent core implements the conversational turn loop: receive user message,
inject system prompt, enrich with memory context, call the LLM provider,
parse tool calls, execute tools, and loop until a final text response is
produced. Sessions provide per-conversation state with persistence, idle
eviction, and thread-safe concurrent access.

## Session Management

### Session Structure

| Field             | Type      | Description                                |
|-------------------|-----------|--------------------------------------------|
| `agent`           | Agent     | Per-session Agent instance                 |
| `created_at`      | timestamp | Session creation time                      |
| `last_active`     | timestamp | Last message processing time               |
| `last_consolidated`| u64      | Timestamp of last compaction               |
| `session_key`     | string    | Unique session key (e.g., `"telegram:chat123"`) |
| `turn_count`      | u64       | Total turns processed                      |
| `turn_running`    | atomic bool| Whether a turn is currently executing     |
| `mutex`           | mutex     | Per-session lock for turn serialization    |

### Session Manager

The session manager maintains a map of session_key → Session.

#### Thread Safety Model
- `SessionManager.mutex` guards the sessions map (short hold times)
- `Session.mutex` serializes `turn()` per session (may be long)
- Different sessions are processed in parallel
- Same session processes turns serially via its own mutex

#### Session Lifecycle

1. **Create**: `getOrCreate(session_key)` — finds existing or creates new session
2. **Process**: Lock session mutex, run `agent.turn()`, update counters
3. **Evict**: `evictIdle(max_idle_secs)` — remove sessions idle beyond threshold
4. **Destroy**: `deinit()` — free all sessions

#### Session Key Format
Free-form string, typically `"<channel>:<peer_id>"` (e.g., `"telegram:chat123"`).

#### Session Persistence
When a session store is available:
- User and assistant messages are persisted after each turn (except slash commands)
- On session create, persisted history is restored
- Session-clearing commands (`/new`, `/reset`, `/restart`) clear both persisted
  messages and auto-saved memory entries for that session

### Message Processing Flow

```
processMessage(session_key, content, conversation_context)
  → getOrCreate(session_key)
  → session.mutex.lock()
  → set conversation_context on agent
  → optionally configure streaming adapter
  → agent.turn(content)
  → increment turn_count, update last_active
  → persist messages to session store (if available)
  → return response
```

### Slash Command Interception

Before reaching the LLM, messages starting with `/` are checked:
- `/new`, `/reset`, `/restart` — clear session (persisted messages + auto-saved memory)
- Slash commands handled directly return a response without calling the LLM
- Non-slash and unrecognized slash commands proceed to the turn loop

### Turn Interruption

External callers can request interruption of in-flight turns:
- Set `interrupt_requested` atomic flag
- The turn loop checks this flag before each tool execution
- Returns an interruption message listing any tools that were interrupted
- Active tool name is tracked under a separate mutex for snapshot access

### Usage Ledger

Token usage is recorded to a JSONL ledger file (`llm_token_usage.jsonl` in config dir).

Each record:
```json
{"ts": <unix_timestamp>, "provider": "<name>", "model": "<name>",
 "prompt_tokens": <n>, "completion_tokens": <n>, "total_tokens": <n>,
 "success": <bool>}
```

Rotation triggers (any one suffices):
- Time window expired (`token_usage_ledger_window_hours`)
- Byte limit exceeded (`token_usage_ledger_max_bytes`)
- Line count exceeded (`token_usage_ledger_max_lines`)

On rotation, the file is truncated and the new record is the first entry.

### Skills Reload

`reloadSkillsAll()` invalidates the system prompt on all active sessions
by clearing `has_system_prompt`. The prompt is rebuilt on the next turn.

## Agent Structure

### Key State

| Field                      | Type     | Description                              |
|----------------------------|----------|------------------------------------------|
| `provider`                 | Provider | LLM provider interface                   |
| `tools`                    | Tool[]   | Registered tool implementations          |
| `tool_specs`               | ToolSpec[]| Tool schemas for function-calling APIs  |
| `mem`                      | Memory?  | Optional memory backend                  |
| `bootstrap`                | BootstrapProvider? | Workspace file provider         |
| `model_name`               | string   | Active model identifier                  |
| `temperature`              | float    | LLM temperature                          |
| `history`                  | OwnedMessage[] | Conversation history (growable)    |
| `max_tool_iterations`      | u32      | Max tool loops per turn (default 25)     |
| `max_history_messages`     | u32      | Max non-system messages (default 50)     |
| `token_limit`              | u64      | Context window budget                    |
| `max_tokens`               | u32      | Max generation tokens                    |
| `auto_save`                | bool     | Auto-persist to memory                   |
| `has_system_prompt`        | bool     | Whether system prompt is injected        |
| `interrupt_requested`      | atomic bool | External interrupt flag               |
| `total_tokens`             | u64      | Cumulative tokens across all turns       |
| `last_turn_usage`          | TokenUsage | Usage from most recent turn           |

### Agent Mode Enums

| Category         | Values                                  | Default      |
|------------------|-----------------------------------------|--------------|
| `VerboseLevel`   | `off`, `on`, `full`                     | `off`        |
| `ReasoningMode`  | `off`, `on`, `stream`                   | `off`        |
| `UsageMode`      | `off`, `tokens`, `full`, `cost`         | `off`        |
| `ExecHost`       | `sandbox`, `gateway`, `node`            | `gateway`    |
| `ExecSecurity`   | `deny`, `allowlist`, `full`             | `allowlist`  |
| `ExecAsk`        | `off`, `on_miss`, `always`              | `on_miss`    |
| `QueueMode`      | `off`, `serial`, `latest`, `debounce`   | `off`        |
| `QueueDrop`      | `summarize`, `oldest`, `newest`         | `summarize`  |
| `TtsMode`        | `off`, `always`, `inbound`, `tagged`    | `off`        |
| `ActivationMode` | `mention`, `always`                     | `mention`    |
| `SendMode`       | `on`, `off`, `inherit`                  | `inherit`    |

### Autonomy → Security Mapping

| Autonomy Level | `exec_security` | `exec_ask`  |
|----------------|-----------------|-------------|
| `supervised`   | `allowlist`     | `on_miss`   |
| `full`         | `full`          | `off`       |
| `yolo`         | `full`          | `off`       |
| `read_only`    | `deny`          | `off`       |

## Turn Loop

### Overview

The turn loop is the core agentic cycle. It iterates up to
`max_tool_iterations` times, calling the LLM and executing tool calls
until a final text response (no tool calls) is produced.

### Turn Sequence

1. **Slash command check**: Handle `/command` messages directly without LLM
2. **Bare session reset**: `/new`, `/reset` → clear session, send fresh prompt
3. **System prompt injection**: Build/refresh system prompt if needed
4. **Auto-save user message**: Store to memory with nanosecond-precision key
5. **Memory enrichment**: Enrich user message with relevant memory context
6. **Response cache check**: If cache hit, return cached response immediately
7. **Tool loop** (up to `max_tool_iterations` iterations):
   a. Check interrupt flag
   b. Build provider messages from history
   c. Filter tool specs for this turn (MCP filter groups)
   d. Calculate effective max_tokens for the request
   e. Call LLM (streaming or blocking, with retry logic)
   f. Normalize token usage
   g. Parse tool calls (native structured or XML fallback)
   h. If no tool calls → final response path
   i. If tool calls → execute each, append results, continue loop

### System Prompt Management

The system prompt is:
- Injected on first turn (stored at `history[0]` with role `system`)
- Refreshed when workspace file fingerprint changes
- Refreshed when conversation context presence changes
- Always kept as exactly one canonical message at index 0

Refresh triggers:
- `has_system_prompt == false`
- Workspace file fingerprint mismatch
- Conversation context added/removed between turns

### Memory Enrichment

Before sending to the LLM, the user message is enriched:
- Memory search (hybrid vector + keyword) retrieves relevant context
- Results are prepended/appended to the user message
- The enriched message is what enters the history

### Response Cache

When enabled (`memory.response_cache`):
- Cache key = hash of (model_name, system_prompt, user_message)
- On hit: return cached response without calling LLM
- On miss after successful direct response: store in cache

### Provider Call Strategy

#### Blocking (non-streaming)
1. First attempt with full parameters
2. On vision error (auto_disable_vision_on_error): strip images, retry
3. On context exhaustion: force-compress history, retry
4. On other errors: wait 500ms, retry once
5. On retry failure with context exhaustion: force-compress, retry once more

#### Streaming
1. First attempt
2. On vision error: strip images, retry once
3. On other errors: fail immediately (no retry for streaming)

### Tool Call Parsing

Two paths:
1. **Native (structured)**: Provider returns structured `tool_calls` array
   - Used when provider supports native tools AND not streaming
   - Falls back to XML if structured calls are empty
2. **XML fallback**: Parse `<tool_call>` XML tags from response text
   - Used when provider doesn't support native tools, or when streaming

### Tool Execution

For each parsed tool call:
1. Check interrupt flag (abort if set)
2. Log tool call metadata (if `log_tool_calls` enabled)
3. Record tool_call_start event
4. Look up tool by name
5. Check security policy (exec block for shell tools)
6. Execute tool with parsed arguments
7. Record tool_call_end event
8. Append tool result to results buffer

### MCP Tool Filtering

Per-turn filtering of MCP tools based on `tool_filter_groups`:
- Non-MCP tools (name doesn't start with `mcp_`) always included
- `always` mode: matching tools always included
- `dynamic` mode: matching tools included only when user message contains
  configured keywords (case-insensitive substring match)
- Glob matching with `*` wildcard for tool name patterns

### Force Action Follow-Through

When the LLM responds with promise text but no tool calls (e.g., "I'll try",
"Let me check"), the system:
1. Detects promise patterns (English and Russian)
2. Injects a system user message demanding immediate action
3. Allows up to 2 follow-through retries per turn

### Final Response Path

When no tool calls are parsed:
1. Compose final reply (add reasoning/usage annotations if enabled)
2. Append assistant response to history
3. Auto-compact history if thresholds exceeded
4. Trim history to `max_history_messages`
5. Auto-save assistant response to memory
6. Drain durable vector outbox (if MemoryRuntime available)
7. Store in response cache (if enabled)
8. Return final text

## Context Token Resolution

### Resolution Chain
1. Explicit config override (`agent.token_limit` if explicitly set)
2. Model ID lookup (table + pattern matching)
3. Provider fallback lookup
4. Default: 200,000 tokens

### Model ID Normalization
- Strip `-latest` suffix
- Strip 8-digit date suffixes (e.g., `-20260219`)
- Try each variant against lookup tables and patterns

### Key Context Windows

| Model Pattern    | Context Tokens |
|------------------|---------------|
| `gpt-4` (legacy) | 8,192         |
| `gpt-4-32k`     | 32,768        |
| `claude-*`       | 200,000       |
| `gpt-4.1*`, `gpt-5*`, `o1*`, `o3*` | 128,000 |
| `gemini-*`       | 200,000       |
| `deepseek-*`     | 128,000       |

## Max Tokens Resolution (Generation Cap)

### Resolution Chain
1. Explicit config override (`max_tokens`)
2. Model ID lookup (same normalization as context tokens)
3. Provider fallback lookup
4. Default: 8,192 tokens

### Effective Max Tokens Clamping

The actual generation limit for each request is:
```
available = token_limit - estimated_prompt_tokens
reserve = min(256, available / 4)
completion_budget = available - reserve
effective = max(1, min(configured_max_tokens, completion_budget))
```

This prevents context overflow by dynamically reducing generation tokens
as the conversation grows.

## History Compaction

### Auto-Compaction Triggers
- Non-system message count exceeds `max_history_messages`
- Estimated token count exceeds 75% of `token_limit`

### Compaction Process
1. Identify compactable messages (all except system + recent `keep_recent`)
2. For small batches (≤10 messages): single-pass LLM summarization
3. For large batches (>10 messages): multi-part strategy
   - Split into halves, summarize each independently, merge
4. Replace compacted messages with a single system-role summary message
5. Extract critical rules from AGENTS.md and prepend to summary

### Compaction Constants

| Constant                        | Default | Description                    |
|---------------------------------|---------|--------------------------------|
| `COMPACTION_KEEP_RECENT`        | 20      | Messages to keep after compact |
| `COMPACTION_MAX_SUMMARY_CHARS`  | 2,000   | Max summary character length   |
| `COMPACTION_MAX_SOURCE_CHARS`   | 12,000  | Max source chars for summarizer|
| `MAX_WORKSPACE_CONTEXT_CHARS`   | 2,000   | Max AGENTS.md chars in summary |
| `MAX_AGENTS_FILE_BYTES`         | 2 MB    | Max AGENTS.md read size        |

### Force Compression (Context Exhaustion Recovery)

When context exhaustion errors occur and history has > 6 messages:
1. Keep only the system prompt + last 4 non-system messages
2. Prepend `[Earlier context compressed]` marker
3. Retry the LLM call

Minimum history for recovery: `CONTEXT_RECOVERY_MIN_HISTORY = 6`
Messages kept: `CONTEXT_RECOVERY_KEEP = 4`

### Token Estimation

Heuristic: `(total_chars + 3) / 4` (~4 chars per token)

For provider messages, adds structural overhead of 32 chars per message
and 48 chars per tool spec.

## History Trimming

After each turn, the history is trimmed:
- System prompt (index 0) is always preserved
- Excess non-system messages from the front are removed
- Limit: `max_history_messages` non-system messages

## Streaming

When streaming is enabled and the provider supports it:
- An adapter converts provider stream chunks to the session's stream sink
- Streaming providers are called with `streamChat()` instead of `chat()`
- Native tools are NOT used during streaming (XML fallback instead)
- No automatic retry on stream errors (unlike blocking calls)

## Observability Events

The agent emits events to an Observer throughout the turn:

| Event              | When                                    |
|--------------------|-----------------------------------------|
| `llm_request`      | Before calling provider (provider, model, message count) |
| `llm_response`     | After provider response (duration, success, error) |
| `tool_call_start`  | Before executing each tool              |
| `tool_call_end`    | After tool execution (tool, duration, success) |
| `turn_complete`    | After final response produced           |

## Multimodal / Vision

- Image detection and processing happens during message building
- Vision can be auto-disabled per model on error
- `vision_disabled_models` list (config + runtime-detected)
- When vision error detected and `auto_disable_vision_on_error` is true,
  model is added to disabled list and the request is retried without images

## Integration Points

- **Provider**: called via `Provider` interface for LLM requests
- **Tools**: dispatched via `Tool` interface during tool loop
- **Memory**: used for enrichment, auto-save, and response cache
- **Bootstrap**: provides workspace identity files for system prompt
- **Security Policy**: checked before shell/exec tool execution
- **Observer**: receives all lifecycle events
- **Session Store**: persists conversation across restarts
