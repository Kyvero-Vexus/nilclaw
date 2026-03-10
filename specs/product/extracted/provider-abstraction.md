# Provider Abstraction & Multi-Model Specification

## Overview

The provider system abstracts LLM interactions behind a vtable-based
polymorphic interface. It supports multiple provider backends, model routing,
reliable retry with fallback chains, streaming, vision, and native tool calls.

## Provider Interface

### Core VTable Methods (Required)

| Method              | Signature                                              | Description                         |
|---------------------|--------------------------------------------------------|-------------------------------------|
| `chatWithSystem`    | (system_prompt?, message, model, temperature) → text   | Simple one-shot chat                |
| `chat`              | (ChatRequest, model, temperature) → ChatResponse       | Structured chat (tool support)      |
| `supportsNativeTools`| () → bool                                             | Whether native tool_calls supported |
| `getName`           | () → string                                            | Provider name for diagnostics       |
| `deinit`            | () → void                                              | Resource cleanup                    |

### Optional VTable Methods

| Method                 | Default Behavior                                   | Description                          |
|------------------------|----------------------------------------------------|--------------------------------------|
| `warmup`               | No-op                                              | Pre-warm connection                  |
| `chat_with_tools`      | Delegates to `chat()`                              | Native function calling              |
| `supports_streaming`   | Returns `false`                                    | Streaming support check              |
| `supports_vision`      | Returns `false`                                    | Vision/image input support           |
| `supports_vision_for_model` | Falls back to `supports_vision()`             | Per-model vision check               |
| `stream_chat`          | Fallback: `chat()` → single chunk + final          | Streaming chat                       |

### Streaming Fallback

When `stream_chat` is null, the provider:
1. Calls `chat()` synchronously
2. Emits content as a single text delta chunk
3. Emits a final (end-of-stream) chunk
4. Returns `StreamChatResult` with accumulated content

## Core Types

### ChatMessage

| Field          | Type           | Default | Description                           |
|----------------|----------------|---------|---------------------------------------|
| `role`         | Role           | —       | `system`, `user`, `assistant`, `tool` |
| `content`      | string         | —       | Message text                          |
| `name`         | string?        | null    | Sender name (for tool results)        |
| `tool_call_id` | string?        | null    | Tool call ID this responds to         |
| `content_parts`| ContentPart[]? | null    | Multimodal content (images, etc.)     |

### ContentPart (Tagged Union)

| Variant        | Fields                              | Description              |
|----------------|-------------------------------------|--------------------------|
| `text`         | text: string                        | Text content             |
| `image_url`    | url: string, detail: ImageDetail    | Image by URL             |
| `image_base64` | data: string, media_type: string    | Base64-encoded image     |

`ImageDetail`: `auto` (default), `low`, `high`

### ChatResponse

| Field              | Type        | Default | Description                      |
|--------------------|-------------|---------|----------------------------------|
| `content`          | string?     | null    | Response text                    |
| `tool_calls`       | ToolCall[]  | `[]`    | Structured tool call requests    |
| `usage`            | TokenUsage  | zeros   | Token usage stats                |
| `provider`         | string      | `""`    | Effective provider name          |
| `model`            | string      | `""`    | Effective model name             |
| `reasoning_content`| string?     | null    | Reasoning/thinking content       |

### TokenUsage

| Field              | Type | Default | Description            |
|--------------------|------|---------|------------------------|
| `prompt_tokens`    | u32  | 0       | Input tokens           |
| `completion_tokens`| u32  | 0       | Output tokens          |
| `total_tokens`     | u32  | 0       | Total tokens           |

### ToolCall

| Field       | Type   | Description                |
|-------------|--------|----------------------------|
| `id`        | string | Unique call identifier     |
| `name`      | string | Tool name                  |
| `arguments` | string | JSON-encoded arguments     |

### ToolSpec

| Field            | Type   | Description                       |
|------------------|--------|-----------------------------------|
| `name`           | string | Tool name                         |
| `description`    | string | Tool description                  |
| `parameters_json`| string | JSON schema for parameters        |

### ChatRequest

| Field             | Type       | Default | Description                        |
|-------------------|------------|---------|------------------------------------|
| `messages`        | ChatMessage[]| —     | Conversation messages              |
| `model`           | string     | `""`    | Model identifier                   |
| `temperature`     | float      | `0.7`   | Sampling temperature               |
| `max_tokens`      | u32?       | null    | Max generation tokens              |
| `tools`           | ToolSpec[]?| null    | Tool definitions for function calling |
| `timeout_secs`    | u64        | `0`     | HTTP timeout (0 = no limit)        |
| `reasoning_effort`| string?    | null    | Reasoning effort hint              |

### StreamChunk

| Field        | Type   | Description                |
|--------------|--------|----------------------------|
| `delta`      | string | Text delta                 |
| `is_final`   | bool   | End-of-stream marker       |
| `token_count`| u32    | Estimated tokens for chunk |

Token estimation: `(text.len + 3) / 4`

## Provider Implementations

### Provider Classification (ProviderKind)

