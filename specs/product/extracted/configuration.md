---
Layer: L1
Lane: engineering-policy
Spec ID: L1-EXT-configuration
Status: draft
Last Updated: 2026-03-10
Traceability:
  L0: [F-CONFIG-MUTABILITY, C-CONFIG-EXPLICITNESS]
---

# Configuration & Config Types Specification

## Overview

The configuration system loads, parses, validates, and manages a JSON
configuration file that controls all aspects of the agent harness. It supports
environment variable overrides, hot mutation with backup/validation, memory
profile presets, and backward-compatible flat field aliases.

## Config File Location

- **Default directory**: `~/.nullclaw/` (overridden by `NULLCLAW_HOME` env var)
- **Config file**: `<config_dir>/config.json`
- **Default workspace**: `<config_dir>/workspace/`
- **Max config file size**: 64 KB (read limit)

## Load Sequence

1. Determine config directory: `NULLCLAW_HOME` env var, or `~/.nullclaw/`.
2. Construct `config_path` = `<config_dir>/config.json`.
3. Construct `default_workspace_dir` = `<config_dir>/workspace/`.
4. Initialize config with all defaults.
5. If config file exists, read and parse JSON. On parse error, log warning
   and continue with defaults (CLI remains usable).
6. If `workspace_dir_override` was set in JSON, use it instead of default.
7. Backfill runtime-derived fields (e.g., Nostr config_dir from config path).
8. Apply environment variable overrides.
9. Sync flat convenience fields from nested sub-configs.

## Environment Variable Overrides

Applied **after** JSON parsing. All override their respective config fields:

| Env Var                        | Config Field              | Type    | Constraint        |
|--------------------------------|---------------------------|---------|--------------------|
| `NULLCLAW_PROVIDER`            | `default_provider`        | string  |                    |
| `NULLCLAW_MODEL`               | `default_model`           | string  |                    |
| `NULLCLAW_TEMPERATURE`         | `default_temperature`     | float   | 0.0–2.0            |
| `NULLCLAW_GATEWAY_PORT`        | `gateway.port`            | u16     |                    |
| `NULLCLAW_GATEWAY_HOST`        | `gateway.host`            | string  |                    |
| `NULLCLAW_WORKSPACE`           | `workspace_dir`           | string  |                    |
| `NULLCLAW_ALLOW_PUBLIC_BIND`   | `gateway.allow_public_bind` | bool  | "1" or "true"      |

## Top-Level Config Schema

### Global Settings

| Field                 | Type       | Default                          | Description                          |
|-----------------------|------------|----------------------------------|--------------------------------------|
| `workspace`           | string?    | `<config_dir>/workspace`         | Workspace directory override         |
| `default_temperature` | float      | `0.7`                            | LLM temperature (0.0–2.0)           |
| `reasoning_effort`    | string?    | null                             | Optional reasoning effort hint       |

### `models.providers`

Map of provider name → provider entry.

| Field          | Type    | Default  | Description                                      |
|----------------|---------|----------|--------------------------------------------------|
| `api_key`      | string? | null     | API key/token. Object/array JSON accepted for structured credentials (e.g., Vertex service-account JSON); stored as compact JSON string |
| `base_url`     | string? | null     | Custom base URL                                  |
| `native_tools` | bool    | `true`   | Use native tool_calls. If false, uses XML tool format via system prompt |
| `user_agent`   | string? | null     | Custom User-Agent header for this provider       |

### `agents.defaults.model.primary`

Model route string in format `provider/model` (e.g., `"openrouter/anthropic/claude-sonnet-4"`).

Special format `custom:<url>/<model>` supported for custom endpoints — splits
on versioned API path segments (`/v1/`, `/v2/`, etc.) to extract model ID.

### `agents` (Named Agents Map)

| Field           | Type    | Default | Description                     |
|-----------------|---------|---------|----------------------------------|
| `name`          | string  | —       | Agent identifier                 |
| `provider`      | string  | —       | Provider name                    |
| `model`         | string  | —       | Model identifier                 |
| `system_prompt` | string? | null    | Optional system prompt override  |
| `api_key`       | string? | null    | Optional dedicated API key       |
| `temperature`   | float?  | null    | Optional temperature override    |
| `max_depth`     | u32     | `3`     | Max delegation depth             |

### `agent` (Agent Behavior)

