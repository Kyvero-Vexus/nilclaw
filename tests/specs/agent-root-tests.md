---
Layer: L2
Lane: unit
Spec ID: L2-UNIT-agent-root-tests
Status: draft
Last Updated: 2026-03-10
Traceability:
  L1: [L1-EXT-agent-core, L1-BHV-nilclaw-baseline-feature-mapping]
  L0: [F-AGENT-SESSIONS, F-UI-CLI, C-SAFE-PRIORITY]
---

# Agent Root Test Specifications

## Overview
The agent root module defines the core Agent type, its lifecycle (history management, message building, configuration), slash commands, tool dispatch integration, streaming, and runtime behavior. It manages conversation history, token tracking, model selection, and user-facing commands.

---

## OwnedMessage

### toChatMessage conversion
- An OwnedMessage with role=user, content="hello" converts to ChatMessage with same role and content
- Works for system role and assistant role alike

---

## Module Reexports

### dispatcher, compaction, cli, prompt, memory_loader
- Agent root re-exports key types from submodules: ParsedToolCall, ToolExecutionResult, parseToolCalls, formatToolResults, buildToolInstructions, tokenEstimate, autoCompactHistory, etc.

---

## Agent Initialization

### Initial state
- History length is 0
- total_tokens is 0
- has_system_prompt is false
- model_name, temperature, workspace_dir match constructor arguments

### Default limits
- max_tool_iterations default: specific numeric constant (implementation-defined)
- max_history_messages default: specific numeric constant

### Streaming fields default to null
- All streaming-related fields (stream context, response buffer) are null initially

### Streaming fields can be set
- Setting stream context and related fields works and persists

---

## History Management

### trimHistory preserves system prompt
- **Setup**: Agent with max_history=5, 1 system prompt + 10 user messages (11 total)
- **Action**: trimHistory()
- **Expected**: System prompt remains at position 0, total messages ≤ 6 (1 system + 5), most recent message is the last one added

### trimHistory no-op when under limit
- **Setup**: Agent with max_history=50, fewer messages than limit
- **Action**: trimHistory()
- **Expected**: No messages removed

### trimHistory without system prompt
- **Setup**: Agent with no system prompt, messages exceeding limit
- **Action**: trimHistory()
- **Expected**: Trimmed to max_history, keeping most recent; no system prompt to preserve

### trimHistory keeps most recent messages
- When trimming, oldest non-system messages are removed, most recent are kept

### clearHistory
- **Setup**: Agent with system prompt + user messages, has_system_prompt=true, workspace_prompt_fingerprint set
- **Action**: clearHistory()
- **Expected**: History length = 0, has_system_prompt = false, workspace_prompt_fingerprint = null

### clearHistory then add messages
- After clearing, new messages can be added and history works normally

---

## Token Tracking

### Tokens tracking
- Agent tracks total_tokens; adding to total_tokens accumulates correctly

---

## Message Building

### buildMessageSlice
- Converts internal history into a slice of ChatMessages suitable for provider API calls

### buildProviderMessages uses model-aware vision capability
- When building provider messages, the agent checks if the model supports vision
- Image content is included or excluded based on model capability

### buildProviderMessages allows workspace image paths
- Image paths within the workspace directory are permitted in message content

---

## Agent.fromConfig

### Resolves token limit from model lookup when unset
- When no explicit token_limit is set, resolves from known model database

### Keeps explicit token_limit override
- When config specifies explicit token_limit, uses that value regardless of model lookup

### Resolves max_tokens from provider lookup when unset
- When max_tokens not explicitly set, derives from provider's known limits

### Resolves conservative limits for legacy gpt-4
- Legacy GPT-4 models get conservative token limits

### Keeps explicit max_tokens override
- Explicit max_tokens in config takes precedence

### Clamps max_tokens to token_limit
- max_tokens cannot exceed token_limit; clamped if it does

### Applies status_show_emojis flag
- Config flag propagates to agent instance

### Sets exec_security based on autonomy level
- full autonomy → exec_security=full
- read_only autonomy → exec_security=deny
- supervised autonomy → exec_security=allowlist

### Sets multimodal_unrestricted for yolo
- "yolo" autonomy level enables multimodal_unrestricted
- "full" autonomy does NOT enable multimodal_unrestricted

---

## Effective max_tokens Calculation

### Reserves prompt headroom
- Effective max_tokens = token_limit minus estimated prompt size minus safety margin

### Does not double count plain content with content_parts
- When message has both plain content and content_parts, only counts once

### Scales with image_base64 size
- Base64-encoded images increase token usage estimate proportionally

### Accounts for native tool schema overhead
- Tool definitions consume tokens; effective max_tokens reduced accordingly

### Can estimate using filtered tool schemas
- When tool groups filter available tools, only filtered schemas count toward overhead

---

## Slash Commands

### /new clears history
- **Action**: Send "/new"
- **Expected**: History cleared, returns confirmation

### /reset clears history and switches model
- **Action**: Send "/reset provider/model"
- **Expected**: History cleared AND model switched to specified model

### /help returns help text
- **Expected**: Returns list of available commands

### /commands aliases to help
- "/commands" behaves identically to "/help"

### /status returns agent info
- **Expected**: Shows model name, provider, token counts, settings

### /status can render without emojis
- When status_show_emojis=false, status output has no emoji characters

### /whoami returns current session id
- **Expected**: Returns the agent's session identifier string

### /model switches model
- "/model provider/new-model" → switches to new model

### /model with colon switches model
- "/model provider:model" format also works

