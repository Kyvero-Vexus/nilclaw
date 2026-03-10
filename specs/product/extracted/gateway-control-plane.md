# Gateway & Control Plane Specification

## Overview

The gateway is a lightweight HTTP server that receives inbound messages from
multiple messaging channels (webhooks) and routes them to the agent runtime.
It provides rate limiting, idempotency deduplication, body size enforcement,
request timeouts, and bearer-token authentication. The control plane exposes
slash commands for runtime session control.

The gateway operates in two modes:
1. **Daemon mode** (event bus present): Publishes inbound messages to an
   internal event bus for asynchronous processing by the channel runtime.
2. **Standalone mode** (no event bus): Processes messages synchronously via
   a local session manager and returns responses inline.

---

## Data Model

### Gateway State

| Field                    | Type               | Description                                      |
|--------------------------|--------------------|--------------------------------------------------|
| `rate_limiter`           | GatewayRateLimiter | Dual rate limiter (pair + webhook)               |
| `idempotency`            | IdempotencyStore   | Deduplicates webhook requests                    |
| `pairing_guard`          | PairingGuard?      | Manages bearer-token authentication              |
| `event_bus`              | Bus?               | Event bus for daemon mode (null = standalone)     |
| `whatsapp_verify_token`  | string             | WhatsApp webhook verification token              |
| `whatsapp_app_secret`    | string             | HMAC signing secret for signature verification   |
| `whatsapp_access_token`  | string             | API token for WhatsApp Cloud API calls           |
| `whatsapp_account_id`    | string             | Account identifier (default: `"default"`)        |
| `whatsapp_allow_from`    | list of string     | DM sender allowlist                              |
| `whatsapp_group_allow_from` | list of string  | Group sender allowlist                           |
| `whatsapp_groups`        | list of string     | Allowed group IDs                                |
| `whatsapp_group_policy`  | string             | `"allowlist"`, `"open"`, or `"disabled"`         |
| `telegram_bot_token`     | string             | Telegram Bot API token                           |
| `telegram_account_id`    | string             | Account identifier (default: `"default"`)        |
| `telegram_allow_from`    | list of string     | Telegram sender allowlist (username or numeric ID)|
| `line_channel_secret`    | string             | LINE channel secret for signature verification   |
| `line_access_token`      | string             | LINE Messaging API access token                  |
| `line_account_id`        | string             | Account identifier (default: `"default"`)        |
| `line_allow_from`        | list of string     | LINE sender allowlist                            |
| `lark_verification_token`| string             | Lark event verification token                    |
| `lark_app_id`            | string             | Lark app ID                                      |
| `lark_app_secret`        | string             | Lark app secret                                  |
| `lark_account_id`        | string             | Account identifier (default: `"default"`)        |
| `lark_allow_from`        | list of string     | Lark sender allowlist                            |
| `qq_channels`            | list of QQChannel  | Runtime QQ channel instances                     |

### Rate Limiter

#### Sliding Window Rate Limiter

A per-key sliding-window rate limiter. Tracks request timestamps per key
within a configurable time window.

| Parameter            | Type   | Description                              |
|----------------------|--------|------------------------------------------|
| `limit_per_window`   | u32    | Max requests per window (0 = unlimited)  |
| `window_ns`          | i128   | Window duration in nanoseconds           |
| `entries`            | map    | Key → list of request timestamps         |
| `last_sweep`         | i128   | Timestamp of last stale-entry sweep      |

**Behavior:**
- `allow(key)`: Returns `true` if the request is within the rate limit.
  Removes expired timestamps older than `now - window_ns`. If count < limit,
  records current timestamp and allows. Otherwise rejects.
- If `limit_per_window` is 0, all requests are allowed (rate limiting disabled).
- Periodic sweep every 300 seconds removes keys with no active timestamps.

#### Gateway Rate Limiter

Wraps two independent sliding-window limiters:
- **Pair limiter**: Controls `/pair` endpoint rate.
- **Webhook limiter**: Controls all webhook endpoint rates.

