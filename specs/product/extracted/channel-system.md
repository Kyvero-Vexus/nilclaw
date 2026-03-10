---
Layer: L1
Lane: contracts
Spec ID: L1-EXT-channel-system
Status: draft
Last Updated: 2026-03-10
Traceability:
  L0: [F-CH-MULTICHANNEL, F-ROUTING-AGENT, C-SAFE-EXTERNAL-ACTION-GATING]
---

# Channel System Specification

## Overview

Channels are messaging platform integrations that receive and send messages.
Each channel implements a vtable-based polymorphic interface. The system
supports multiple concurrent channels with per-channel permission policies,
allowlists, and message dispatch.

## Channel Interface

### VTable Methods

| Method         | Signature                                        | Required | Description                |
|----------------|--------------------------------------------------|----------|----------------------------|
| `start`        | () → void                                        | Yes      | Connect and begin listening|
| `stop`         | () → void                                        | Yes      | Disconnect and clean up    |
| `send`         | (target, message, media[]) → void                | Yes      | Send message to target     |
| `name`         | () → string                                      | Yes      | Channel name identifier    |
| `healthCheck`  | () → bool                                        | Yes      | Check if operational       |
| `sendEvent`    | (target, message, media[], stage) → void         | Optional | Staged outbound delivery   |
| `startTyping`  | (recipient) → void                               | Optional | Show typing indicator      |
| `stopTyping`   | (recipient) → void                               | Optional | Hide typing indicator      |

### OutboundStage (Streaming)

When `sendEvent` is implemented:
- `chunk` — intermediate streaming delta (may be ignored)
- `final` — complete message delivery

When `sendEvent` is null, runtime falls back to `send()` for `final` stage
and ignores `chunk` events.

### ChannelMessage

| Field          | Type    | Description                        |
|----------------|---------|------------------------------------|
| `id`           | string  | Message identifier                 |
| `sender`       | string  | Sender identifier                  |
| `content`      | string  | Message text content               |
| `channel`      | string  | Channel name                       |
| `timestamp`    | u64     | Unix timestamp                     |
| `reply_target` | string? | Where to send reply                |
| `message_id`   | i64?    | Platform message ID (for replies)  |
| `first_name`   | string? | Sender's first name                |
| `is_group`     | bool    | Whether from group chat            |
| `sender_uuid`  | string? | Signal-specific sender UUID        |
| `group_id`     | string? | Signal-specific group ID           |

## Built-in Channels

| Channel     | Transport           | Key Features                                |
|-------------|---------------------|---------------------------------------------|
| CLI         | stdin/stdout        | Built-in, always available                  |
| Telegram    | Long-polling        | Streaming, typing, media, group mentions    |
| Discord     | WebSocket gateway   | Intents, guild roles, thread support        |
| Slack       | Socket/HTTP mode    | Bot/app token, signing secret               |
| WhatsApp    | Webhook             | Meta signature verification                 |
| Matrix      | Long-polling /sync  | Room-based, access token auth               |
| IRC         | TLS socket          | NickServ/SASL auth, multi-channel           |
| iMessage    | AppleScript+SQLite  | macOS only                                  |
| Email       | IMAP/SMTP           | Polling interval, folder watching            |
| Signal      | HTTP API            | Privacy-aware (UUID sender support)         |
| Nostr       | Relay WebSocket     | Encrypted DMs, relay list, owner pubkey     |
| Mattermost  | WebSocket+REST      | Team/channel based                          |
| Lark/Feishu | HTTP callback       | Enterprise messaging                        |
| DingTalk    | WebSocket stream    | Enterprise messaging                        |
| Line        | Webhook             | Rich messaging                              |
| OneBot      | WebSocket           | QQ/WeChat bridge protocol                   |
| QQ          | Native              | QQ-specific                                 |
| Web         | WebSocket           | Browser-based, relay/local transport        |
| MaixCam     | Serial              | Hardware device channel                     |

## Permission System

### DM Policy

| Policy     | Behavior                              |
|------------|---------------------------------------|
| `allow`    | Allow all direct messages             |
| `deny`     | Deny all direct messages              |
| `allowlist`| Only allow senders in the allowlist   |

### Group Policy

| Policy        | Behavior                                 |
|---------------|------------------------------------------|
| `open`        | Allow all group messages                 |
| `mention_only`| Only respond when explicitly mentioned   |
| `allowlist`   | Only allow senders in the allowlist      |

### Permission Check Flow

```
checkPolicy(policy, sender_id, is_dm, is_mention)
  DM:
    allow → true
    deny → false
    allowlist → inAllowlist(sender_id)
  Group:
    open → true
    mention_only → is_mention
    allowlist → inAllowlist(sender_id)
```

### Allowlist Matching

- `"*"` wildcard matches all senders
- Case-insensitive string comparison (default)
- Case-sensitive exact match available via `isAllowedExact()`

## Multi-Account Support

Channels with multi-account support use nested configuration:
```json
{
  "channels": {
    "<type>": {
      "accounts": {
        "<account_id>": { ... }
      }
    }
  }
}
```

Account selection priority: `"default"` → `"main"` → first entry.

## Message Splitting

Large messages are split at `max_bytes` boundaries respecting UTF-8
character boundaries:
- Walk backwards from split point to find valid UTF-8 boundary
- If no boundary found going backward, advance forward
- Returns iterator of message chunks

## Channel Dispatch

The dispatch module routes inbound messages to the appropriate handler:
1. Identify channel by name
2. Apply permission policy (DM/group check)
3. Route to session manager for processing
4. Deliver response back through the same channel

## Channel Lifecycle

1. **Configuration**: Channel config loaded from config file
2. **Initialization**: Channel struct created with config
3. **Start**: `channel.start()` — connect to platform
4. **Processing**: Receive messages → dispatch → send responses
5. **Health check**: Periodic `channel.healthCheck()` monitoring
6. **Stop**: `channel.stop()` — graceful disconnect

## Reconnection

Channels implement reconnection with exponential backoff:
- Initial backoff: `channel_initial_backoff_secs` (default 2)
- Max backoff: `channel_max_backoff_secs` (default 60)

## Integration Points

- **Session manager**: channels route messages through sessions
- **Event bus**: channels publish/consume via the event bus
- **Config**: `channels.*` section configures each channel
- **Gateway**: webhook-based channels (WhatsApp) use gateway endpoints
- **Streaming**: channels with `sendEvent` support streaming responses
- **Agent routing**: channel + account used for agent binding resolution
