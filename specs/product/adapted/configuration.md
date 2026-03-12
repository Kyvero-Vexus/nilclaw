---
Layer: L1
Lane: engineering-policy
Spec ID: L1-ADP-configuration
Status: draft
Last Updated: 2026-03-10
Traceability:
  L0: [F-CONFIG-MUTABILITY, C-CONFIG-EXPLICITNESS]
---

# Configuration Specification (Adapted from NilClaw docs)

> Frozen reference — do not modify. Source: NilClaw docs/en/configuration.md

## Overview

The system uses a JSON configuration file with `snake_case` keys, compatible
with the OpenClaw config structure. An interactive onboarding wizard generates
the initial config.

## Config File Path

- Linux/macOS: `~/.nilclaw/config.json`
- Windows: `%USERPROFILE%\.nilclaw\config.json`

## Core Sections

### `models.providers`

Defines LLM provider connection parameters and API keys.

```json
{
  "models": {
    "providers": {
      "<provider_name>": {
        "api_key": "<key>"
      }
    }
  }
}
```

Common providers: `openrouter`, `openai`, `anthropic`, `groq`.

### `agents.defaults.model.primary`

Sets default model route using the format `provider/vendor/model`.
Example: `"openrouter/anthropic/claude-sonnet-4"`

### `channels`

Channel config lives under `channels.<name>`. Multi-account channels use an
`accounts` wrapper.

Key rules for `allow_from`:
- `[]` — deny all inbound messages
- `["*"]` — allow all sources (high risk)
- Otherwise — exact-match allowlist

### `memory`

- `backend`: storage backend (e.g., `"sqlite"`)
- `auto_save`: boolean, persists conversation memory automatically

### `gateway`

- `host`: bind address (default `"127.0.0.1"`)
- `port`: bind port (default `3000`)
- `require_pairing`: boolean (default `true`)

Public exposure should use tunnels rather than direct binding.

### `autonomy`

- `level`: autonomy level (e.g., `"supervised"`, `"full"`)
- `workspace_only`: boolean (default `true`), limits file access scope
- `max_actions_per_hour`: integer rate limit

### `security`

- `sandbox.backend`: sandbox selection (`"auto"` for auto-detect)
- `audit.enabled`: boolean, enables audit trail
- `audit.retention_days`: integer, audit log retention period

### Advanced: HTTP and Shell Settings (high risk)

- `http_request.enabled`: boolean
- `http_request.search_base_url`: URL (must be valid, validated at startup)
- `http_request.search_provider`: string (e.g., `"auto"`)
- `http_request.search_fallback_providers`: list of provider names
- `autonomy.allowed_commands`: list of allowed commands (`["*"]` = all)
- `autonomy.allowed_paths`: list of allowed paths (`["*"]` = all)
- `autonomy.require_approval_for_medium_risk`: boolean
- `autonomy.block_high_risk_commands`: boolean

## Validation

After config changes, the system provides diagnostic commands:
- `doctor` — validates config and dependencies
- `status` — shows overall system status
- `channel status` — shows channel health