| Kind                    | Description                    |
|-------------------------|--------------------------------|
| `anthropic_provider`    | Anthropic API (Claude)         |
| `openai_provider`       | OpenAI API                     |
| `openrouter_provider`   | OpenRouter aggregator          |
| `ollama_provider`       | Local Ollama                   |
| `gemini_provider`       | Google Gemini API              |
| `vertex_provider`       | Google Vertex AI               |
| `compatible_provider`   | OpenAI-compatible endpoint     |
| `claude_cli_provider`   | Claude CLI subprocess          |
| `codex_cli_provider`    | Codex CLI subprocess           |
| `openai_codex_provider` | OpenAI Codex (OAuth)           |
| `unknown`               | Unrecognized provider          |

### OpenAI-Compatible Provider System

Many providers are configured as OpenAI-compatible endpoints with per-provider
customization flags:

| Flag                       | Purpose                                        |
|----------------------------|-------------------------------------------------|
| `no_responses_fallback`    | Disable `/v1/responses` fallback on 404        |
| `merge_system_into_user`   | Merge system messages into first user message  |
| `auth_style`               | Auth method (`bearer`, `api_key_header`, etc.) |
| `native_tools`             | Support native tool_calls                      |
| `max_tokens_non_streaming` | Cap max_tokens when not streaming              |
| `thinking_param`           | Include `"thinking"` in request body           |
| `enable_thinking_param`    | Include `"enable_thinking"` in request body    |
| `reasoning_split_param`    | Include `"reasoning_split"` in request body    |

### Built-in Compatible Providers

Major providers registered as compatible:
Groq, Mistral, DeepSeek, xAI/Grok, Cerebras, Perplexity, Cohere,
Venice, Vercel, Together AI, Fireworks, Hyperbolic, Featherless,
GitHub Models, Qwen, Z.AI/GLM, NVIDIA, Sambanova, MiniMax, Moonshot/Kimi,
and many more.

## Reliable Provider (Retry & Fallback)

Wraps any provider to add retry logic, provider fallback chains, and
model fallback chains.

### Error Classification

| Category          | Detection Pattern                              | Behavior        |
|-------------------|------------------------------------------------|-----------------|
| Non-retryable     | 4xx status (except 429, 408)                   | Fail immediately|
| Rate-limited      | 429, "rate limit", "too many requests"         | Retry with backoff |
| Context exhaustion| "context length", "token limit exceeded"       | Force-compress + retry |
| Vision error      | "does not support vision"                      | Auto-disable vision + retry |
| Other             | All other errors                               | Retry with backoff |

### Retry-After Parsing

Extracts `Retry-After` values from error messages:
- Integer seconds → converted to milliseconds
- Floating-point seconds → converted to milliseconds
- Millisecond values (>1000) → used directly

## Agent Routing

Routes incoming messages to specific agent configurations based on a
tiered matching system.

### Match Priority (highest to lowest)

1. **peer** — exact peer (chat type + id) match
2. **parent_peer** — peer matches thread parent
3. **guild_roles** — guild_id + at least one matching role
4. **guild** — guild_id only
5. **team** — team_id match
6. **account** — channel + account_id
7. **channel_only** — channel only

If no binding matches, the default agent is used (first in agents list,
or "main" if empty).

### Route Input

| Field            | Type       | Description                |
|------------------|------------|----------------------------|
| `channel`        | string     | Channel name               |
| `account_id`     | string     | Account identifier         |
| `peer`           | PeerRef?   | Current message peer       |
| `parent_peer`    | PeerRef?   | Thread parent peer         |
| `guild_id`       | string?    | Guild/server identifier    |
| `team_id`        | string?    | Team identifier            |
| `member_role_ids`| string[]   | Member's role IDs          |

### ID Normalization

IDs are normalized: lowercase, non-alphanumeric → `-`, strip leading/trailing
dashes, cap at 64 chars. Empty/all-dash input → `"default"`.

## Model Route Format

Models are referenced as `provider/model` (e.g., `"openrouter/anthropic/claude-sonnet-4"`).

Special format `custom:<url>/<model>` for custom endpoints — splits on
versioned API path segments (`/v1/`, `/v2/`) to extract the model ID.

## API Key Resolution

Resolution chain:
1. Named agent's dedicated `api_key`
2. Provider entry in `models.providers.<name>.api_key`
3. Environment variable (provider-specific, e.g., `OPENAI_API_KEY`)

API keys can be strings or structured JSON objects (e.g., Vertex service
account credentials), stored as compact JSON strings.

## Secret Scrubbing

All provider error messages and tool outputs are scrubbed before being
shown to the user or included in conversation history:
- API keys, bearer tokens, authorization headers
- Common secret patterns (passwords, credentials)
- Provider-specific error details are captured separately for diagnostics

## Integration Points

- **Agent**: calls `Provider.chat()` / `Provider.streamChat()` during turn loop
- **Config**: reads `models.providers.*` for provider setup
- **Routing**: uses agent bindings to select provider/model per message
- **Reliability**: wraps providers with retry/fallback logic
- **Observability**: events include provider name and model for each call
