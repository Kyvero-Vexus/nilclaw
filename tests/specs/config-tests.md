# Config Test Specifications

## Overview
The config module handles parsing, validation, serialization, and roundtripping of the application configuration. It supports JSON-based configuration with sections for providers, channels, agents, memory, gateway, security, scheduling, diagnostics, and more. Configuration supports multi-account channel setups, environment variable overrides, and save/load roundtripping.

---

## JSON Parsing

### Full roundtrip
- **Setup**: JSON with workspace, temperature, providers, agents, memory, gateway, autonomy, runtime, cost
- **Action**: Parse and sync flat fields
- **Expected**: All nested and flat fields match input; provider/model split from "anthropic/claude-opus-4" into provider="anthropic", model="claude-opus-4"; heartbeat interval parsed from "15m" to 15 minutes

### Empty object uses defaults
- **Input**: `{}`
- **Expected**: default_provider="openrouter", default_temperature=0.7, secrets.encrypt=true

### Integer temperature coerced to float
- **Input**: `{"default_temperature": 1}`
- **Expected**: Stored as 1.0

### Unknown foreign fields silently ignored
- **Input**: JSON with unrecognized keys like `tts`, `ui`, `skills`, `bedrock_discovery`
- **Expected**: No errors, known defaults preserved

---

## Model Configuration

### agents.defaults.model.primary parsing
- **Input**: `"anthropic/claude-opus-4"`
- **Expected**: provider="anthropic", model="claude-opus-4"

### Custom provider with versioned path
- **Input**: `"custom:https://api.example.com/openai/v2/minimaxai/minimax-m2.1"`
- **Expected**: provider="custom:https://api.example.com/openai/v2", model="minimaxai/minimax-m2.1"

### Legacy default_provider with model-only primary
- **Input**: `default_provider: "openai"`, `agents.defaults.model.primary: "gpt-5.2"`
- **Expected**: provider="openai", model="gpt-5.2", legacy_default_provider_detected=true

### Top-level default_model (legacy, rejected on validation)
- **Input**: `{"default_model": "meta-llama/llama-3.3-70b-instruct:free"}`
- **Expected**: legacy_default_model_detected=true, default_model=null, validation returns LegacyDefaultModelField error

### Top-level default_model with nested model (still rejected)
- **Input**: Both `default_model` and `agents.defaults.model.primary` present
- **Expected**: Nested model used but legacy flag set; validation still fails with LegacyDefaultModelField

### Workspace override with backslashes
- **Input**: `"workspace": "C:\\Users\\menger\\Desktop\\myspace"`
- **Expected**: workspace_dir_override preserved as-is, model still parsed correctly

---

## Validation

### Passes for valid defaults
- **Setup**: Config with default_model="test/model"
- **Expected**: Validation passes

### Rejects null default_model
- **Expected**: NoDefaultModel error

### Rejects top-level default_provider
- **Expected**: LegacyDefaultProviderField error

### Rejects defaults.model.primary without provider prefix
- **Input**: `"claude-opus-4"` (no slash)
- **Expected**: InvalidDefaultModelPrimary error

### Temperature range: [0.0, 2.0]
- Rejects 5.0 → TemperatureOutOfRange
- Rejects -1.0 → TemperatureOutOfRange
- Accepts 0.0 and 2.0

### Rejects zero port
- **Expected**: InvalidPort error

### Retry limits
- Rejects provider_retries=101 → InvalidRetryCount
- Accepts provider_retries=100
- Rejects provider_backoff_ms=700,000 → InvalidBackoffMs
- Accepts provider_backoff_ms=600,000

### HTTP request validation
- Rejects search_base_url with query string → InvalidHttpSearchBaseUrl
- Accepts valid URL without query
- Rejects unknown search_provider "google" → InvalidHttpSearchProvider
- Rejects unknown search_fallback_provider "auto" → InvalidHttpSearchFallbackProvider
- Rejects proxy with ftp scheme → InvalidHttpProxyUrl

### Diagnostics
- Rejects api_error_max_chars=120 (below minimum) → InvalidApiErrorMaxChars

### Web channel validation
- Rejects path not starting with "/" → InvalidWebPath
- Rejects auth_token with spaces → InvalidWebAuthToken
- Rejects origin without scheme → InvalidWebOrigin
- Accepts HTTPS and chrome-extension:// origins
- Rejects unknown transport "direct" → InvalidWebTransport
- Rejects unknown message_auth_mode "jwt" → InvalidWebMessageAuthMode
- Rejects token message_auth_mode with relay transport → InvalidWebMessageAuthTransport
- Rejects relay transport without relay_url → MissingWebRelayUrl
- Rejects relay_url with https scheme (must be wss) → InvalidWebRelayUrl
- Rejects relay_agent_id with spaces → InvalidWebRelayAgentId
- Accepts well-formed relay config with wss:// URL

