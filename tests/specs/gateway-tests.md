# Gateway Test Specifications

## Overview
The gateway module handles inbound HTTP webhook requests from messaging platforms (Telegram, WhatsApp, Slack, Line, Lark, QQ), rate limiting, request parsing, signature verification, session routing, and health checking. It is the primary entry point for external traffic.

## Constants

### System limits are correctly defined
- **MAX_BODY_SIZE**: must equal 65,536 bytes (64 KB)
- **RATE_LIMIT_WINDOW_SECS**: must equal 60
- **REQUEST_TIMEOUT_SECS**: must equal 30

---

## Rate Limiter (Sliding Window)

### Allows up to the configured limit
- **Setup**: Create a rate limiter with limit=2, window=60s
- **Action**: Make 3 requests from the same key ("127.0.0.1")
- **Expected**: First 2 requests allowed, 3rd request denied

### Zero limit always allows
- **Setup**: Create a rate limiter with limit=0, window=60s
- **Action**: Make 100 requests from the same key
- **Expected**: All 100 requests are allowed (zero means unlimited)

### Different keys are independent
- **Setup**: Create a rate limiter with limit=1, window=60s
- **Action**: Request from "ip-1" (allowed), request from "ip-1" again (denied), request from "ip-2"
- **Expected**: First "ip-1" allowed, second "ip-1" denied, "ip-2" allowed

### Single request allowed
- **Setup**: Create a rate limiter with limit=1, window=60s
- **Action**: Make 2 requests from the same key
- **Expected**: First allowed, second denied

### High limit
- **Setup**: Create a rate limiter with limit=100, window=60s
- **Action**: Make 101 requests from the same key
- **Expected**: First 100 allowed, 101st denied

### Different keys do not interfere
- **Setup**: Create a rate limiter with limit=2, window=60s
- **Action**: Request key-a, request key-b, request key-a again (2nd for key-a), request key-a (3rd)
- **Expected**: key-a's 3rd request denied, key-b still has room for another request

### Window duration calculation
- **Setup**: Create a rate limiter with limit=10, window=120s
- **Expected**: Internal window stored as 120,000,000,000 nanoseconds

---

## Gateway Rate Limiter (Dual: Pair + Webhook)

### Blocks after limit (pair endpoint)
- **Setup**: Create gateway rate limiter with pair_limit=2, webhook_limit=2
- **Action**: Make 3 pair requests from same IP
- **Expected**: First 2 pair requests allowed, 3rd denied

### Pair and webhook are independent
- **Setup**: Create gateway rate limiter with pair_limit=1, webhook_limit=1
- **Action**: Exhaust pair limit for an IP, then make webhook request from same IP
- **Expected**: Pair denied after limit, but webhook still allowed (and vice versa)

### Zero limits always allow
- **Setup**: Create gateway rate limiter with pair_limit=0, webhook_limit=0
- **Action**: Make 50 pair requests and 50 webhook requests
- **Expected**: All allowed (zero means unlimited for both)

---

## Idempotency Store

### Rejects duplicate key
- **Setup**: Create idempotency store with TTL=30s
- **Action**: Record "req-1", then try to record "req-1" again, then record "req-2"
- **Expected**: First "req-1" accepted, second "req-1" rejected, "req-2" accepted

### Allows different keys
- **Setup**: Create idempotency store with TTL=300s
- **Action**: Record keys "a", "b", "c", then try "a" again
- **Expected**: "a", "b", "c" all accepted on first insert; "a" rejected on second attempt

### TTL ordering
- **Setup**: Create stores with TTL=1s and TTL=3600s
- **Expected**: The internal TTL (in nanoseconds) of the 3600s store is greater than the 1s store

### Zero TTL treated as 1 second minimum
- **Setup**: Create idempotency store with TTL=0
- **Expected**: Internal TTL is 1,000,000,000 nanoseconds (1 second)

### Many unique keys accepted
- **Setup**: Create idempotency store with TTL=300s
- **Action**: Record 5 distinct keys
- **Expected**: All 5 accepted

### Duplicate detected after many inserts
- **Setup**: Create idempotency store with TTL=300s
- **Action**: Record "first", "second", "third", then try "first" again
- **Expected**: "first" is still rejected (not evicted by subsequent inserts)

