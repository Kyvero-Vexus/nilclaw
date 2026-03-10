# Streaming & Voice Specification

## Overview

This specification covers three subsystems:

1. **Streaming**: An event-based streaming abstraction for delivering partial
   LLM responses to clients in real-time, with a tag-filtering pipeline that
   strips internal markup (tool call XML tags) from the user-visible stream.

2. **Voice (STT)**: Speech-to-text transcription via OpenAI-compatible Whisper
   APIs, with Telegram voice message integration.

3. **SSE Client**: A persistent Server-Sent Events connection client for
   receiving real-time events from SSE endpoints, implementing the W3C SSE
   specification.

---

## Streaming

### Data Model

#### Outbound Stage

An enum representing the lifecycle stage of a streaming event:

| Value   | Description                                    |
|---------|------------------------------------------------|
| `chunk` | A partial text fragment (may be any size)      |
| `final` | End-of-stream marker (no text payload)         |

#### Streaming Event

| Field  | Type          | Description                              |
|--------|---------------|------------------------------------------|
| `stage`| OutboundStage | Whether this is a chunk or final marker  |
| `text` | string        | Text content (empty for `final` events)  |

#### Sink

A callback-based event consumer interface. Any component that wants to receive
streaming events implements this pattern:

- **`emit(event)`**: Deliver an event to the consumer.
- **`emitChunk(text)`**: Convenience — emits a `chunk` event. No-op if text is empty.
- **`emitFinal()`**: Convenience — emits a `final` event.

### Behavior

#### Provider Chunk Conversion

Converts provider-specific stream chunks into generic streaming events:

- If the provider chunk is marked as final → produce a `final` event.
- If the provider chunk has a non-empty delta → produce a `chunk` event with the delta text.
- If the provider chunk has an empty delta and is not final → produce nothing (skip).

#### Forward Provider Chunk

Convenience function: converts a provider chunk and emits it to a sink in one step.

### Tag Filter

A state-machine filter that strips XML-style tool invocation tags from the
streaming output before it reaches the user. This ensures internal markup
like `<tool_call>...</tool_call>` and `<tool_result ...>...</tool_result>`
is never visible in the user-facing stream.

#### Filtered Tags

| Open Tag Pattern          | Close Tag          | Notes                              |
|---------------------------|--------------------|------------------------------------|
| `<tool_call>`             | `</tool_call>`     | Tool invocation                    |
| `<tool_call ...>`         | `</tool_call>`     | With attributes                    |
| `<tool_result>`           | `</tool_result>`   | Tool result                        |
| `<tool_result ...>`       | `</tool_result>`   | With attributes (e.g., `name`, `status`) |

#### State Machine

| State               | Description                                        |
|----------------------|----------------------------------------------------|
| `passthrough`        | Normal text flows through to inner sink            |
| `maybe_open`         | Buffering after `<`, checking for open tag prefix  |
| `skip_to_angle_close`| Open tag prefix matched, consuming until `>`       |
| `inside_tag`         | Inside tag body, suppressing all output            |
| `maybe_close`        | Buffering after `<`, checking for close tag match  |

#### Behavior

1. In `passthrough`, text flows through unchanged until `<` is encountered.
2. On `<`, buffer bytes and check if they match a known open tag prefix.
3. If they match an open tag and the next char is `>` or ` ` (space for attributes):
   - Skip until closing `>`.
   - Enter `inside_tag` state — suppress all text.
4. Inside a tag body, all output is suppressed until a matching close tag is found.
5. Close tags are also buffered and matched; on match, return to `passthrough`.
6. If a buffered sequence doesn't match any known tag, flush the buffer
   as regular text and return to `passthrough`.