### /model with telegram bot mention
- "/model @botname provider/model" → strips mention, switches model

### /model resolves provider max_tokens fallback
- After model switch, max_tokens recalculated from provider lookup

### /model keeps explicit token_limit override
- If token_limit was explicitly set, model switch preserves it

### /model without name shows current
- "/model" with no argument → shows current model info

### /models aliases to /model
- "/models" behaves like "/model" (show current)

### /model list aliases to model status
- "/model list" → shows model status

### /model shows provider and model fallback chains
- Output includes configured fallback providers and model fallbacks

### /model dupe prevents use-after-free
- Switching to the same model that's already active doesn't cause memory issues

### /memory list hides internal entries by default
- Autosave and hygiene entries are filtered from output

### /memory list includes internal entries when requested
- With explicit flag/argument, internal entries are shown

### /compact with short history is a no-op
- If history is already short, compaction does nothing

### /think updates reasoning effort
- "/think high" → sets reasoning_effort to high

### /verbose updates verbose level
- "/verbose 2" → sets verbose level

### /reasoning updates reasoning mode
- "/reasoning on" → enables reasoning display

### /exec updates runtime exec settings
- Modifies execution runtime configuration

### /queue updates queue settings
- Modifies message queue configuration

### /usage updates usage mode
- Toggles or sets token usage display mode

### /tts updates tts settings
- Modifies text-to-speech configuration

### /stop handled explicitly
- "/stop" → stops current processing

### /abort aliases /stop
- "/abort" behaves like "/stop"

### /approve executes pending bash command
- When a command is waiting for approval, "/approve" executes it

### /restart clears runtime command settings
- Resets execution runtime to defaults

### slash additional commands are handled
- Additional registered slash commands route correctly

### non-slash message returns null
- Regular messages (not starting with /) return null from slash handler

### slash command with whitespace
- Leading/trailing whitespace around slash command is handled

---

## Turn Processing

### bare /new routes through fresh-session prompt
- When user sends just "/new", the subsequent turn uses the fresh-session prompt flow

### /reset with argument stays slash-only command
- "/reset model" is fully handled by slash handler, not sent to LLM

### Returns interruption reply when interrupt requested
- If an interruption flag is set, turn returns immediately with interruption message

### Interruption reply lists effectively interrupted tools
- The interruption response names which tools were interrupted

### Hard stop mock interruption lists exactly interrupted tool
- Even during hard stop, the specific interrupted tool is reported

### Includes reasoning and usage footer when enabled
- When reasoning display and usage tracking are on, turn response includes both footers

### Estimates token usage when provider omits usage
- If provider response lacks usage data, agent estimates from content length

### Refreshes system prompt after workspace markdown change
- When AGENTS.md or SOUL.md changes on disk, next turn detects fingerprint change and rebuilds system prompt

### Refreshes system prompt after TOOLS.md change
- File change detection triggers system prompt refresh

### Refreshes system prompt after USER.md change
- File change detection triggers system prompt refresh

---

## Exec Security

### deny blocks shell tool execution
- When exec_security=deny, shell/exec tools are completely blocked

### ask always registers pending approval from tool path
- In ask mode, tool execution requests are queued for user approval

### execBlockMessage allows all commands when exec_security=full
- No blocking, all commands pass

### execBlockMessage checks allowlist when exec_security=allowlist
- Only commands matching the allowed list proceed; others blocked with message

### execBlockMessage allowlist mode honors wildcard
- Wildcard ("*") in allowed_commands allows everything

---

## Tool Management

### tool_call_batch_updates_tools_md
- Detects when a batch of tool calls includes writes to TOOLS.md

### should_skip_tools_memory_store_duplicate
- Skips only tools-related memory_store entries to avoid duplicates

### Agent turn skips duplicate memory_store when TOOLS.md updated in same batch
- When a tool batch writes to TOOLS.md and also calls memory_store, the memory_store for tools is deduplicated

### bindMemoryTools wires memory tools to sqlite backend
- Memory tools (memory_store, memory_search) are connected to the configured backend

### Agent tool loop frees dynamic tool outputs
- Dynamically allocated tool output strings are freed after each iteration (no leaks)

---

## Shell Failure Recovery

### Shell failure with normalized output does not poison next turn
- If a shell command fails and its output is normalized/cleaned, subsequent agent turns work normally

---

## Streaming

### Falls back to blocking chat when stream ctx is missing
- If streaming context is unavailable, agent uses synchronous chat completion

---

## Content Analysis

### shouldForceActionFollowThrough
- Detects English deferred promises ("I'll", "Let me") → forces follow-through
- Detects Russian deferred promises → forces follow-through
- Ignores normal final answers → no follow-through forced

### selectDisplayText
- Hides malformed tool markup payload from display
- Keeps plain text when no markup exists
- Prefers parsed text when present
- Hides malformed tool markup even in parsed text

---

## Tool Filtering

### filterToolSpecsForTurn no groups
- With no tool groups configured, all tool specs are returned unchanged

### filterToolSpecsForTurn always group
- Tools in "always" group are always included regardless of context

### filterToolSpecsForTurn dynamic group
- Tools in dynamic groups are included when message content matches group keywords

### filterToolSpecsForTurn dynamic keyword match is case-insensitive
- "SEARCH" matches "search" keyword

---

## Utility

### milliTimestamp negative difference clamps to zero
- When computing time differences, negative results are clamped to 0

### globMatch handles prefix wildcard
- Glob pattern matching with leading "*" works correctly