| Field                           | Type    | Default   | Description                                          |
|---------------------------------|---------|-----------|------------------------------------------------------|
| `compact_context`               | bool    | `false`   | Enable context compaction                            |
| `max_tool_iterations`           | u32     | `1000`    | Max tool calls per turn                              |
| `max_history_messages`          | u32     | `100`     | Max history messages retained                        |
| `parallel_tools`                | bool    | `false`   | Allow parallel tool execution                        |
| `tool_dispatcher`               | string  | `"auto"`  | Tool dispatch strategy                               |
| `token_limit`                   | u64     | `200000`  | Context token budget                                 |
| `session_idle_timeout_secs`     | u64     | `1800`    | Evict idle sessions after N seconds (30 min)         |
| `compaction_keep_recent`        | u32     | `20`      | Messages to keep after compaction                    |
| `compaction_max_summary_chars`  | u32     | `2000`    | Max chars for compaction summary                     |
| `compaction_max_source_chars`   | u32     | `12000`   | Max chars of source fed to compaction                |
| `status_show_emojis`            | bool    | `true`    | Emoji prefixes in /status output                     |
| `message_timeout_secs`          | u64     | `600`     | Max seconds for LLM HTTP response (0 = no limit)    |
| `vision_disabled_models`        | list    | `[]`      | Models that don't support image input                |
| `auto_disable_vision_on_error`  | bool    | `true`    | Auto-add model to vision_disabled on vision error    |

#### Tool Filter Groups

Per-turn MCP tool filtering. Empty = all tools included.

| Field      | Type   | Description                                                     |
|------------|--------|-----------------------------------------------------------------|
| `mode`     | enum   | `"always"` (always include) or `"dynamic"` (keyword-triggered) |
| `tools`    | list   | Glob patterns for tool names (`*` wildcard only)               |
| `keywords` | list   | Keywords for dynamic mode (case-insensitive substring match)   |

Built-in (non-MCP) tools are always included regardless of filter groups.

### `tools`

| Field                   | Type | Default     | Description                    |
|-------------------------|------|-------------|--------------------------------|
| `shell_timeout_secs`    | u64  | `60`        | Shell command timeout          |
| `shell_max_output_bytes`| u32  | `1048576`   | Max shell output (1 MB)        |
| `max_file_size_bytes`   | u32  | `10485760`  | Max file size for read/edit/append (10 MB) |
| `web_fetch_max_chars`   | u32  | `100000`    | Max chars for web fetch        |

### `autonomy`

| Field                              | Type   | Default        | Description                          |
|------------------------------------|--------|----------------|--------------------------------------|
| `level`                            | enum   | `"supervised"` | Autonomy level                       |
| `workspace_only`                   | bool   | `true`         | Restrict file access to workspace    |
| `max_actions_per_hour`             | u32    | `20`           | Hourly action rate limit             |
| `require_approval_for_medium_risk` | bool   | `true`         | Require approval for medium-risk ops |
| `block_high_risk_commands`         | bool   | `true`         | Block high-risk shell commands       |
| `allowed_commands`                 | list   | `[]`           | Allowed shell commands               |
| `allow_raw_url_chars`              | bool   | `false`        | Skip single-`&` shell-operator check |
| `allowed_paths`                    | list   | `[]`           | Additional allowed directories       |

`allowed_paths` entries are resolved via realpath at check time; system-critical
paths are always blocked regardless of this list.

### `diagnostics`

| Field                                | Type  | Default | Description                                   |
|--------------------------------------|-------|---------|-----------------------------------------------|
| `backend`                            | string| `"none"`| Observability backend                         |
| `otel_endpoint`                      | string?| null   | OpenTelemetry endpoint                        |
| `otel_service_name`                  | string?| null   | OpenTelemetry service name                    |
| `api_error_max_chars`                | u32?  | null    | Max chars for user-visible API errors. Validated: [200, 10000] |
| `log_tool_calls`                     | bool  | `false` | Log tool call metadata (not args/output)      |
| `log_message_receipts`               | bool  | `false` | Log message receipts (metadata only)          |
| `log_message_payloads`               | bool  | `false` | Log full message payloads (sensitive!)        |
| `log_llm_io`                         | bool  | `false` | Log LLM request/response payloads (sensitive!)|
| `token_usage_ledger_enabled`         | bool  | `true`  | Persist per-response token counters to JSONL  |
| `token_usage_ledger_window_hours`    | u32   | `24`    | Reset ledger after N hours (0 = disabled)     |
| `token_usage_ledger_max_bytes`       | u64   | `0`     | Max ledger size before reset (0 = disabled)   |
| `token_usage_ledger_max_lines`       | u64   | `0`     | Max JSONL rows before reset (0 = disabled)    |