7. On `final` event, any incomplete open-tag buffer is flushed as regular text
   (it's not a real tag), then the `final` is forwarded.

#### Constants

| Constant         | Value | Description                            |
|------------------|-------|----------------------------------------|
| `max_prefix_len` | 12    | Longest open tag prefix to buffer      |
| `max_tag_len`    | 14    | Longest close tag to buffer            |

#### Edge Cases

- Tags split across multiple chunks are handled correctly.
- Close tags split across chunks are handled correctly.
- Regular `<` characters that don't form known tags pass through.
- Multiple consecutive tool calls in one stream are all stripped.
- Incomplete tag at end of stream is flushed as regular text.

---

## Voice (Speech-to-Text)

### Data Model

#### Transcription Options

| Field      | Type    | Default            | Description                      |
|------------|---------|--------------------|----------------------------------|
| `model`    | string  | `"whisper-large-v3"` | Whisper model name             |
| `language` | string? | null               | Language hint (ISO 639-1 code)   |

#### Transcriber Interface

A pluggable interface for speech-to-text backends:

- **`transcribe(path) → string?`**: Transcribe an audio file at the given
  filesystem path. Returns transcribed text or null.

#### Whisper Transcriber

Concrete implementation of the Transcriber interface for OpenAI-compatible
Whisper APIs.

| Field      | Type    | Description                         |
|------------|---------|-------------------------------------|
| `endpoint` | string  | API endpoint URL                    |
| `api_key`  | string  | Bearer token for authentication     |
| `model`    | string  | Whisper model name                  |
| `language` | string? | Optional language hint              |

### Behavior

#### File Transcription

1. Generate a random 32-character hex boundary for multipart encoding.
2. Write multipart/form-data body to a temp file (streaming, to avoid
   holding both file data and encoded body in memory simultaneously):
   - Part 1: `file` — the audio file, Content-Type: `audio/ogg`, filename: `audio.ogg`.
   - Part 2: `model` — the Whisper model name.
   - Part 3 (optional): `language` — language hint if configured.
3. POST the temp file to the transcription endpoint via curl subprocess:
   - `curl -s -X POST -H "Authorization: Bearer <key>" -H "Content-Type: multipart/form-data; boundary=<boundary>" --data-binary @<tempfile> <endpoint>`
4. Delete the temp file.
5. Parse JSON response: extract `{"text": "..."}` field.
6. Return transcribed text.

**Error conditions:**
- File read failure → `FileReadFailed`
- Boundary generation failure → `BoundaryGenerationFailed`
- API request failure (curl error) → `ApiRequestFailed`
- Invalid/unparseable response → `InvalidResponse`
- Non-string or missing `text` field → `InvalidResponse`

#### Provider Endpoint Resolution

Maps provider names to known transcription API endpoints:

| Provider  | Endpoint                                              |
|-----------|-------------------------------------------------------|
| `openai`  | `https://api.openai.com/v1/audio/transcriptions`     |
| `groq`    | `https://api.groq.com/openai/v1/audio/transcriptions`|
| `telnyx`  | `https://api.telnyx.com/v2/ai/audio/transcriptions`  |
| (unknown) | Falls back to Groq endpoint                          |
| (explicit)| Any explicitly provided endpoint overrides the above  |

#### Telegram Voice Integration

Handles voice/audio messages from Telegram:

1. If no Transcriber is configured, return null immediately.
2. Call Telegram `getFile` API with the `file_id` to obtain the server-side `file_path`.
3. Download the file from `https://api.telegram.org/file/bot<token>/<file_path>`.
4. Save to temp file: `<tmp_dir>/nullclaw_tg_voice_<pid>.ogg`.
5. Transcribe via the configured Transcriber.
6. Clean up temp file.
7. Return transcribed text (or null on any failure).

**Failure handling:** All errors (getFile, download, transcription) are logged
and result in a null return — voice transcription failures are non-fatal.

### Constraints

- Temp files are named with PID to avoid collisions: `nullclaw_voice_<pid>.bin`,
  `nullclaw_tg_voice_<pid>.ogg`.
- Audio streaming to temp file uses 32KB read buffer.
- Curl stdout is capped at 4MB for transcription responses.
- Temp files are always cleaned up (even on error paths).

---

## SSE Client

### Data Model

#### SSE Connection

A persistent HTTP connection that streams Server-Sent Events.

| Field            | Type      | Description                                     |
|------------------|-----------|-------------------------------------------------|
| `url`            | string    | SSE endpoint URL                                |
| `client`         | HTTPClient| Underlying HTTP client                          |
| `request`        | Request?  | Active HTTP request (null when disconnected)     |
| `body_reader`    | Reader?   | HTTP body reader (decodes chunked encoding)      |
| `transfer_buf`   | byte[4096]| Transfer buffer for body reader                 |
| `last_event_id`  | string?   | Last received event ID (for reconnection)        |

#### SSE Event

| Field        | Type   | Description                                        |
|--------------|--------|----------------------------------------------------|
| `data`       | string | Event data (concatenated from all `data:` lines)   |
| `event_type` | string | Event type from `event:` field (empty = `"message"`) |
| `id`         | string | Event ID from `id:` field (empty if not set)        |

### Constants

| Constant           | Value     | Description                              |
|--------------------|-----------|------------------------------------------|
| `MAX_EVENT_SIZE`   | 262,144   | Maximum SSE event size (256KB)           |
| `MAX_BUFFER_SIZE`  | 8,192     | Maximum read buffer size per call        |
| `READ_TIMEOUT_MS`  | 1,000     | Poll timeout for new data (1 second)     |

### Behavior

#### Connection

1. Parse the URL.
2. Build request headers:
   - `Accept: text/event-stream`
   - `Last-Event-ID: <id>` (if reconnecting with a stored event ID).
3. Close any previous request before opening a new one.
4. Send a bodiless GET request.
5. Receive response headers.
6. If status is not 2xx, return `ConnectionFailed`.
7. Initialize body reader (handles chunked transfer encoding).
8. Return the HTTP status code.

#### Reading Data

The read strategy optimizes for both latency and throughput:

1. **Phase 1 — Drain buffered data**: Read all already-buffered HTTP body
   bytes (non-blocking). If data was obtained, return immediately.
2. **Phase 2 — Early return**: If any data was read in Phase 1, return it.
   The caller will poll again soon.
3. **Phase 3 — Wait for readability**: If no data available, poll the socket
   for readability with `READ_TIMEOUT_MS` timeout. If timeout expires, return 0.
4. **Phase 4 — Read and drain**: After socket becomes readable, read one byte,
   then drain any additional buffered data to coalesce small reads.

**Socket polling:**
- Uses `poll()` syscall with `POLLIN` flag.
- Also checks TLS/buffered transport layers for pre-decoded data.
- `POLLERR`, `POLLHUP`, `POLLNVAL` → `ConnectionClosed`.

**Error mapping:**
- End of stream with no data → `ConnectionClosed`.
- Read errors → `ReadError`.
- No active connection → `NotConnected`.

#### Event ID Tracking

- `setLastEventId(id)`: Stores a copy of the event ID (frees previous).
- On reconnection, sends `Last-Event-ID` header per W3C SSE spec so the
  server can resume from the last received event.

#### Connection Status

- `isConnected()`: Returns true if both `request` and `body_reader` are non-null.

### SSE Event Parsing

Parses raw SSE text into structured events per the W3C Server-Sent Events specification.

#### Line Processing

- Lines are split on `\n` (LF).
- Trailing `\r` is stripped (handles CRLF line endings).
- Empty lines dispatch the current event.
- Lines starting with `:` are comments (ignored).

#### Field Processing

Each non-empty, non-comment line is parsed as `field: value`:
- The field name is everything before the first `:`.
- The value is everything after `:`, with **exactly one** leading space stripped.
- If no `:` is present, the entire line is the field name and value is empty.

#### Supported Fields

| Field   | Behavior                                                        |
|---------|-----------------------------------------------------------------|
| `data`  | Appends value to current event data. Multiple `data:` lines are |
|         | joined with `\n`. An empty `data:` line appends a newline.      |
| `event` | Sets the event type (replaces previous value for this event).   |
| `id`    | Sets the event ID (rejected if contains null byte U+0000).       |
| `retry` | Parsed as integer (reconnection time in ms); not acted upon.    |

Unknown fields are silently ignored.

#### Event Dispatch

- When an empty line is encountered and data has been accumulated, an event
  is dispatched with the current `data`, `event_type`, and `id`.
- All fields are then reset for the next event.
- Data remaining at end of buffer (no trailing empty line) is still dispatched.

#### Size Limit

- Events are truncated at `MAX_EVENT_SIZE` (256KB).
- When the limit is reached, the accumulated data so far is dispatched as a
  complete event (preserving event_type and id), and remaining `data:` lines
  for that event are discarded.

---

## Integration Points

- **Provider System**: Streaming events originate from LLM provider stream chunks.
- **Gateway/Webhook**: Streaming enables partial response delivery to connected clients.
- **Telegram Channel**: Voice messages are intercepted, transcribed, and processed
  as text messages via the Transcriber interface.
- **Signal Channel**: SSE client is used for persistent event streaming from
  Signal's API (the connection URL includes account configuration).
- **Configuration**: Voice provider, model, language, and endpoint are configured
  per-deployment.
- **Platform Abstraction**: Temp directory resolution is platform-aware
  (Linux/macOS/other).

---

## Configuration

| Key                          | Type    | Default                | Description                         |
|------------------------------|---------|------------------------|-------------------------------------|
| Voice transcription provider | string  | `"groq"`               | STT provider name                   |
| Voice transcription endpoint | string? | null (auto-resolved)   | Override transcription API URL      |
| Voice transcription model    | string  | `"whisper-large-v3"`   | Whisper model name                  |
| Voice transcription language | string? | null                   | Language hint (ISO 639-1)           |
| Voice transcription API key  | string  | required               | Bearer token for STT API            |

---

## Constraints

- Streaming events are delivered in-order; chunks must not be reordered.
- The TagFilter is stateful and must process a single stream sequentially.
- SSE connections use HTTP/1.1 with chunked transfer encoding.
- SSE read operations are bounded by `MAX_BUFFER_SIZE` (8KB) per call.
- SSE event parsing handles both LF and CRLF line endings.
- Voice temp files include PID for collision avoidance in multi-process deployments.
- Voice transcription failures are non-fatal; they return null rather than
  propagating errors.
- The TagFilter buffer is fixed-size (14 bytes) — sufficient for the longest
  close tag (`</tool_result>` = 14 characters).