Default rates (from config):
- Pair: 10 per minute
- Webhook: 30 per minute

### Idempotency Store

Deduplicates webhook requests using a key-based TTL store.

| Parameter | Type  | Description                                   |
|-----------|-------|-----------------------------------------------|
| `ttl_ns`  | i128  | Time-to-live in nanoseconds (min 1 second)    |
| `keys`    | map   | Key → recording timestamp                     |

**Behavior:**
- `recordIfNew(key)`: Returns `true` if key is new (and records it).
  Returns `false` if key already exists and hasn't expired.
- On each call, sweeps expired keys (older than TTL).
- Default TTL: 300 seconds (5 minutes).
- Zero TTL is clamped to 1 second minimum.

---

## HTTP Server

### Constants

| Constant                      | Value    | Description                                 |
|-------------------------------|----------|---------------------------------------------|
| `MAX_BODY_SIZE`               | 65,536   | Maximum request body size (64KB)            |
| `MAX_HEADER_SIZE`             | 8,192    | Maximum HTTP header size                    |
| `MAX_HTTP_REQUEST_SIZE`       | 73,728   | MAX_HEADER_SIZE + MAX_BODY_SIZE             |
| `REQUEST_TIMEOUT_SECS`        | 30       | Per-request read timeout (slow-loris guard) |
| `RATE_LIMIT_WINDOW_SECS`      | 60       | Sliding window duration for rate limiting   |
| `RATE_LIMITER_SWEEP_INTERVAL` | 300      | Seconds between stale-entry sweeps          |
| `MAX_OBSERVED_TOOL_EVENTS`    | 512      | Max tool events retained per gateway        |

### Request Processing

1. Accept TCP connection.
2. Set socket read timeout to `REQUEST_TIMEOUT_SECS`.
3. Read HTTP request incrementally:
   - Parse headers to find `Content-Length`.
   - Reject if headers exceed `MAX_HEADER_SIZE`.
   - Reject if `Content-Length` exceeds `MAX_BODY_SIZE`.
   - Reject if total request exceeds `MAX_HTTP_REQUEST_SIZE`.
4. Parse first line for method and target path.
5. Route to handler based on path.
6. Send JSON response and close connection.

### Error Responses

| Condition              | HTTP Status                | Body                                    |
|------------------------|----------------------------|-----------------------------------------|
| Body too large         | 413 Payload Too Large      | `{"error":"request too large"}`         |
| Invalid Content-Length | 400 Bad Request            | `{"error":"invalid content-length"}`    |
| Read timeout           | 408 Request Timeout        | `{"error":"request timeout"}`           |
| Unknown path           | 404 Not Found              | `{"error":"not found"}`                 |
| Wrong HTTP method      | 405 Method Not Allowed     | `{"error":"method not allowed"}`        |
| Rate limited           | 429 Too Many Requests      | `{"error":"rate limited"}`              |
| Unauthorized           | 401 Unauthorized           | `{"error":"unauthorized"}`              |

---

## Endpoints

### GET /health

Returns component health status.

- **Response** (200): `{"status":"ok"}` or `{"status":"degraded"}`
- Checks all registered health components; if any is not `"ok"`, returns `"degraded"`.

### GET /ready

Returns readiness status with per-component checks.

- **Response** (200): `{"status":"ready","checks":[...]}` when all checks pass.
- **Response** (503): `{"status":"not_ready","checks":[...]}` when any check fails.

### POST /pair

Device pairing endpoint. Requires `X-Pairing-Code` header.

- Rate limited via pair limiter.
- **Success** (200): `{"status":"paired","token":"<bearer_token>"}`
- **Errors:**
  - 400: Missing `X-Pairing-Code` header.
  - 401: Invalid pairing code.
  - 403: Pairing disabled.
  - 409: Already paired.
  - 429: Rate limited or locked out (too many failed attempts).
  - 500: Internal pairing failure.