### `gateway`

| Field                           | Type  | Default       | Description                        |
|---------------------------------|-------|---------------|------------------------------------|
| `port`                          | u16   | `3000`        | Bind port (must be non-zero)       |
| `host`                          | string| `"127.0.0.1"` | Bind address                       |
| `require_pairing`               | bool  | `true`        | Require pairing code exchange      |
| `allow_public_bind`             | bool  | `false`       | Allow binding to non-loopback      |
| `pair_rate_limit_per_minute`    | u32   | `10`          | Pairing endpoint rate limit        |
| `webhook_rate_limit_per_minute` | u32   | `60`          | Webhook endpoint rate limit        |
| `idempotency_ttl_secs`          | u64   | `300`         | Idempotency key TTL (5 min)        |
| `paired_tokens`                 | list  | `[]`          | Pre-paired bearer tokens           |

### `reliability`

| Field                         | Type  | Default | Description                            |
|-------------------------------|-------|---------|----------------------------------------|
| `provider_retries`            | u32   | `2`     | Max provider retries (validated ≤ 100) |
| `provider_backoff_ms`         | u64   | `500`   | Retry backoff (validated ≤ 600000)     |
| `channel_initial_backoff_secs`| u64   | `2`     | Channel reconnect initial backoff      |
| `channel_max_backoff_secs`    | u64   | `60`    | Channel reconnect max backoff          |
| `scheduler_poll_secs`         | u64   | `15`    | Scheduler polling interval             |
| `scheduler_retries`           | u32   | `2`     | Scheduler retry count                  |
| `fallback_providers`          | list  | `[]`    | Ordered fallback provider names        |
| `api_keys`                    | list  | `[]`    | Additional API keys for rotation       |
| `model_fallbacks`             | list  | `[]`    | Per-model fallback chains              |

Model fallback entry format:
```json
{ "model": "<model_id>", "fallbacks": ["<alt1>", "<alt2>"] }
```

### `scheduler`

| Field               | Type | Default | Description                            |
|---------------------|------|---------|----------------------------------------|
| `enabled`           | bool | `true`  | Enable task scheduler                  |
| `max_tasks`         | u32  | `64`    | Max scheduled tasks                    |
| `max_concurrent`    | u32  | `4`     | Max concurrent task executions         |
| `agent_timeout_secs`| u64  | `0`     | Cron agent subprocess timeout (0 = none)|

### `heartbeat`

| Field              | Type | Default | Description                |
|--------------------|------|---------|----------------------------|
| `enabled`          | bool | `false` | Enable heartbeat polling   |
| `interval_minutes` | u32  | `30`    | Heartbeat interval         |

### `cron`

| Field              | Type | Default | Description                     |
|--------------------|------|---------|---------------------------------|
| `enabled`          | bool | `false` | Enable cron scheduling          |
| `interval_minutes` | u32  | `30`    | Cron check interval             |
| `max_run_history`  | u32  | `50`    | Max run history entries per task |

### `runtime`

| Field  | Type   | Default    | Description          |
|--------|--------|------------|----------------------|
| `kind` | string | `"native"` | Runtime adapter type |

#### Docker Runtime Sub-Config

| Field              | Type   | Default       | Description             |
|--------------------|--------|---------------|-------------------------|
| `image`            | string | `"alpine:3.20"`| Docker image           |
| `network`          | string | `"none"`      | Docker network mode     |
| `memory_limit_mb`  | u64?   | `512`         | Container memory limit  |
| `cpu_limit`        | float? | `1.0`         | CPU limit               |
| `read_only_rootfs` | bool   | `true`        | Read-only root FS       |
| `mount_workspace`  | bool   | `true`        | Mount workspace dir     |

### `security`

#### `security.sandbox`

| Field           | Type   | Default  | Description                  |
|-----------------|--------|----------|------------------------------|
| `enabled`       | bool?  | null     | Override auto-detection      |
| `backend`       | enum   | `"auto"` | `auto`, `landlock`, `firejail`, `bubblewrap`, `docker`, `none` |
| `firejail_args` | list   | `[]`     | Extra firejail arguments     |

#### `security.resources`