---

## Webhook Route Resolution

### Resolves known webhook paths
- **Action**: Look up route descriptors for platform paths
- **Expected**: `/telegram`, `/whatsapp`, `/slack/events`, `/line`, `/lark`, `/qq` all resolve to a descriptor; `/health` does not resolve (returns null)

---

## Query Parameter Parsing

### Extracts single parameter
- **Input**: `/whatsapp?hub.mode=subscribe`, param `hub.mode`
- **Expected**: Returns `"subscribe"`

### Extracts parameter from multiple
- **Input**: `/whatsapp?hub.mode=subscribe&hub.verify_token=mytoken&hub.challenge=abc123`
- **Expected**: Each param returns its correct value

### Returns null for missing parameter
- **Input**: `/whatsapp?hub.mode=subscribe`, param `hub.challenge`
- **Expected**: Returns null

### Returns null when no query string
- **Input**: `/whatsapp`, any param
- **Expected**: Returns null

### Empty value
- **Input**: `/path?key=`, param `key`
- **Expected**: Returns empty string (not null)

### Partial key match does not match
- **Input**: `/path?hub.mode_extra=subscribe`, param `hub.mode`
- **Expected**: Returns null (exact key match required)

---

## Gateway State

### Initialization with verify token
- **Action**: Create GatewayState with verify token "test-verify-token"
- **Expected**: `whatsapp_verify_token` field equals "test-verify-token"

### Default initialization
- **Action**: Create GatewayState with default init
- **Expected**: `whatsapp_verify_token` is empty string, `telegram_bot_token` is empty string, `whatsapp_app_secret` is empty string, `event_bus` is null

---

## Bearer Token Validation

### Allows when no paired tokens configured
- **Setup**: Empty token list
- **Action**: Validate any token
- **Expected**: Allowed (open access when no tokens configured)

### Allows valid token
- **Setup**: Token list ["token-a", "token-b", "token-c"]
- **Action**: Validate "token-b"
- **Expected**: Allowed

### Rejects invalid token
- **Setup**: Token list ["token-a", "token-b"]
- **Action**: Validate "token-c"
- **Expected**: Rejected

### Rejects empty token when tokens are configured
- **Setup**: Token list ["secret"]
- **Action**: Validate empty string
- **Expected**: Rejected

### Exact match required
- **Setup**: Token list ["abc123"]
- **Expected**: "abc123" allowed, "abc1234" rejected, "abc12" rejected

---

## Webhook Authorization

### Fails closed when pairing guard is missing
- **Action**: Call isWebhookAuthorized with null guard and a token
- **Expected**: Returns false (fail closed)

### Allows when pairing is disabled
- **Setup**: Create pairing guard with pairing disabled
- **Action**: Call isWebhookAuthorized with null token
- **Expected**: Returns true (no auth needed)

### Requires valid bearer token when pairing is enabled
- **Setup**: Create pairing guard with pairing enabled, accepted tokens ["zc_valid"]
- **Expected**: "zc_valid" authorized, null token rejected, "zc_invalid" rejected

---

## Pair Success Response

### Includes paired token in JSON
- **Action**: Format pair success response with token "zc_token_123"
- **Expected**: Returns `{"status":"paired","token":"zc_token_123"}`

### Fails when buffer is too small
- **Action**: Format pair success response with 8-byte buffer
- **Expected**: Returns null (buffer overflow protection)

---

## HTTP Header Extraction

### Finds Authorization header
- **Input**: Raw HTTP request with `Authorization: Bearer secret123`
- **Expected**: Returns `"Bearer secret123"`

### Case insensitive header matching
- **Input**: Raw HTTP request with `content-type: text/plain`, search for `Content-Type`
- **Expected**: Returns `"text/plain"`

### Returns null for missing header
- **Input**: Raw HTTP request without Authorization header
- **Expected**: Returns null

### Returns null for empty headers
- **Input**: Minimal HTTP request with no headers
- **Expected**: Returns null

---

## Bearer Token Extraction

### Extracts token from Bearer string
- **Input**: `"Bearer mytoken"`
- **Expected**: Returns `"mytoken"`

### Returns null for non-Bearer scheme
- **Input**: `"Basic abc123"`
- **Expected**: Returns null