### POST /webhook

Generic webhook endpoint for direct message injection.

- Requires bearer token authentication via `Authorization: Bearer <token>` header.
- Authorization logic:
  - If no `PairingGuard` is configured, **reject** (fail closed).
  - If pairing is not required, **allow** all requests.
  - Otherwise, validate bearer token against paired tokens list.
- Rate limited via webhook limiter.
- Extracts message from body field `"message"` or `"text"` (falls back to raw body).
- Session key: `webhook:<bearer_token>` (or `webhook:anon` if no token).
- **Response** (200): `{"status":"ok","response":"<text>","thread_events":[...]}`
  - `thread_events` contains a tool execution summary: `[{"type":"tool_summary","total":N,"failed":M}]`

### POST /telegram

Telegram Bot API webhook receiver.

- Rate limited via webhook limiter (key: `"telegram"`).
- Only POST method accepted.
- **Multi-account support:** Selects Telegram config by:
  1. `?account_id=<id>` or `?account=<id>` query parameter.
  2. Primary account (account with `account_id = "default"`).
  3. First configured account as fallback.
- **Sender authorization:** If `allow_from` is non-empty, matches sender's
  `username` or numeric `id` against the allowlist. Empty allowlist = allow all.
- **Chat ID extraction:** Parses `message.chat.id` (or `edited_message.chat.id`),
  falls back to flat `chat_id` field.
- **Session key routing:** Uses agent routing engine to resolve session key.
  Format: `telegram:<chat_id>` (fallback) or `agent:<agent_id>:telegram:<scope>:<peer_id>`.
- **Group detection:** Checks `message.chat.type` for `"group"`, `"supergroup"`, or `"channel"`.
- In daemon mode: publishes to event bus with metadata `{"account_id":"...","peer_kind":"...","peer_id":"..."}`.
- In standalone mode: processes via session manager, sends reply via Telegram Bot API `sendMessage`.

### GET|POST /whatsapp

WhatsApp Cloud API webhook receiver.

#### GET (Webhook Verification)

Meta verification handshake:
- Requires query parameters: `hub.mode=subscribe`, `hub.verify_token`, `hub.challenge`.
- If `hub.verify_token` matches configured token, responds with the `hub.challenge` value.
- Otherwise returns 403.

#### POST (Message Delivery)

- Rate limited via webhook limiter (key: `"whatsapp"`).
- **Multi-account support:** Selects WhatsApp config by:
  1. `verify_token` match (for verification requests).
  2. `phone_number_id` field in body.
  3. First configured account as fallback.
- **Signature verification:** If `app_secret` is configured, validates
  `X-Hub-Signature-256` header using HMAC-SHA256:
  - Header format: `sha256=<64-char-hex-digest>`
  - Constant-time comparison to prevent timing attacks.
  - Missing signature when secret is configured → 403.
  - Invalid signature → 403.
- **Sender authorization:** Per-sender allowlist with phone number normalization:
  - Matches with and without `+` prefix.
  - Direct messages: uses `allow_from` list (empty = deny all).
  - Group messages: policy-based (`"allowlist"`, `"open"`, `"disabled"`).
    - `"disabled"`: reject all group messages.
    - `"open"`: allow all senders in allowed groups.
    - `"allowlist"`: check `group_allow_from` (falls back to `allow_from`).
    - Groups list: if non-empty, only listed group IDs are accepted.
- **Session key:** `whatsapp:<sender>` for DMs, `whatsapp:group:<group_id>:<sender>` for groups.
- **Message extraction:** Tries `"text"`, then `"body"` field, then attempts media download.

### POST /slack/events

Slack Events API webhook receiver.

- Rate limited via webhook limiter (key: `"slack"`).
- **Signature verification:** HMAC-SHA256 using Slack signing secret:
  - Base string: `v0:<timestamp>:<body>`
  - Header: `X-Slack-Signature: v0=<hex-digest>`
  - Timestamp header: `X-Slack-Request-Timestamp`
  - Replay window: 300 seconds (5 minutes).