| Field                  | Type | Default | Description                     |
|------------------------|------|---------|---------------------------------|
| `max_memory_mb`        | u32  | `512`   | Process memory limit            |
| `max_cpu_percent`      | u32  | `80`    | CPU usage limit                 |
| `max_disk_mb`          | u32  | `1024`  | Disk usage limit                |
| `max_cpu_time_seconds` | u64  | `60`    | CPU time limit per command      |
| `max_subprocesses`     | u32  | `10`    | Max concurrent subprocesses     |
| `memory_monitoring`    | bool | `true`  | Enable memory monitoring        |

#### `security.audit`

| Field            | Type   | Default       | Description              |
|------------------|--------|---------------|--------------------------|
| `enabled`        | bool   | `true`        | Enable audit logging     |
| `log_file`       | string?| null          | Custom log file path     |
| `log_path`       | string | `"audit.log"` | Default log path         |
| `retention_days` | u32    | `90`          | Log retention period     |
| `max_size_mb`    | u32    | `100`         | Max log file size        |
| `sign_events`    | bool   | `false`       | Cryptographically sign events |

### `memory`

#### Core Fields

| Field       | Type   | Default            | Description                |
|-------------|--------|--------------------|----------------------------|
| `profile`   | string | `"hybrid_keyword"` | Memory profile preset      |
| `backend`   | string | `"hybrid"`         | Storage backend            |
| `instance_id`| string| `""`               | Instance identifier        |
| `auto_save` | bool   | `true`             | Auto-persist conversations |
| `citations` | string | `"auto"`           | Citation mode              |

#### Memory Profiles

Profiles apply defaults only for fields still at their default values (user
overrides always win). Applied **after** JSON parsing.

| Profile            | Backend    | Search Provider | Hybrid | Rollout |
|--------------------|------------|-----------------|--------|---------|
| `hybrid_keyword`   | (default)  | (default)       | off    | off     |
| `local_keyword`    | `sqlite`   | (default)       | off    | off     |
| `markdown_only`    | (default)  | (default)       | off    | off     |
| `postgres_keyword` | `postgres` | (default)       | off    | off     |
| `local_hybrid`     | `sqlite`   | `openai`        | on     | on      |
| `postgres_hybrid`  | `postgres` | `openai`        | on     | on (pgvector) |
| `minimal_none`     | `none`     | (default)       | off    | off (auto_save=false) |
| `custom`           | —          | —               | —      | — (no defaults) |

#### `memory.search`

| Field               | Type   | Default                 | Description                |
|---------------------|--------|-------------------------|----------------------------|
| `enabled`           | bool   | `true`                  | Enable search              |
| `provider`          | string | `"none"`                | Embedding provider         |
| `model`             | string | `"text-embedding-3-small"` | Embedding model         |
| `dimensions`        | u32    | `1536`                  | Embedding dimensions       |
| `fallback_provider` | string | `"none"`                | Fallback embedding provider|

##### Vector Store (`memory.search.store`)

| Field                      | Type   | Default               | Description                  |
|----------------------------|--------|-----------------------|------------------------------|
| `kind`                     | string | `"auto"`              | `auto`, `pgvector`, `qdrant` |
| `sidecar_path`             | string | `""`                  | Sidecar binary path          |
| `qdrant_url`               | string | `""`                  | Qdrant endpoint              |
| `qdrant_api_key`           | string | `""`                  | Qdrant API key               |
| `qdrant_collection`        | string | `"nullclaw_memories"` | Qdrant collection name       |
| `pgvector_table`           | string | `"memory_embeddings"` | pgvector table name          |
| `ann_candidate_multiplier` | u32    | `12`                  | ANN candidate prefilter multiplier |
| `ann_min_candidates`       | u32    | `64`                  | Minimum ANN candidates       |

##### Chunking (`memory.search.chunking`)

| Field        | Type | Default | Description          |
|--------------|------|---------|----------------------|
| `max_tokens` | u32  | `512`   | Max tokens per chunk |
| `overlap`    | u32  | `64`    | Overlap tokens       |

##### Sync (`memory.search.sync`)

| Field               | Type   | Default         | Description            |
|---------------------|--------|-----------------|------------------------|
| `mode`              | string | `"best_effort"` | Sync mode              |
| `embed_timeout_ms`  | u32    | `15000`         | Embedding timeout      |
| `vector_timeout_ms` | u32    | `5000`          | Vector store timeout   |
| `embed_max_retries` | u32    | `2`             | Embedding retries      |
| `vector_max_retries`| u32    | `2`             | Vector store retries   |

##### Query (`memory.search.query`)

