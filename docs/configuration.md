# Configuration

NilClaw is compatible with OpenClaw config structure and uses `snake_case` keys.

## Page Guide

**Who this page is for**

- Users creating or editing the main `config.json`
- Operators tuning channels, gateway behavior, and autonomy limits
- Migrators mapping existing OpenClaw-style settings into NilClaw

**Read this next**

- Open [Usage and Operations](./usage.md) after config edits to validate runtime behavior
- Open [Security](./security.md) before widening permissions, public exposure, or tool scope
- Open [Gateway API](./gateway-api.md) if your config changes affect pairing, webhooks, or external integrations

**If you came from ...**

- [Installation](./installation.md): this page takes over once `nilclaw` is installed and ready for first-run setup
- [README](./README.md): this is the detailed config path after choosing the operator/user docs route
- [Gateway API](./gateway-api.md): come back here when the API workflow depends on concrete `gateway` or channel settings

## Config File Path

- macOS/Linux: `~/.nilclaw/config.json`
- Windows: `%USERPROFILE%\.nilclaw\config.json`

Recommended first step:

```lisp
;; In SBCL REPL
(nilclaw/config:initialize-default-config)
```

This generates your initial config file.

## Minimal Working Config

The example below is enough to run local CLI mode (replace API key):

```json
{
  "models": {
    "providers": {
      "openrouter": {
        "api_key": "YOUR_OPENROUTER_API_KEY"
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/anthropic/claude-sonnet-4"
      }
    }
  },
  "channels": {
    "cli": true
  },
  "memory": {
    "backend": "sqlite",
    "auto_save": true
  },
  "gateway": {
    "host": "127.0.0.1",
    "port": 3000,
    "require_pairing": true
  },
  "autonomy": {
    "level": "supervised",
    "workspace_only": true,
    "max_actions_per_hour": 20
  },
  "security": {
    "sandbox": {
      "backend": "auto"
    },
    "audit": {
      "enabled": true
    }
  }
}
```

## Core Sections

### `models.providers`

- Defines LLM provider connection parameters and API keys.
- Common providers: `openrouter`, `openai`, `anthropic`, `groq`.
- Each provider accepts an optional `transport` field:
  - `"http"` (default) — standard HTTP API with API key auth
  - `"claude-cli"` — route completions through the `claude` CLI binary (Claude Max subscription path)

Example:

```json
{
  "models": {
    "providers": {
      "openrouter": { "api_key": "sk-or-..." },
      "anthropic": { "api_key": "sk-ant-..." },
      "openai": { "api_key": "sk-..." }
    }
  }
}
```

#### Claude Max (Claude CLI Transport)

To use your Claude Max subscription instead of API pay-as-you-go:

1. Install and authenticate the [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code):
   ```bash
   claude login
   ```
2. Set the Anthropic provider transport to `claude-cli`:
   ```json
   {
     "models": {
       "providers": {
         "anthropic": { "transport": "claude-cli" }
       }
     }
   }
   ```
   Or in native Lisp config (`nilclaw.lisp`):
   ```lisp
   (:providers ((:name "anthropic" :transport "claude-cli")))
   ```
3. Select an Anthropic model: `/model anthropic/claude-opus-4-0520`

**Automatic fallback:** When using the default `"http"` transport, if an Anthropic API key
authentication fails, NilClaw will automatically attempt the Claude CLI path as a fallback
(if the `claude` binary is available and logged in). No configuration change is needed for
this fallback behavior.

### `agents.defaults.model.primary`

- Sets default model route, typically `provider/vendor/model`.
- Example: `openrouter/anthropic/claude-sonnet-4`

### `channels`

- Channel config lives under `channels.<name>`.
- Multi-account channels typically use an `accounts` wrapper.

Telegram example:

```json
{
  "channels": {
    "telegram": {
      "accounts": {
        "main": {
          "bot_token": "123456:ABCDEF",
          "allow_from": ["YOUR_TELEGRAM_USER_ID"]
        }
      }
    }
  }
}
```

Rules:

- `allow_from: []` means deny all inbound messages.
- `allow_from: ["*"]` means allow all sources (use only when you accept the risk).

### `memory`

- `backend`: start with `sqlite`.
- `auto_save`: persists conversation memory automatically.
- For hybrid retrieval and embedding settings, see root `config.example.json`.

### `gateway`

Recommended defaults:

- `host = "127.0.0.1"`
- `require_pairing = true`

Avoid direct public exposure. Use tunnel when external access is required.

#### Gateway runtime flags (OpenClaw parity)

These flags are used by OpenClaw-compatible clients (`openclaw.el`, TUI) and are validated at load time:

| Field | Type | Default | Notes |
|---|---|---:|---|
| `url` | string? | `null` | Optional explicit gateway endpoint (`ws://`, `wss://`, `http://`, or `https://`). |
| `token` | string? | `null` | Optional bearer token. Must not contain spaces. |
| `keepalive_interval_ms` | u64 | `30000` | Client keepalive ping interval; must be `> 0`. |
| `reconnect_initial_backoff_ms` | u64 | `500` | Initial reconnect backoff; must be `>= 0`. |
| `reconnect_max_backoff_ms` | u64 | `30000` | Max reconnect backoff; must be `>= reconnect_initial_backoff_ms`. |

Example:

```json
{
  "gateway": {
    "host": "127.0.0.1",
    "port": 3000,
    "url": "ws://127.0.0.1:3000/ws",
    "token": "replace-with-secret",
    "keepalive_interval_ms": 15000,
    "reconnect_initial_backoff_ms": 250,
    "reconnect_max_backoff_ms": 8000
  }
}
```

### `autonomy`

- `level`: start with `supervised`.
- `workspace_only`: keep `true` to limit file access scope.
- `max_actions_per_hour`: keep conservative limits first.

### `security`

- `sandbox.backend = "auto"`: auto-selects an available sandbox backend.
- `audit.enabled = true`: recommended for traceability.

### Advanced: Web Search + Full Shell (high risk)

Use only in controlled environments:

```json
{
  "http_request": {
    "enabled": true,
    "search_base_url": "https://searx.example.com",
    "search_provider": "auto",
    "search_fallback_providers": ["jina", "duckduckgo"]
  },
  "autonomy": {
    "level": "full",
    "allowed_commands": ["*"],
    "allowed_paths": ["*"],
    "require_approval_for_medium_risk": false,
    "block_high_risk_commands": false
  }
}
```

Notes:

- `search_base_url` must be a valid URL, otherwise startup validation fails.
- `allowed_commands: ["*"]` and `allowed_paths: ["*"]` significantly widen execution scope.

## Validate After Config Changes

After each config change:

```bash
nilclaw doctor
nilclaw status
nilclaw channel status
```

If gateway/channel changed, also run:

```bash
nilclaw gateway
```

## Next Steps

- Run `nilclaw doctor` and `nilclaw status` after each edit to confirm the config still loads cleanly
- Use [Usage and Operations](./usage.md) for operational checks, service mode, and troubleshooting flow
- Review [Security](./security.md) before enabling broader autonomy, public bind, or wildcard allowlists

## Related Pages

- [Installation](./installation.md)
- [Usage and Operations](./usage.md)
- [Security](./security.md)
- [Gateway API](./gateway-api.md)
