---
Layer: L2
Lane: compatibility
Spec ID: L2-COMP-providers-compatible-tests
Status: draft
Last Updated: 2026-03-10
Traceability:
  L1: [L1-EXT-provider-abstraction, L1-COMP-baseline-compatibility]
  L0: [F-LLM-COMPAT, F-LLM-MULTIPROVIDER, C-REL-TIMEOUT-RETRY]
---

# Providers Compatible (OpenAI-Compatible) Test Specifications

## Overview
The compatible provider module implements an OpenAI-compatible API client supporting chat completions, responses API, streaming, authentication styles, multimodal content (images), reasoning model handling, think-block stripping, and model normalization. It serves as the universal provider adapter for all OpenAI-API-compatible backends.

---

## URL Construction

### Strips trailing slash from base_url
- `"https://example.com/"` → stored as `"https://example.com"`

### chatCompletionsUrl
- Standard: `https://api.openai.com/v1` → `…/v1/chat/completions`
- Custom full endpoint (already ends with `/chat/completions`): preserved as-is
- Trailing slash stripped before appending
- Without `/v1`: `https://api.example.com` → `…/chat/completions`
- With `/v1`: `https://api.example.com/v1` → `…/v1/chat/completions`
- Requires exact suffix match: `…/completions-proxy` → appends `/chat/completions` (no false match)

### responsesUrl
- Standard base → `…/v1/responses`
- With `/v1` → no duplicate `/v1/v1`, just `…/v1/responses`
- Derives from chat endpoint: `…/api/v2/chat/completions` → `…/api/v2/responses`
- Custom endpoint ending in `/responses` → preserved
- Non-v1 API path → appends `/responses`
- Requires exact suffix match: `…/responses-proxy` → appends `/responses`

---

## Authentication

### Bearer style
- api_key="my-key", auth=bearer → header name="authorization", value="Bearer my-key"

### X-API-Key style
- api_key="my-key", auth=x_api_key → header name="x-api-key", value="my-key"

### No key → null (no auth header)

### Custom style with custom_header
- custom_header="X-Custom-Key" → uses that as header name, value=key (no "Bearer" prefix), needs_free=false

### Custom style without custom_header → falls back to "authorization"

### AuthStyle headerName
- bearer → "authorization"
- x_api_key → "x-api-key"
- custom → "authorization" (fallback)

---

## Request Body Building

### buildRequestBody with system prompt
- Body contains model name, "system" role, "user" role

### buildRequestBody without system prompt
- No "system" in body, contains `"stream":false`

### buildRequestBody reasoning model omits temperature
- Model "gpt-5" → no `"temperature":` in body, `"stream":false` present

---

## Chat Request Body (buildChatRequestBody)

### Reasoning effort params
- GLM model with reasoning_effort="high" + thinking_param=true → `"thinking":{"type":"enabled"}` in body
- thinking_param=false → no `"thinking"` in body
- enable_thinking=true → `"enable_thinking":true` in body
- reasoning_split=true → `"reasoning_split":true` in body
- reasoning_effort="none" → all provider thinking params omitted (even when all flags true)

### Temperature omission for reasoning models
- Model "o1" → no `"temperature":` in body, uses `"max_completion_tokens"` instead of `"max_tokens"`

### Plain text content (no content_parts)
- Serialized as JSON string, not array

### Image URL content parts → OpenAI array format
- Text part + image_url part → content is array of 2 objects
- Text part: type="text", text=value
- Image part: type="image_url", image_url.url=URL, image_url.detail="auto"

### Base64 image → data URI
- `data:image/jpeg;base64,AQID` in body

### High detail image_url
- detail="high" in serialized image_url object

---

## Streaming Request Body

### Contains `"stream":true`

### Omits provider thinking params when reasoning_effort="none"

### Reasoning model omits temperature
- "gpt-5.2" → no temperature, uses max_completion_tokens, stream=true

### Same messages as non-streaming
- Both bodies contain the same message content

### Has model field

---

## Response Parsing

### parseTextResponse extracts content
- `{"choices":[{"message":{"content":"Hello!"}}]}` → "Hello!"

### Strips think blocks
- Content with `<think>…</think>` prefix → stripped, only visible text returned

### Empty choices → NoResponseContent error
### Null content → NoResponseContent error
### Rate limit error → RateLimited error

### parseNativeResponse splits think blocks
- Content with `<think>…</think>` → content gets visible text, reasoning_content gets think block content

### Reads native reasoning_content field (Z.AI/GLM style)
- `"reasoning_content":"chain of thought"` → extracted into reasoning_content field

### Reads native reasoning field (Groq/Cerebras format)
- `"reasoning":"parsed reasoning trace"` → extracted into reasoning_content field

---

## Responses API

### extractResponsesText
- Top-level output_text → extracted directly
- Strips think blocks from output_text
- Nested output_text type → finds text in content array
- Fallback: any text type in content → extracted
- Empty output → NoResponseContent error

### buildResponsesRequestBody
- With system → body contains model, "instructions", system content
- Without system → no "instructions" field

---

## Streaming Think Sanitize Callback

### Strips think blocks across chunk boundaries
- Chunks: `"<thi"`, `"nk>private reasoning"`, `"</think>\nVisible answer"`, final
- **Expected**: Collected output = `"\nVisible answer"`, final seen

### Preserves incomplete think tag literals
- Chunks: `"literal <thi"`, final
- **Expected**: Output = `"literal <thi"` (not stripped since never closed)

---

## Model Normalization

### DeepSeek v3.2 aliases
- Provider "deepseek": "deepseek-v3.2" → "deepseek-chat"
- Provider "deepseek": "deepseek/deepseek-v3.2" → "deepseek-chat"
- "deepseek-reasoner" → unchanged

### Other providers unchanged
- Provider "openrouter": "deepseek-v3.2" → "deepseek-v3.2" (no mapping)

---

## Provider Interface

### getName returns custom name
- Init with name "Venice" → getName() returns "Venice"

### supportsNativeTools → true
### supportsStreaming → true
### vtable has stream_chat (not null)

---

## Non-Streaming Max Tokens Capping

### Caps when above provider limit
- Request max_tokens=8000, provider limit=4096 → capped to 4096

### Keeps when below limit
- Request max_tokens=1024, provider limit=4096 → unchanged (1024)

### Unchanged when limit is unset
- No provider limit → max_tokens preserved

---

## User Agent Validation

### Accepts valid
- "nilclaw/1.0" → valid

### Rejects CRLF injection
- "bad\r\nX-Test: 1" → invalid

---

## Merge System Into User

### Merges system into first user message
- System + user → 1 message, role=user, content contains `[System: Be helpful]` + user text

### No system messages → passes through unchanged

### merge_system_into_user=false keeps system messages
- 2 messages preserved with original roles

### Field defaults to false

### Multiple system messages concatenated
- 2 system + 1 user → 1 message with both system texts joined by newline

### Preserves assistant messages
- System + user + assistant + user → 3 messages (merged first user, assistant, last user)
- Only first user message has merge prefix

### Streaming body also merges when enabled
- Same merge behavior applies to streaming request body