| Field            | Type   | Default | Description            |
|------------------|--------|---------|------------------------|
| `max_results`    | u32    | `6`     | Max results            |
| `min_score`      | float  | `0.0`   | Minimum similarity     |
| `merge_strategy` | string | `"rrf"` | Merge strategy         |
| `rrf_k`          | u32    | `60`    | RRF constant           |

Hybrid sub-config:

| Field                  | Type  | Default | Description              |
|------------------------|-------|---------|--------------------------|
| `enabled`              | bool  | `false` | Enable hybrid retrieval  |
| `vector_weight`        | float | `0.7`   | Vector score weight      |
| `text_weight`          | float | `0.3`   | Text score weight        |
| `candidate_multiplier` | u32   | `4`     | Candidate multiplier     |
| `mmr.enabled`          | bool  | `false` | Enable MMR diversity     |
| `mmr.lambda`           | float | `0.7`   | MMR lambda               |
| `temporal_decay.enabled` | bool | `false`| Enable temporal decay    |
| `temporal_decay.half_life_days` | u32 | `30` | Decay half-life      |

##### Embedding Cache (`memory.search.cache`)

| Field         | Type | Default | Description         |
|---------------|------|---------|---------------------|
| `enabled`     | bool | `true`  | Enable cache        |
| `max_entries` | u32  | `10000` | Max cached entries  |

#### `memory.lifecycle`

| Field                         | Type | Default | Description                |
|-------------------------------|------|---------|----------------------------|
| `hygiene_enabled`             | bool | `true`  | Enable auto hygiene        |
| `archive_after_days`          | u32  | `7`     | Archive threshold          |
| `purge_after_days`            | u32  | `30`    | Purge threshold            |
| `preserve_before_purge`       | bool | `true`  | Snapshot before purge      |
| `conversation_retention_days` | u32  | `30`    | Conversation retention     |
| `snapshot_enabled`            | bool | `false` | Enable snapshots           |
| `snapshot_on_hygiene`         | bool | `false` | Snapshot on hygiene run    |
| `auto_hydrate`                | bool | `true`  | Auto-hydrate on startup    |

#### `memory.reliability`

| Field                         | Type   | Default    | Description                         |
|-------------------------------|--------|------------|-------------------------------------|
| `rollout_mode`                | string | `"off"`    | Rollout mode for vector plane       |
| `circuit_breaker_failures`    | u32    | `5`        | Failures before circuit opens       |
| `circuit_breaker_cooldown_ms` | u32    | `30000`    | Cooldown before circuit retry       |
| `shadow_hybrid_percent`       | u32    | `0`        | Shadow hybrid traffic percentage    |
| `canary_hybrid_percent`       | u32    | `0`        | Canary hybrid traffic percentage    |
| `fallback_policy`             | string | `"degrade"`| `"degrade"` (silent) or `"fail_fast"` |

#### `memory.response_cache`

| Field         | Type | Default | Description              |
|---------------|------|---------|--------------------------|
| `enabled`     | bool | `false` | Enable response caching  |
| `ttl_minutes` | u32  | `60`    | Cache TTL                |
| `max_entries` | u32  | `5000`  | Max cached entries       |

#### `memory.retrieval_stages`

| Field                           | Type | Default | Description                     |
|---------------------------------|------|---------|---------------------------------|
| `query_expansion_enabled`       | bool | `false` | Enable query expansion          |
| `adaptive_retrieval_enabled`    | bool | `false` | Enable adaptive retrieval       |
| `adaptive_keyword_max_tokens`   | u32  | `3`     | Max tokens for keyword search   |
| `adaptive_vector_min_tokens`    | u32  | `6`     | Min tokens for vector search    |
| `llm_reranker_enabled`          | bool | `false` | Enable LLM reranking           |
| `llm_reranker_max_candidates`   | u32  | `10`    | Max reranking candidates        |
| `llm_reranker_timeout_ms`       | u32  | `5000`  | Reranking timeout               |

#### `memory.summarizer`

| Field                      | Type | Default | Description                    |
|----------------------------|------|---------|--------------------------------|
| `enabled`                  | bool | `false` | Enable summarization           |
| `window_size_tokens`       | u32  | `4000`  | Summarization window           |
| `summary_max_tokens`       | u32  | `500`   | Max summary tokens             |
| `auto_extract_semantic`    | bool | `true`  | Auto-extract semantic content  |

#### `memory.postgres`

| Field                  | Type   | Default    | Description           |
|------------------------|--------|------------|-----------------------|
| `url`                  | string | `""`       | PostgreSQL URL        |
| `schema`               | string | `"public"` | Schema name           |
| `table`                | string | `"memories"`| Table name           |
| `connect_timeout_secs` | u32    | `30`       | Connection timeout    |

