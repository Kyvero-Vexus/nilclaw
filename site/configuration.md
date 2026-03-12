---
layout: default
title: Configuration
nav_order: 4
---

# Configuration

## Configuration File

Default location: `~/.nilclaw/config.json`

NilClaw uses a JSON-based configuration file for all settings.

## Schema

### Top-Level Structure

```json
{
  "agent": {
    "name": "NilClaw Agent",
    "identity_file": "~/.nilclaw/identity.md"
  },
  "provider": {
    "default": "openai",
    "runtime": {
      "openai": {
        "model": "gpt-4o-mini",
        "max_retries": 2
      }
    }
  },
  "channels": {
    "cli": {
      "enabled": true
    },
    "web": {
      "enabled": true,
      "path": "/",
      "transport": "relay"
    }
  },
  "memory": {
    "backend": "none"
  },
  "security": {
    "policy": "permissive"
  }
}
```

## Agent Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | `"NilClaw Agent"` | Agent display name |
| `identity_file` | string | `null` | Path to identity markdown file |

## Provider Configuration

### Provider Runtime

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `model` | string | `"openai/gpt-4o-mini"` | Model identifier |
| `max_retries` | integer | `2` | Maximum retry attempts (0-10) |
| `base_url` | string | `null` | API base URL override |
| `api_key` | string | `null` | API key (use env var instead) |
| `enabled` | boolean | `true` | Whether provider is active |

### Provider Example

```json
{
  "provider": {
    "default": "openai",
    "runtime": {
      "openai": {
        "model": "gpt-4o",
        "max_retries": 3,
        "base_url": "https://api.openai.com/v1"
      },
      "anthropic": {
        "model": "claude-3-sonnet",
        "max_retries": 2
      }
    }
  }
}
```

## Channel Configuration

### CLI Channel

```json
{
  "channels": {
    "cli": {
      "enabled": true
    }
  }
}
```

### Web Channel

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `true` | Whether channel is active |
| `path` | string | `"/"` | URL path prefix |
| `auth_token` | string | `null` | Bearer token for auth |
| `allowed_origins` | array | `[]` | CORS allowed origins |
| `transport` | string | `"relay"` | Transport mode: `relay` or `local` |
| `relay_url` | string | `null` | WebSocket relay URL |
| `message_auth_mode` | string | `"none"` | Auth mode: `none` or `token` |

```json
{
  "channels": {
    "web": {
      "enabled": true,
      "path": "/",
      "transport": "relay",
      "allowed_origins": ["https://example.com"],
      "message_auth_mode": "token",
      "auth_token": "your-token-here"
    }
  }
}
```

## Memory Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `backend` | string | `"none"` | Backend: `none`, `markdown`, `lru` |
| `path` | string | `null` | Path for file-based backends |

### Backends

- **none** — No persistent storage (stateless)
- **markdown** — Markdown files with metadata
- **lru** — In-memory LRU cache

```json
{
  "memory": {
    "backend": "markdown",
    "path": "~/.nilclaw/memory"
  }
}
```

## Security Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `policy` | string | `"permissive"` | Policy: `permissive` or `strict` |
| `allowlist` | array | `[]` | Allowed tool names |
| `denylist` | array | `[]` | Denied tool names |

```json
{
  "security": {
    "policy": "strict",
    "allowlist": ["read", "write", "exec"],
    "denylist": ["delete"]
  }
}
```

## Auto-Reply Configuration

Auto-reply is configured programmatically:

```lisp
;; Create auto-reply config
(defparameter *config*
  (nilclaw/channel:make-auto-reply-config
    :enabled t
    :max-replies-per-hour 10
    :fallback-response "I'm here to help!"
    :rules (list
      (nilclaw/channel:make-auto-reply-rule
        :name "greeting"
        :trigger-type :keyword
        :trigger-pattern "hello"
        :response "Hello! How can I help you today?"
        :priority 10))))

;; Create runtime
(defparameter *runtime*
  (nilclaw/channel:make-auto-reply-runtime :config *config*))
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `NILCLAW_CONFIG` | Path to config file (default: `~/.nilclaw/config.json`) |
| `OPENAI_API_KEY` | OpenAI API key |
| `ANTHROPIC_API_KEY` | Anthropic API key |

## Validation

Configuration is validated on load:

```lisp
;; Parse and validate config
(multiple-value-bind (config errors)
    (nilclaw/config:parse-config-file path)
  (when errors
    (error "Config validation failed: ~A" errors))
  config)
```

Validation checks:
- Required fields present
- Type correctness
- Value ranges (e.g., max_retries 0-10)
- Unknown fields flagged as warnings