### Relay TTL validation
- Rejects relay_pairing_code_ttl_secs=30 (too low) → InvalidWebRelayPairingCodeTtl
- Rejects relay_ui_token_ttl_secs=120 (too low) → InvalidWebRelayUiTokenTtl
- Rejects relay_token_ttl_secs=120 (too low) → InvalidWebRelayTokenTtl

---

## Security-Critical Defaults

### Gateway requires pairing by default
- Default: require_pairing=true

### Gateway blocks public bind by default
- Default: allow_public_bind=false

### Secrets config encrypts by default
- Default: encrypt=true

---

## Flat Field Synchronization

### syncFlatFields propagates nested to flat
- **Action**: Set nested fields (default_temperature, memory.backend, heartbeat.*, gateway.*, autonomy.*)
- **Expected**: Corresponding flat fields (temperature, memory_backend, heartbeat_enabled, etc.) match

### syncFlatFields keeps explicit workspace_dir
- **Setup**: workspace_dir="/from-env", workspace_dir_override="/from-json"
- **Expected**: workspace_dir unchanged, workspace_dir_override preserved

---

## Configuration Sections Parsing

### Reliability section
- Parses provider_retries, provider_backoff_ms, fallback_providers array, api_keys array, model_fallbacks (model + fallbacks array)

### Diagnostics section
- Parses backend, log_tool_calls, log_message_receipts, log_message_payloads, log_llm_io, token_usage_ledger_*, otel_endpoint, otel_service_name

### Scheduler section
- Parses enabled, max_tasks, max_concurrent, agent_timeout_secs

### Agent section
- Parses compact_context, max_tool_iterations, max_history_messages, parallel_tools, tool_dispatcher, token_limit, status_show_emojis, vision_disabled_models array, auto_disable_vision_on_error
- token_limit_explicit is true when token_limit is explicitly set, false when omitted

### Composio section
- Parses enabled, api_key, entity_id

### Secrets section
- Parses encrypt boolean

### Identity section
- Parses format, aieos_path

### Hardware section
- Parses enabled, transport (serial enum), serial_port, baud_rate

### Security section
- Parses sandbox.enabled, sandbox.backend (firejail enum), resources.max_memory_mb, resources.max_cpu_time_seconds, audit.enabled, audit.log_path

### Browser section
- Parses enabled, backend, native_headless, allowed_domains array

### Autonomy section
- Parses allowed_commands array, allowed_paths array, allow_raw_url_chars boolean

### Gateway section
- Parses paired_tokens array

### HTTP request section
- Parses enabled, search_base_url, search_provider, search_fallback_providers, proxy, api_error_max_chars

### Memory section
- Parses search.query.hybrid weights (accepts integer values coerced to float)
- Parses search.store.kind="sqlite_ann", ann_candidate_multiplier, ann_min_candidates
- Clamps negative integers to defaults, clamps overflow to max(u32)

### Model routes
- Parses array of {hint, provider, model, api_key?}
- Skips entries missing required fields (e.g., missing model)

### Agents list
- Parses array of {name, provider, model, system_prompt?, api_key?, temperature?, max_depth}
- Skips invalid entries (missing model, non-object values)
- Accepts "id" as alias for "name"
- Accepts model as object with "primary" field

### Agent bindings
- Parses top-level "bindings" array with agent_id, comment, match (channel, account_id, peer, guild_id, team_id, roles)
- Ignores nested "agents.bindings" alias (returns empty)

### MCP servers
- Parses from object keyed by server name: {command, args, env}
- Handles env as key-value map

### Providers section
- Parses from models.providers as {name, api_key, base_url?}
- Accepts api_key as JSON object (e.g., service account credentials) — serialized to JSON string
- Saves native_tools boolean when false
- Properly escapes provider string fields (quotes, special chars) in save/load roundtrip

### Combined fields parse
- All new fields (model_routes, agents, allowed_commands, paired_tokens, browser.allowed_domains) can appear simultaneously

---

## Provider Key Lookup

### getProviderKey returns null for missing provider
### providers defaults to empty slice (length 0)
### defaultProviderKey returns key for default provider

---

## Audio Media

### Defaults
- enabled=true, provider="groq", model="whisper-large-v3", base_url=null, language=null

### With language only
- Language set, provider/model remain defaults

### Full configuration
- Parses enabled, provider, model, base_url, language from nested tools.media.audio.models array

### Disabled
- enabled=false, provider remains default

---

## Heartbeat Configuration

### Every string with minutes
- "30m" → enabled=true, interval_minutes=30

### Every string with hours
- "2h" → enabled=true, interval_minutes=120

### Disabled flag
- enabled=false with every="30m" → enabled=false, interval_minutes=30