#### `memory.redis`

| Field        | Type   | Default       | Description       |
|--------------|--------|---------------|-------------------|
| `host`       | string | `"127.0.0.1"` | Redis host        |
| `port`       | u16    | `6379`        | Redis port        |
| `password`   | string | `""`          | Redis password    |
| `db_index`   | u8     | `0`           | Redis DB index    |
| `key_prefix` | string | `"nullclaw"`  | Key prefix        |
| `ttl_seconds`| u32    | `0`           | TTL (0 = no expiry)|

#### `memory.api`

| Field        | Type   | Default | Description         |
|--------------|--------|---------|---------------------|
| `url`        | string | `""`    | API endpoint        |
| `api_key`    | string | `""`    | API key             |
| `timeout_ms` | u32    | `10000` | Request timeout     |
| `namespace`  | string | `""`    | Namespace           |

### `channels`

Multi-account channels use `channels.<type>.accounts.<id>` nesting in JSON.
Account selection priority: `account_id="default"`, then `"main"`, then first.

#### CLI Channel

| Field | Type | Default | Description       |
|-------|------|---------|-------------------|
| `cli` | bool | `true`  | Enable CLI channel|

#### Common Channel Fields

Most channels share:
- `account_id` (string, default `"default"`)
- `allow_from` (list of strings) — sender allowlist
- `group_allow_from` (list of strings) — group allowlist
- `group_policy` (string, default `"allowlist"`)

#### Channel-Specific Configs

See source for complete per-channel schemas. Key channels include:

**Telegram**: `bot_token`, `allow_from`, `group_allow_from`, `group_policy`,
`reply_in_private` (default true), `proxy` (SOCKS5/HTTP), `require_mention`
(default false), `streaming` (default true), interactive sub-config.

**Discord**: `token`, `guild_id`, `allow_bots` (false), `allow_from`,
`require_mention` (false), `intents` (default 37377 = GUILDS|GUILD_MESSAGES|MESSAGE_CONTENT|DIRECT_MESSAGES).

**Slack**: `mode` (`socket`|`http`), `bot_token`, `app_token`, `signing_secret`,
`webhook_path` (`/slack/events`), `dm_policy` (`pairing`), `group_policy`
(`mention_only`), `reply_to_mode` (`off`|`all`).

**IRC**: `host`, `port` (6697), `nick`, `channels`, `tls` (true),
`server_password`, `nickserv_password`, `sasl_password`.

**Matrix**: `homeserver`, `access_token`, `room_id`, `user_id`.

**Signal**: `http_url`, `account`, `ignore_attachments` (false).

**Email**: `imap_host/port/folder`, `smtp_host/port/tls`, `username/password`,
`from_address`, `poll_interval_secs` (60).

**Web (WebSocket)**: `transport` (`local`|`relay`), `port` (32123),
`listen` (`127.0.0.1`), `path` (`/ws`), `max_connections` (10),
`auth_token`, `message_auth_mode` (`pairing`|`token`),
`allowed_origins`, relay settings.

**Nostr**: `private_key` (enc2: encrypted), `owner_pubkey` (64-char hex),
`bot_pubkey`, `relays`, `dm_relays`, `dm_allowed_pubkeys`, `display_name`,
`nak_path`.

### `http_request`

| Field                       | Type   | Default  | Description                           |
|-----------------------------|--------|----------|---------------------------------------|
| `enabled`                   | bool   | `false`  | Enable HTTP requests                  |
| `max_response_size`         | u32    | `1000000`| Max response bytes (1 MB)             |
| `timeout_secs`              | u64    | `30`     | Request timeout                       |
| `allowed_domains`           | list   | `[]`     | Domain allowlist                      |
| `proxy`                     | string?| null     | Outbound proxy (http/https/socks5)    |
| `search_base_url`           | string?| null     | SearXNG instance URL                  |
| `search_provider`           | string | `"auto"` | Search provider                       |
| `search_fallback_providers` | list   | `[]`     | Fallback provider chain               |

Valid search providers: `auto`, `searxng`, `duckduckgo`/`ddg`, `brave`,
`firecrawl`, `tavily`, `perplexity`, `exa`, `jina`.

Fallback providers cannot be `auto`.

`search_base_url` must be `https://host[/search]` (no query/fragment).

### `browser`