### Returns null for empty string
- **Input**: `""`
- **Expected**: Returns null

### Returns null for "Bearer" without space/token
- **Input**: `"Bearer"` (no trailing space)
- **Expected**: Returns null

---

## JSON Field Extraction

### String field extraction
- **Input**: `{"message": "hello world"}`, key `"message"`
- **Expected**: Returns `"hello world"`

### Returns null for missing string key
- **Input**: `{"other": "value"}`, key `"message"`
- **Expected**: Returns null

### Handles nested JSON (finds first occurrence)
- **Input**: `{"message": {"text": "hi"}, "text": "direct"}`, key `"text"`
- **Expected**: Returns `"hi"` (finds nested value first)

### Integer field extraction (positive)
- **Input**: `{"chat_id": 12345}`, key `"chat_id"`
- **Expected**: Returns 12345

### Integer field extraction (negative)
- **Input**: `{"offset": -100}`, key `"offset"`
- **Expected**: Returns -100

### Returns null for missing integer key
- **Input**: `{"other": 42}`, key `"chat_id"`
- **Expected**: Returns null

### Returns null when integer field has string value
- **Input**: `{"chat_id": "not a number"}`, key `"chat_id"`
- **Expected**: Returns null

---

## Multi-Account Channel Selection

### WhatsApp: picks account by phone_number_id
- **Setup**: Two WhatsApp accounts with phone_number_ids "111" and "222"
- **Action**: Incoming webhook body contains `phone_number_id: "222"` in metadata
- **Expected**: Selects the account with phone_number_id "222" (account_id "backup")

### WhatsApp: picks account by verify_token
- **Setup**: Two WhatsApp accounts with different verify tokens
- **Action**: Select config using verify_token "verify-b"
- **Expected**: Selects the matching account

### Telegram: picks account by query account_id
- **Setup**: Two Telegram accounts ("main", "backup")
- **Action**: Request path `/telegram?account_id=backup`
- **Expected**: Selects "backup" account

### Telegram: falls back to preferred primary account
- **Setup**: Two Telegram accounts ("z-last", "default"), no account_id in query
- **Action**: Request path `/telegram`
- **Expected**: Selects "default" as the preferred primary account

### Line: matches account by HMAC signature
- **Setup**: Two Line accounts with different channel secrets
- **Action**: Request body signed with "secret-b"
- **Expected**: Selects the account whose channel secret produced a valid HMAC-SHA256 signature; invalid signature returns null

### Lark: picks account by verification token
- **Setup**: Two Lark accounts with different verification tokens
- **Action**: Request body contains `header.token: "token-b"`
- **Expected**: Selects the matching account

### QQ: picks account by X-Bot-Appid header
- **Setup**: Two QQ accounts with app_ids "app-main" and "app-backup"
- **Action**: Header contains `X-Bot-Appid: app-backup`
- **Expected**: Selects "app-backup" account

### QQ: falls back to primary account
- **Setup**: Two QQ accounts ("z-last", "default"), no appid header
- **Expected**: Selects "default" as the primary

### QQ: rejects invalid JSON payload
- **Setup**: QQ account configured in webhook mode
- **Action**: POST invalid JSON body `{invalid`
- **Expected**: Returns 400 Bad Request with `{"error":"invalid json payload"}`

---

## Slack Configuration

### hasSlackHttpEndpoint respects mode and webhook_path
- **Setup**: One Slack account in HTTP mode with custom webhook_path `/slack/custom`, one in socket mode
- **Expected**: `/slack/custom` matches, `/slack/events` does not match, `/line` does not match

### findSlackConfigForRequest selects account by verified signature
- **Setup**: Two Slack accounts ("a", "b") sharing same webhook_path, request signed with account b's secret
- **Action**: Request with valid HMAC for secret_b
- **Expected**: Selects account "b" based on signature verification

---

## Session Key Construction

### WhatsApp: direct key by sender
- **Input**: Message body with `from: "15550001111"`, no group
- **Expected**: Session key = `"whatsapp:15550001111"`

### WhatsApp: group key includes group ID and sender
- **Input**: Message body with `from: "15550001111"`, `context.group_jid: "1203630@g.us"`
- **Expected**: Session key = `"whatsapp:group:1203630@g.us:15550001111"`