- **URL verification:** Responds to `{"type":"url_verification"}` with challenge response.
- **Event handling:** Processes `event_callback` type with `message` or `app_mention` events.
  - Ignores events with subtypes (edits, bot messages, etc.).
  - Extracts `user`, `text`, and `channel` from the event object.
  - DM detection: `channel_type == "im"` or channel ID starts with `"D"`.
- **Bot self-message filtering:** Extracts bot user ID from `authorizations[0].user_id`
  in the envelope to avoid processing the bot's own messages.
- **Session key:** `slack:<account_id>:direct:<sender_id>` for DMs,
  `slack:<account_id>:channel:<channel_id>` for channels.
- **Custom webhook paths:** Slack configs can specify custom `webhook_path`;
  paths are normalized for matching.

### POST /line

LINE Messaging API webhook receiver.

- Rate limited via webhook limiter (key: `"line"`).
- **Signature verification:** HMAC-SHA256 using channel secret.
  - Header: `X-Line-Signature` (Base64-encoded HMAC).
  - If any configured LINE account has a channel secret, signature is required.
  - Account is selected by which secret validates the signature.
- **Event parsing:** Processes webhook events array; filters by `allow_from` (user IDs).
- **Session key:** `line:<user_id>`.
- **Reply target resolution:**
  - Group source → group ID.
  - Room source → room ID.
  - User source → user ID.
- **Reply mechanism:** Uses LINE reply token for synchronous replies.

### POST /lark

Lark (Feishu) webhook receiver.

- Rate limited via webhook limiter (key: `"lark"`).
- **URL verification:** Responds to payloads containing `"url_verification"` type
  with `{"challenge":"<value>"}`.
- **Token verification:** If `verification_token` is configured, validates
  `header.token` field in the JSON payload. Mismatch → 403.
- **Multi-account support:** Selects config by matching `token` field in payload
  against configured `verification_token`.
- **Session key:** `lark:<sender_id>`.

### POST /qq

QQ Bot webhook receiver.

- Rate limited via webhook limiter (key: `"qq"`).
- **Account selection:** By `?account_id=` query param, `X-Bot-Appid` header,
  primary account, or first configured.
- **Mode gate:** Only processes requests when `receive_mode` is `webhook`.
- **App ID validation:** If `X-Bot-Appid` header is present, must match configured `app_id`.
- **Webhook validation:** Handles challenge/validation responses for QQ's verification protocol.
- **Runtime channel management:** Lazily creates QQ channel instances on first request per account.
- **Invalid JSON payload** → 400 Bad Request.

---

## Authentication

### Bearer Token Validation

- If no paired tokens are configured, all tokens are accepted (backward compatibility).
- Otherwise, exact string match against the paired tokens list.

### Pairing Guard

The pairing guard manages the lifecycle of bearer token authentication:
- Generates a one-time pairing code on startup.
- Validates pairing attempts against the code.
- Issues bearer tokens on successful pairing.
- Supports lockout after too many failed attempts.
- Can be disabled entirely (`require_pairing = false`).

---

## Agent Routing

Session keys are resolved through an agent routing engine that maps
`(channel, account_id, peer)` tuples to agent-specific session keys.

**Route resolution:**
1. Match against configured `agent_bindings` (channel + account + peer pattern).
2. If matched, session key becomes `agent:<agent_id>:<channel>:<scope>:<peer_id>`.
3. Session scope can be further refined by `session.dm_scope` config (e.g., `per_peer`).
4. If no binding matches, falls back to channel-specific default key.

**Peer types:**
- `direct`: DM conversations.
- `group`/`channel`: Multi-user conversations.

---

## Tool Event Observer

The gateway maintains a thread-safe observer that records tool call events
during message processing. Used to enrich webhook responses with execution summaries.