| Field                | Type   | Default               | Description                |
|----------------------|--------|-----------------------|----------------------------|
| `enabled`            | bool   | `false`               | Enable browser tool        |
| `session_name`       | string?| null                  | Browser session name       |
| `backend`            | string | `"agent_browser"`     | Browser backend            |
| `native_headless`    | bool   | `true`                | Headless mode              |
| `native_webdriver_url`| string| `"http://127.0.0.1:9515"` | WebDriver URL         |
| `allowed_domains`    | list   | `[]`                  | Domain allowlist           |

Computer use sub-config: `endpoint`, `api_key`, `timeout_ms` (15000),
`allow_remote_endpoint` (false), `max_coordinate_x/y`.

### `tunnel`

| Field      | Type   | Default  | Description      |
|------------|--------|----------|------------------|
| `provider` | string | `"none"` | Tunnel provider  |

### `cost`

| Field              | Type  | Default | Description               |
|--------------------|-------|---------|---------------------------|
| `enabled`          | bool  | `false` | Enable cost tracking      |
| `daily_limit_usd`  | float | `10.0`  | Daily spend limit         |
| `monthly_limit_usd` | float| `100.0` | Monthly spend limit       |
| `warn_at_percent`  | u8    | `80`    | Warning threshold %       |
| `allow_override`   | bool  | `false` | Allow limit override      |

### `identity`

| Field          | Type   | Default      | Description            |
|----------------|--------|--------------|------------------------|
| `format`       | string | `"nullclaw"` | Identity format        |
| `aieos_path`   | string?| null         | AIEOS file path        |
| `aieos_inline` | string?| null         | Inline AIEOS content   |

### `secrets`

| Field     | Type | Default | Description              |
|-----------|------|---------|--------------------------|
| `encrypt` | bool | `true`  | Encrypt secrets at rest  |

### `composio`

| Field       | Type   | Default     | Description        |
|-------------|--------|-------------|--------------------|
| `enabled`   | bool   | `false`     | Enable Composio    |
| `api_key`   | string?| null        | API key            |
| `entity_id` | string | `"default"` | Entity identifier  |

### `session`

| Field                  | Type   | Default              | Description                       |
|------------------------|--------|----------------------|-----------------------------------|
| `dm_scope`             | enum   | `"per_channel_peer"` | DM session scoping                |
| `idle_minutes`         | u32    | `60`                 | Session idle timeout              |
| `identity_links`       | list   | `[]`                 | Cross-channel identity links      |
| `typing_interval_secs` | u32   | `5`                  | Typing indicator interval         |
| `max_concurrent_tasks` | u32   | `4`                  | Max parallel message processing   |

DM scope values:
- `main` — single shared session for all DMs
- `per_peer` — one session per peer across all channels
- `per_channel_peer` — one session per (channel, peer) pair (default)
- `per_account_channel_peer` — one session per (account, channel, peer) triple

Identity link format: `{ "canonical": "<id>", "peers": ["<id1>", "<id2>"] }`

### `mcp_servers`

Map of server name → config:

| Field     | Type | Description                    |
|-----------|------|--------------------------------|
| `command` | string | Command to launch MCP server |
| `args`    | list | Command arguments              |
| `env`     | list | Environment entries (`key`, `value` pairs) |

### `peripherals`

| Field          | Type | Default | Description            |
|----------------|------|---------|------------------------|
| `enabled`      | bool | `false` | Enable peripherals     |
| `datasheet_dir`| string?| null  | Datasheet directory    |
| `boards`       | list | `[]`   | Board configurations   |

Board config: `board`, `transport` ("serial"), `path`, `baud` (115200).

### `hardware`

| Field                  | Type   | Default  | Description              |
|------------------------|--------|----------|--------------------------|
| `enabled`              | bool   | `false`  | Enable hardware support  |
| `transport`            | enum   | `"none"` | `none`, `native`, `serial`, `probe` |
| `serial_port`          | string?| null     | Serial port path         |
| `baud_rate`            | u32    | `115200` | Baud rate                |
| `workspace_datasheets` | bool   | `false`  | Use workspace datasheets |

### `audio_media` (tools.media.audio)

| Field      | Type   | Default              | Description         |
|------------|--------|----------------------|---------------------|
| `enabled`  | bool   | `true`               | Enable audio        |
| `provider` | string | `"groq"`             | Audio provider      |
| `model`    | string | `"whisper-large-v3"` | Audio model         |
| `base_url` | string?| null                 | Custom endpoint     |
| `language` | string?| null                 | Language hint       |