### WhatsApp: routed key falls back without config
- **Input**: Message body with sender, no routing config
- **Expected**: Falls back to basic session key format `"whatsapp:15550001111"`

### WhatsApp: routed key uses route engine when config exists
- **Setup**: Agent binding matching channel=whatsapp, account_id=wa-prod, peer=group:1203630@g.us → agent "wa-agent"
- **Expected**: Session key = `"agent:wa-agent:whatsapp:group:1203630@g.us"`

### WhatsApp: routed key uses nested context.group_jid
- **Setup**: Message with `context.group_jid`, agent binding matching that group
- **Expected**: Session key includes the context group_jid for routing

### Telegram: routed uses group peer for group chats
- **Setup**: Message from supergroup chat -10012345, agent binding for that group
- **Expected**: Session key = `"agent:tg-group-agent:telegram:group:-10012345"`

### Telegram: routed uses direct peer for private chats
- **Setup**: Private chat from user 4242, agent binding for direct peer
- **Expected**: Session key = `"agent:tg-dm-agent:telegram:direct:4242"`

### Telegram: routed applies session dm_scope for direct chats
- **Setup**: Private chat with dm_scope=per_peer in session config
- **Expected**: Session key = `"agent:tg-dm-agent:direct:4242"` (no channel prefix when per_peer)

### Line: routed uses group ID for group events
- **Setup**: Group event from user U111 in group G222, agent binding for that group
- **Expected**: Session key = `"agent:line-group-agent:line:group:group:G222"`

### Line: falls back to user session key without config
- **Setup**: User event from U777, no routing config
- **Expected**: Session key = `"line:U777"`

### Line: routed uses room-prefixed peer ID for room events
- **Setup**: Room event in room R333, agent binding for `room:R333`
- **Expected**: Session key = `"agent:line-room-agent:line:group:room:R333"`

### Lark: routed uses route engine when config exists
- **Setup**: Group message from `ou_abc123`, agent binding for that peer
- **Expected**: Session key = `"agent:lark-group-agent:lark:group:ou_abc123"`

---

## Line Reply Target Resolution

### Group events → group ID
- **Input**: Group event with user_id=U111, group_id=G222
- **Expected**: Reply target = `"G222"`

### Room events → room ID
- **Input**: Room event with user_id=U111, room_id=R333
- **Expected**: Reply target = `"R333"`

### Direct events → user ID
- **Input**: Direct user event with user_id=U111
- **Expected**: Reply target = `"U111"`

---

## Sender Filtering

### Telegram: permits when allow_from is empty
- **Setup**: Empty allow_from list
- **Action**: Any sender sends a message
- **Expected**: Allowed (empty list = open access)

### Telegram: extracts nested chat ID
- **Input**: Body with `message.chat.id: -100777`
- **Expected**: Returns -100777

### Telegram: falls back to flat chat_id
- **Input**: Body with top-level `chat_id: 12345`
- **Expected**: Returns 12345 (backward compatibility)

### Telegram: matches numeric sender ID from nested from object
- **Setup**: allow_from = ["12345"]
- **Input**: Body with `message.from.id: 12345`
- **Expected**: Allowed

### Telegram: does not confuse chat ID with sender ID
- **Setup**: allow_from = ["-100777"] (the chat ID, not sender ID)
- **Input**: Body with `message.from.id: 12345`, `message.chat.id: -100777`
- **Expected**: Rejected (chat ID is not sender ID)

### Telegram: rejects sender outside allowlist
- **Setup**: allow_from = ["alice"]
- **Input**: Body with `message.from.id: 12345` (no matching username)
- **Expected**: Rejected

### Telegram: falls back to numeric ID when username is missing
- **Input**: Body without `username` field in `from` object, only `id: 12345`
- **Expected**: Sender identity = `"12345"` (string representation of numeric ID)

### WhatsApp: direct respects allow_from
- **Setup**: allow_from = ["+1111111111"]
- **Expected**: "+1111111111" allowed, "+2222222222" denied

### WhatsApp: direct denies all when allow_from is empty
- **Setup**: Empty allow_from
- **Expected**: All direct messages denied

### WhatsApp: group open policy bypasses allow_from
- **Setup**: allow_from = ["+1111111111"], group_policy = "open"
- **Action**: "+2222222222" sends in a group
- **Expected**: Allowed (open policy bypasses sender check)