| Field      | Type   | Description                              |
|------------|--------|------------------------------------------|
| `next_seq` | u64    | Monotonically increasing sequence number |
| `events`   | list   | Circular buffer of tool events           |

- Records `tool_call_start` and `tool_call` (result) events.
- Maximum 512 events retained (oldest evicted on overflow).
- Callers can query events since a given sequence number to get
  only events from the current turn.

---

## Control Plane (Slash Commands)

The control plane provides runtime session control via slash commands.
Commands are parsed from message text starting with `/`.

### Command Parsing

- Commands start with `/` followed by the command name.
- Bot mentions in command names are stripped (e.g., `/model@bot_name` → `model`).
- Arguments follow the command name, separated by space or colon.
- Colon separator is consumed (e.g., `/model: gpt-4` → name=`model`, arg=`gpt-4`).

### Available Commands

| Command                       | Description                                    |
|-------------------------------|------------------------------------------------|
| `/new`, `/reset [model]`, `/restart [model]` | Clear history, start fresh session |
| `/help`, `/commands`          | Show available commands                        |
| `/status`                     | Show model and session stats                   |
| `/whoami`, `/id`              | Show current session ID                        |
| `/model`, `/models`           | List or switch model                           |
| `/model <name>`               | Switch to specified model                      |
| `/think`, `/verbose`, `/reasoning` | Set thinking/reasoning level              |
| `/exec`                       | Set exec policy                                |
| `/queue`                      | Set queue policy                               |
| `/usage`                      | Set usage footer mode                          |
| `/tts`, `/voice`              | Set TTS mode                                   |
| `/stop`, `/abort`             | Stop active background task                    |
| `/compact`                    | Compact context window now                     |
| `/allowlist`, `/approve`      | Manage command allowlist                       |
| `/context`                    | Show context info                              |
| `/export-session`, `/export`  | Export session data                            |
| `/session ttl <duration|off>` | Set session time-to-live                       |
| `/subagents`, `/agents`       | List sub-agents                                |
| `/focus`, `/unfocus`          | Focus/unfocus on a sub-agent                   |
| `/kill`, `/steer`, `/tell`    | Manage sub-agents                              |
| `/config`                     | Show configuration                             |
| `/capabilities`               | Show capabilities                              |
| `/debug`                      | Debug info                                     |
| `/dock-telegram`, `/dock-discord`, `/dock-slack` | Channel docking commands      |
| `/activation`                 | Set activation mode                            |
| `/send`                       | Send message                                   |
| `/elevated`, `/bash`          | Elevated/bash mode                             |
| `/poll`, `/skill`             | Polling and skill commands                     |
| `/doctor`                     | Memory subsystem diagnostics                   |
| `/memory <subcommand>`        | Memory operations (stats, status, reindex, count, search, get, list, drain-outbox) |

### Stop Detection

The system provides fast-path detection for stop commands (`/stop`, `/abort`)
including case-insensitive matching and bot-mention stripping, to enable
rapid cancellation of in-flight operations.

---

## Integration Points

- **Config**: Loads channel credentials, rate limits, security policy, agent bindings.
- **Session Manager**: Manages per-conversation agent sessions (standalone mode).
- **Event Bus**: Publishes inbound messages for asynchronous processing (daemon mode).
- **Agent Routing**: Resolves session keys based on channel/account/peer bindings.
- **Pairing Guard**: Manages authentication tokens.
- **Health Registry**: Reports gateway component health and readiness.
- **Provider Bundle**: Initializes LLM provider runtime (standalone mode).
- **Memory Runtime**: Initializes memory backend (standalone mode).
- **Tool System**: Loads available tools (standalone mode).
- **Security Policy**: Enforces autonomy level, rate tracking, command restrictions.
- **Observability**: Records tool call events for response enrichment.

---

## Configuration