---

## Reasoning Effort

### Valid values parsed
- "high", "medium", "low", "minimal", "xhigh" all accepted

### Invalid value ignored
- "invalid" → reasoning_effort=null

---

## Channel Parsing

### Telegram
- Parses bot_token, allow_from array, reply_in_private, proxy, interactive settings
- Interactive defaults: enabled=false, ttl_secs=900, owner_only=true, remove_on_click=true
- Multi-account sorted alphabetically by account_id
- Custom account_id preserved
- Interactive settings roundtrip through save/load

### Discord
- Parses token, guild_id, allow_from, require_mention
- mention_only (camelCase) is ignored; only require_mention (snake_case) accepted

### Slack
- Parses bot_token, app_token, allow_from; dm_policy defaults to "pairing"

### IRC
- Parses host, nick, port, channels array

### Matrix
- Parses homeserver, access_token, room_id, user_id, group_allow_from, group_policy

### Mattermost
- Parses bot_token, base_url, allow_from, group_allow_from, dm_policy, group_policy, chatmode, onchar_prefixes, require_mention

### Lark
- Parses app_id, app_secret, use_feishu

### DingTalk
- Parses client_id, client_secret, allow_from

### WhatsApp
- Parses access_token, phone_number_id, verify_token, app_secret, allow_from

### Signal
- Multi-account sorted alphabetically; parses http_url, account, ignore_attachments

### QQ
- Multi-account with receive_mode (webhook/websocket enum), group_policy, allowed_groups, allow_from

### OneBot
- Multi-account sorted; parses url, group_trigger_prefix
- account_id in payload body is overridden by the account key name

### MaixCam
- Multi-account sorted; parses port, name, allow_from

### Web
- Parses listen, port, path, auth_token, allowed_origins, message_auth_mode
- message_auth_mode defaults to "pairing"
- Token message_auth_mode parsed separately
- Relay fields: transport, relay_url, relay_agent_id, relay_token, relay_token_ttl_secs, relay_pairing_code_ttl_secs, relay_ui_token_ttl_secs, relay_e2e_required

### iMessage
- Legacy single-object format: enabled + allow_from → single account with account_id="default"
- Multi-account format supported with preferred primary selection

### Nostr
- Parses private_key, owner_pubkey, relays, dm_allowed_pubkeys, display_name, about, nak_path
- Missing required fields (private_key, owner_pubkey) → null
- Asymmetric required fields (only one present) → null (no leak)
- dm_relays default: ["wss://auth.nostr1.com"]
- config_dir defaults to "." in tests
- Save includes nostr channel fields when configured; omits null optional fields
- dm_relays roundtrip through save and load
- display_name with special characters (quotes, newlines) round-trips correctly

---

## Multi-Account Behavior

### Empty accounts object → empty slice
### Missing accounts key → empty slice
### Missing channel config → empty slice for all channels
### Alphabetical sort across channels
### Primary selection: prefers "default", then "main", then first alphabetically
### Primary returns null for empty slice (all channel types)
### Account config overrides base fields
### Multiple channels configured simultaneously all parse correctly

---

## Session Configuration

### dm_scope parsing
- Accepts dash format: "per-peer" → per_peer
- Accepts underscore format: "per_peer" → per_peer
- "per-account-channel-peer" → per_account_channel_peer
- Default: per_channel_peer
- All valid values: main, per-peer, per-channel-peer, per-account-channel-peer (plus underscore variants)

### idle_minutes
- Parses integer value
- camelCase alias "idleMinutes" is ignored (default 60 used)

### identity_links
- Map format: `{"alice": ["telegram:111", "discord:222"]}`
- Array format: `[{"canonical": "bob", "peers": ["slack:999"]}]`

### Empty session block → all defaults
- dm_scope=per_channel_peer, idle_minutes=60, identity_links=[]

---

## Save/Serialization

### Includes channels section by default
### Writes configured telegram channel with all fields
### Roundtrip preserves telegram interactive settings
### Roundtrip preserves diagnostics logging flags
### Roundtrip preserves reliability settings (including model_fallbacks)
### Roundtrip preserves extended config sections (comprehensive: all sections, model_routes, agents, bindings, mcp_servers, runtime, scheduler, agent, memory, gateway, tunnel, composio, secrets, browser, http_request, identity, cost, security, peripherals, hardware, session)
### Escapes MCP server strings safely (quotes, backslashes, newlines roundtrip)
### Save and load roundtrip retains model, workspace override, vision_disabled_models
### Escapes provider string fields (quotes in api_key, base_url, user_agent)

---

## Environment Variable Overrides

### applyEnvOverrides does not crash on default config
- **Action**: Call applyEnvOverrides with no NULLCLAW_* env vars set
- **Expected**: Default values remain intact, no crash