### WhatsApp: open policy still respects explicit groups allowlist
- **Setup**: groups allowlist = ["1203630@g.us"], group_policy = "open"
- **Expected**: Messages in "1203630@g.us" allowed, messages in "1203631@g.us" denied

### WhatsApp: group allowlist uses both groups and sender allowlists
- **Setup**: allow_from = ["+1111111111"], group_allow = ["+3333333333"], groups = ["1203630@g.us"], policy = "allowlist"
- **Expected**:
  - "+3333333333" in group "1203630@g.us" → allowed (in group_allow)
  - "+1111111111" in group "1203630@g.us" with group_allow set → denied (not in group_allow)
  - "+1111111111" in group "1203630@g.us" with empty group_allow → allowed (falls back to allow_from)
  - "+1111111111" in unlisted group → denied
  - Unknown sender in listed group → denied
  - "+1111111111" in listed group but no groups list → denied

### WhatsApp: matches with and without plus prefix
- **Setup**: One allow_from has "+", other doesn't
- **Expected**: Matching works regardless of leading "+" on either side

---

## HTTP Body Extraction

### Finds body after header separator
- **Input**: HTTP request with `\r\n\r\n` separator followed by `{"message":"hi"}`
- **Expected**: Returns `{"message":"hi"}`

### Returns null for empty body
- **Input**: HTTP request ending with `\r\n\r\n` (separator but no content after)
- **Expected**: Returns null

### Returns null when no separator exists
- **Input**: HTTP request without `\r\n\r\n` separator
- **Expected**: Returns null

---

## HTTP Request Size Calculation

### Returns null when headers are incomplete
- **Input**: HTTP data without `\r\n\r\n` terminator
- **Expected**: Returns null (still receiving headers)

### Rejects oversized incomplete headers
- **Input**: Data exceeding MAX_HEADER_SIZE without completing headers
- **Expected**: Returns RequestTooLarge error

### Returns header length for bodyless requests
- **Input**: Complete GET request with `\r\n\r\n`
- **Expected**: Returns total length equal to header bytes

### Includes content length payload
- **Input**: POST request with `Content-Length: 5` and 5-byte body
- **Expected**: Returns total length = header length + 5

### Rejects invalid content length
- **Input**: `Content-Length: abc`
- **Expected**: Returns InvalidContentLength error

### Rejects oversized content length
- **Input**: `Content-Length: 999999`
- **Expected**: Returns RequestTooLarge error

---

## HTTP Request Reader

### Assembles fragmented request
- **Setup**: Reader delivers a full HTTP request in 3 chunks
- **Expected**: Assembled result matches the complete request

### Returns IncompleteRequest for truncated body
- **Setup**: Reader delivers headers declaring Content-Length: 8 but only 3 bytes of body, then EOF
- **Expected**: Returns IncompleteRequest error

### Maps WouldBlock to RequestTimeout
- **Setup**: Reader immediately returns WouldBlock
- **Expected**: Returns RequestTimeout error

---

## User-Facing Error Messages

### ProviderDoesNotSupportVision → "The current provider does not support image input."
### NoResponseContent → "Model returned an empty response. Please try again."
### AllProvidersFailed → "All configured providers failed for this request. Check model/provider compatibility and credentials."
### Generic error → "An error occurred. Try again."

### JSON variants:
- NoResponseContent → `{"error":"model returned empty response"}`
- AllProvidersFailed → `{"error":"all providers failed for this request"}`
- Generic → `{"error":"agent failure"}`

---

## Case-Insensitive ASCII Comparison

### Equal strings with different case
- `"Authorization"` equals `"authorization"`, `"CONTENT-TYPE"` equals `"content-type"`, `"Host"` equals `"Host"`

### Different strings
- `"Authorization"` does not equal `"authenticate"`, `"a"` does not equal `"ab"`

### Empty strings are equal

---

## WhatsApp HMAC-SHA256 Signature Verification

### Valid signature accepted
- **Setup**: Compute HMAC-SHA256 of body with correct secret, format as `sha256=<hex>`
- **Expected**: Verification passes

### Invalid signature rejected
- **Setup**: All-zeros signature
- **Expected**: Verification fails