| Key                                    | Type       | Default     | Description                                      |
|----------------------------------------|------------|-------------|--------------------------------------------------|
| `gateway.pair_rate_limit_per_minute`   | u32        | 10          | Max pairing requests per minute                  |
| `gateway.webhook_rate_limit_per_minute`| u32        | 30          | Max webhook requests per minute                  |
| `gateway.idempotency_ttl_secs`         | u64        | 300         | Idempotency key TTL in seconds                   |
| `gateway.require_pairing`              | bool       | true        | Whether pairing is required for webhook access   |
| `gateway.paired_tokens`               | list       | []          | Pre-configured bearer tokens                     |
| `channels.telegram[].bot_token`        | string     | required    | Telegram Bot API token                           |
| `channels.telegram[].account_id`       | string     | `"default"` | Account identifier                               |
| `channels.telegram[].allow_from`       | list       | []          | Sender allowlist (empty = allow all)             |
| `channels.whatsapp[].verify_token`     | string     | required    | Webhook verification token                       |
| `channels.whatsapp[].app_secret`       | string?    | null        | HMAC signing secret                              |
| `channels.whatsapp[].access_token`     | string     | required    | Cloud API access token                           |
| `channels.whatsapp[].phone_number_id`  | string     | required    | Phone number ID for account matching             |
| `channels.whatsapp[].account_id`       | string     | `"default"` | Account identifier                               |
| `channels.whatsapp[].allow_from`       | list       | []          | DM sender allowlist (empty = deny all)           |
| `channels.whatsapp[].group_allow_from` | list       | []          | Group sender allowlist                           |
| `channels.whatsapp[].groups`           | list       | []          | Allowed group IDs                                |
| `channels.whatsapp[].group_policy`     | string     | `"allowlist"`| Group access policy                             |
| `channels.slack[].signing_secret`      | string?    | null        | HMAC signing secret                              |
| `channels.slack[].webhook_path`        | string     | `/slack/events` | Custom webhook path                         |
| `channels.slack[].mode`                | enum       | `http`      | Connection mode (`http` for webhooks)            |
| `channels.slack[].account_id`          | string     | `"default"` | Account identifier                               |
| `channels.line[].channel_secret`       | string     | `""`        | Channel secret for signature verification        |
| `channels.line[].access_token`         | string     | `""`        | Messaging API access token                       |
| `channels.line[].account_id`           | string     | `"default"` | Account identifier                               |
| `channels.line[].allow_from`           | list       | []          | Sender allowlist                                 |
| `channels.lark[].verification_token`   | string?    | null        | Event verification token                         |
| `channels.lark[].app_id`              | string     | required    | Lark app ID                                      |
| `channels.lark[].app_secret`          | string     | required    | Lark app secret                                  |
| `channels.lark[].account_id`          | string     | `"default"` | Account identifier                               |
| `channels.lark[].allow_from`          | list       | []          | Sender allowlist                                 |
| `channels.qq[].app_id`               | string     | required    | QQ Bot app ID                                    |
| `channels.qq[].app_secret`           | string     | required    | QQ Bot app secret                                |
| `channels.qq[].account_id`           | string     | `"default"` | Account identifier                               |
| `channels.qq[].receive_mode`         | enum       | `websocket` | Receive mode (`webhook` or `websocket`)          |
| `agent_bindings[]`                    | object     | []          | Agent routing bindings                           |
| `session.dm_scope`                    | enum       | `per_channel`| DM session scope                                |

---

## Constraints

- All requests must complete within 30 seconds (socket timeout).
- Request bodies cannot exceed 64KB.
- Request headers cannot exceed 8KB.
- Rate limiters are per-IP for pairing and per-channel-type for webhooks.
- Signature verification uses constant-time comparison (timing-attack resistant).
- The gateway processes requests sequentially on a single accept loop;
  each request gets a per-request arena allocator that is freed after the response.
- In standalone mode, the gateway initializes the full agent runtime (provider,
  tools, memory, security policy, sub-agent manager) at startup.
- YOLO autonomy mode prints a prominent warning on startup.