## Validation Rules

Validation runs after loading and after mutation. Errors are typed and each
produces a specific user-facing error message.

| Condition                                        | Error                              |
|--------------------------------------------------|------------------------------------|
| Legacy `default_provider` field used             | `LegacyDefaultProviderField`       |
| Legacy `default_model` field used                | `LegacyDefaultModelField`          |
| Empty `default_provider`                         | `InvalidDefaultModelPrimary`       |
| No `default_model`                               | `NoDefaultModel`                   |
| Temperature outside [0.0, 2.0]                   | `TemperatureOutOfRange`            |
| Gateway port = 0                                 | `InvalidPort`                      |
| Provider retries > 100                           | `InvalidRetryCount`                |
| Provider backoff > 600,000 ms                    | `InvalidBackoffMs`                 |
| Invalid proxy URL                                | `InvalidHttpProxyUrl`              |
| `api_error_max_chars` outside [200, 10000]       | `InvalidApiErrorMaxChars`          |
| Invalid search base URL                          | `InvalidHttpSearchBaseUrl`         |
| Invalid search provider name                     | `InvalidHttpSearchProvider`        |
| Invalid fallback provider (or "auto")            | `InvalidHttpSearchFallbackProvider`|
| Web channel: invalid transport                   | `InvalidWebTransport`              |
| Web channel: malformed path                      | `InvalidWebPath`                   |
| Web channel: invalid auth token                  | `InvalidWebAuthToken`              |
| Web channel: invalid message auth mode           | `InvalidWebMessageAuthMode`        |
| Web channel: token auth with relay transport     | `InvalidWebMessageAuthTransport`   |
| Web channel: invalid origin                      | `InvalidWebOrigin`                 |
| Web relay: missing relay_url                     | `MissingWebRelayUrl`               |
| Web relay: invalid relay_url (must be wss://)    | `InvalidWebRelayUrl`               |
| Web relay: invalid agent_id                      | `InvalidWebRelayAgentId`           |
| Web relay: pairing code TTL outside [60, 300]    | `InvalidWebRelayPairingCodeTtl`    |
| Web relay: UI token TTL outside [300, 2592000]   | `InvalidWebRelayUiTokenTtl`        |
| Web relay: token TTL outside [3600, 31536000]    | `InvalidWebRelayTokenTtl`          |

## Config Mutation

The mutation system allows runtime config changes with safety guarantees:

### Allowed Mutation Paths

**Exact paths**: `default_temperature`, `reasoning_effort`, `memory.backend`,
`memory.profile`, `memory.auto_save`, `gateway.host`, `gateway.port`,
`tunnel.provider`, `agents.defaults.model.primary`.

**Prefix paths** (any sub-path allowed): `agent.`, `autonomy.`, `browser.`,
`channels.`, `diagnostics.`, `http_request.`, `memory.`, `models.providers.`,
`runtime.`, `scheduler.`, `security.`, `session.`, `tools.`.

### Paths Requiring Restart

- `channels.*` — any channel config change
- `runtime.*` — any runtime config change
- `memory.backend` and `memory.profile`

### Mutation Process

1. Validate path is in allowlist.
2. Read current config (or empty `{}` if no file exists).
3. Parse current JSON tree.
4. Capture old value at path.
5. Apply mutation (`set` or `unset`).
6. Capture new value.
7. Render full JSON with 2-space indentation.
8. Validate rendered JSON by parsing into a full Config and running validate().
9. If `apply=true` and value changed:
   a. Create `.bak` backup of original file (if it existed).
   b. Write atomically (write to `.tmp`, rename; fallback to direct write).
10. Return result with `changed`, `applied`, `requires_restart`, old/new values.

## Integration Points

- **Agent core**: reads `agent.*` settings for context management, tool limits.
- **Provider system**: reads `models.providers.*` and model routes.
- **Channel system**: reads `channels.*` for startup and allowlists.
- **Security system**: reads `autonomy.*`, `security.*` for sandboxing.
- **Memory system**: reads `memory.*` with profile defaults.
- **Gateway**: reads `gateway.*` for HTTP listener.
- **Scheduler**: reads `scheduler.*` and `cron.*` for task management.

## Constants

| Constant                     | Value     | Description                    |
|------------------------------|-----------|--------------------------------|
| `DEFAULT_AGENT_TOKEN_LIMIT`  | `200000`  | Default context token budget   |
| `DEFAULT_MODEL_MAX_TOKENS`   | `8192`    | Default generation cap         |