### Missing sha256= prefix rejected
- **Expected**: Raw hex without prefix → verification fails

### Empty body with valid signature
- **Setup**: Empty body, correct HMAC
- **Expected**: Verification passes

### Empty secret returns false
- **Expected**: Any body/signature with empty secret → verification fails

### Wrong secret rejected
- **Setup**: Signature computed with correct_secret, verified with wrong_secret
- **Expected**: Verification fails

### Constant-time comparison correctness
- Identical MACs pass, single-bit-flip in last or first byte fails

### Hex encoding edge cases
- Truncated hex → fails
- Too long hex → fails
- Invalid hex characters → fails
- Empty signature → fails
- Just "sha256=" with no hex → fails

### Uppercase hex accepted
- HMAC formatted with uppercase hex letters → verification passes

---

## Slack Signature Verification

### Accepts valid signature
- **Setup**: Compute `v0=HMAC-SHA256(signing_secret, "v0:{timestamp}:{body}")`, current timestamp
- **Expected**: Verification passes

### Rejects stale timestamp
- **Setup**: Timestamp 900 seconds in the past, correct signature
- **Expected**: Verification fails (replay protection)

---

## Event Bus Publishing

### Creates inbound message on bus
- **Action**: Publish message with channel="telegram", sender="user1", chat="chat42", content="hello", session_key="telegram:chat42"
- **Expected**: Message consumable from bus with all fields matching

### With metadata
- **Action**: Publish message with metadata `{"account_id":"personal"}`
- **Expected**: Consumed message has metadata_json field matching the input

---

## JSON Escaping

### Escapes double quotes
- `hello "world"` → `hello \"world\"`

### Escapes backslashes
- `path\to\file` → `path\\to\\file`

### Escapes newlines and tabs
- `line1\nline2\ttab` → `line1\\nline2\\ttab`

### Escapes control characters as unicode
- Bytes 0x00, 0x01, 0x1F → `\u0000\u0001\u001f`

### Empty string yields empty output

### Passes through unicode and emoji unchanged
- UTF-8 characters and emoji pass through without escaping

### Escapes carriage return
- `\r\n` → `\\r\\n`

### Escapes backspace and form feed
- 0x08 → `\b`, 0x0C → `\f`

### Mixed special characters
- Combination of quotes, backslashes, and newlines all escaped correctly

---

## JSON Wrapping Utilities

### jsonWrapField produces valid JSON field
- Key "msg", value `hello "world"` → `"msg":"hello \"world\""`

### jsonWrapField with empty value
- Key "key", value "" → `"key":""`

### jsonWrapField result is valid JSON when wrapped
- Wrapped in braces produces parseable JSON with correct string value

### jsonWrapResponse produces valid JSON with escaped content
- Input with quotes and newlines → parseable JSON with status "ok" and response field containing unescaped original content

### jsonWrapResponse with clean input
- `"simple reply"` → `{"status":"ok","response":"simple reply"}`

### jsonWrapChallenge produces valid JSON
- Challenge "abc123" → `{"challenge":"abc123"}`

### jsonWrapChallenge escapes malicious challenge value
- Input `abc","evil":"true` → properly escaped, no injection (parsed JSON has no "evil" key)

---

## Gateway Thread Observer

### Init/deinit without leaks
- Create and immediately destroy observer — no memory leaks

### Records tool events and collectSince works
- **Action**: Record a tool_call_start and tool_call event
- **Expected**: collectSince returns 2 events with correct tool names, kinds (start/result), and success flag

### collectSince filters by sequence number
- **Action**: Record event1, capture mid-sequence, record event2
- **Expected**: collectSince(mid_seq) returns only event2

### collectSince OOM frees partial output
- **Setup**: Inject allocation failure after 2 allocations
- **Expected**: Returns OutOfMemory error without leaking partial allocations

---

## Thread Events JSON Building

### Empty events → `"[]"`

### With tool results
- **Input**: 3 events (1 start, 2 results — 1 success, 1 failure)
- **Expected**: JSON array with 1 tool_summary object: total=2, failed=1

### Webhook success response includes thread_events
- **Action**: Build response with content "hello" and events "[]"
- **Expected**: JSON has status "ok", response "hello", and thread_events array
