---
Layer: L1
Lane: reliability
Spec ID: L1-EXT-memory-system
Status: draft
Last Updated: 2026-03-10
Traceability:
  L0: [F-MEM-PERSISTENCE, F-MEM-RECALL, C-REL-DEGRADATION]
---

# Memory System Specification

## Overview

The memory system provides persistent knowledge storage with a layered
architecture: primary store backends, a retrieval engine (hybrid keyword +
vector search), a vector plane (embeddings, vector store, circuit breaker),
and lifecycle management (cache, hygiene, snapshots, summarization).

## Architecture Layers

| Layer          | Modules                                    | Purpose                         |
|----------------|--------------------------------------------|---------------------------------|
| A: Primary Store| sqlite, markdown, none, lru, postgres, redis, api, lancedb | Key-value storage with categories |
| B: Retrieval   | engine, rrf, temporal_decay, mmr, adaptive, query_expansion, llm_reranker | Search and ranking |
| C: Vector Plane| embeddings, vector_store, circuit_breaker, outbox, chunker | Embedding and similarity search |
| D: Lifecycle   | cache, semantic_cache, hygiene, snapshot, rollout, migrate, diagnostics, summarizer | Runtime management |

## Memory Interface

### VTable Methods

| Method      | Signature                                                     | Description                    |
|-------------|---------------------------------------------------------------|--------------------------------|
| `name`      | () → string                                                   | Backend name                   |
| `store`     | (key, content, category, session_id?) → void                  | Store entry                    |
| `recall`    | (allocator, query, limit, session_id?) → MemoryEntry[]        | Keyword search                 |
| `get`       | (allocator, key) → MemoryEntry?                               | Get by key                     |
| `list`      | (allocator, category?, session_id?) → MemoryEntry[]           | List entries                   |
| `forget`    | (key) → bool                                                  | Delete entry                   |
| `count`     | () → usize                                                    | Total entry count              |
| `healthCheck`| () → bool                                                    | Backend health                 |
| `deinit`    | () → void                                                     | Cleanup                        |

### MemoryEntry

| Field        | Type           | Description                    |
|--------------|----------------|--------------------------------|
| `id`         | string         | Unique identifier              |
| `key`        | string         | Storage key                    |
| `content`    | string         | Entry content                  |
| `category`   | MemoryCategory | Category tag                   |
| `timestamp`  | string         | Creation timestamp             |
| `session_id` | string?        | Owning session                 |
| `score`      | float?         | Relevance score (from search)  |

### MemoryCategory

| Variant        | Description                      |
|----------------|----------------------------------|
| `core`         | Core knowledge                   |
| `daily`        | Daily log entries                |
| `conversation` | Auto-saved conversation messages |
| `custom(name)` | User-defined category            |

### Internal Keys

Keys starting with these prefixes are internal and hidden from user-facing
memory tools:

- `autosave_user_` — auto-saved user messages
- `autosave_assistant_` — auto-saved assistant responses
- `last_hygiene_at` — hygiene timestamp
- `__bootstrap.prompt.` — workspace identity files

## Storage Backends

### SQLite (default "hybrid"/"sqlite")
- FTS5 full-text search with BM25 ranking
- Embeddings stored as BLOBs
- Session message persistence
- Build-time optional (`enable_sqlite`)

### Markdown ("markdown")
- File-based storage in workspace directory
- One markdown file per memory entry
- Document chunking for large files

### None ("none")
- No-op backend, all operations succeed silently
- `store` is a no-op, `recall`/`get` return empty, `count` returns 0

### In-Memory LRU ("memory")
- Bounded in-memory storage
- LRU eviction when capacity exceeded

### PostgreSQL ("postgres")
- PostgreSQL-backed storage
- Optional pgvector extension for vector search
- Build-time optional (`enable_postgres`)

### Redis ("redis")
- Redis key-value storage
- Configurable key prefix and TTL

### API ("api")
- Remote API-backed memory
- REST endpoint for all operations

### LanceDB ("lancedb")
- LanceDB vector database
- Build-time optional (`enable_memory_lancedb`)

### Lucid ("lucid")
- Experimental backend
- Build-time optional (`enable_memory_lucid`)

## Session Store

Separate from the Memory interface, handles conversation persistence:

| Method         | Signature                                      | Description           |
|----------------|------------------------------------------------|-----------------------|
| `saveMessage`  | (session_id, role, content) → void             | Persist a message     |
| `loadMessages` | (allocator, session_id) → MessageEntry[]       | Restore messages      |
| `clearMessages`| (session_id) → void                            | Clear session history |
| `clearAutoSaved`| (session_id?) → void                          | Clear auto-saved entries |

## Retrieval Engine

### Pipeline

1. **Query Analysis** (adaptive) — determine retrieval strategy based on
   token count: keyword-only for short queries (≤3 tokens), vector-only
   for long queries (≥6 tokens), hybrid for medium
2. **Query Expansion** (optional) — expand query with synonyms/related terms
3. **Dual-Path Search**:
   - Keyword search via primary backend `recall()`
   - Vector search via embedding + vector store similarity
4. **Merge** — Reciprocal Rank Fusion (RRF) or weighted hybrid merge
5. **Temporal Decay** (optional) — downweight older results
6. **MMR** (optional) — Maximal Marginal Relevance for diversity
7. **LLM Reranking** (optional) — re-score candidates via LLM

### RetrievalCandidate

| Field     | Type   | Description                    |
|-----------|--------|--------------------------------|
| `key`     | string | Entry key                      |
| `content` | string | Entry content                  |
| `score`   | f64    | Combined relevance score       |
| `source`  | enum   | `keyword`, `vector`, `merged`  |

### Reciprocal Rank Fusion (RRF)

```
score = Σ 1 / (k + rank_i)
```
Where `k` = 60 (default `rrf_k` constant).

### Hybrid Merge

Weighted combination:
```
final_score = vector_weight * vector_score + text_weight * text_score
```
Defaults: `vector_weight = 0.7`, `text_weight = 0.3`

### Temporal Decay

Exponential decay based on entry age:
```
decayed_score = score * 0.5^(age_days / half_life_days)
```
Default `half_life_days = 30`

### MMR (Maximal Marginal Relevance)

Iteratively selects results that balance relevance and diversity:
```
mmr_score = lambda * relevance - (1 - lambda) * max_similarity_to_selected
```
Default `lambda = 0.7`

## Vector Plane

### Embedding Providers

| Provider  | Module              | Description                 |
|-----------|---------------------|-----------------------------|
| OpenAI    | embeddings.zig      | text-embedding-3-small      |
| Gemini    | embeddings_gemini   | Gemini embedding models     |
| Voyage    | embeddings_voyage   | Voyage AI embeddings        |
| Ollama    | embeddings_ollama   | Local Ollama embeddings     |
| Noop      | embeddings.zig      | Returns zero vectors        |

Provider router: tries primary, falls back to fallback provider.

### Vector Stores

| Store          | Module            | Description                  |
|----------------|-------------------|------------------------------|
| SQLite Shared  | store.zig         | SQLite BLOB in same DB       |
| SQLite Sidecar | store.zig         | Separate SQLite DB           |
| Qdrant         | store_qdrant.zig  | Remote Qdrant server         |
| pgvector       | store_pgvector.zig| PostgreSQL pgvector extension|

### Circuit Breaker

Protects against cascading failures in the vector plane:
- Opens after `circuit_breaker_failures` consecutive failures (default 5)
- Stays open for `circuit_breaker_cooldown_ms` (default 30,000ms)
- Half-open state allows single probe request

### Durable Outbox

Async vector sync with at-least-once delivery:
- Failed embeddings/upserts queued to SQLite outbox
- Drained periodically or after turn completion
- Configurable retry with backoff

### Chunking

Large documents split into chunks for embedding:
- `max_tokens` per chunk (default 512)
- `overlap` tokens between chunks (default 64)

## Rollout System

Controls gradual migration from keyword-only to hybrid retrieval:

| Mode          | Behavior                                          |
|---------------|---------------------------------------------------|
| `off`         | Keyword-only always                               |
| `on`          | Hybrid always (when engine available)             |
| `shadow`      | Run both, serve keyword, log hybrid for comparison|
| `canary`      | Hybrid for N% of requests (hash-based)            |

## Lifecycle Management

### Response Cache

LLM response deduplication:
- Key: hash of (model, system_prompt, user_message)
- TTL-based expiration (`ttl_minutes`, default 60)
- Bounded by `max_entries` (default 5000)

### Semantic Cache

Extends response cache with cosine similarity matching:
- Finds similar (not identical) queries
- Uses embedding distance threshold

### Hygiene

Automatic maintenance:
- Archive entries older than `archive_after_days` (default 7)
- Purge entries older than `purge_after_days` (default 30)
- Optional snapshot before purge
- Conversation retention: `conversation_retention_days` (default 30)

### Snapshots

Full export/import for migration:
- `exportSnapshot()` — serialize all entries to JSON
- `hydrateFromSnapshot()` — restore from snapshot
- Auto-hydrate on startup if `auto_hydrate = true` and DB is empty

### Summarizer

Automatic summarization of memory windows:
- Triggered when window exceeds `window_size_tokens` (default 4000)
- Summary capped at `summary_max_tokens` (default 500)
- Optional semantic extraction (`auto_extract_semantic`, default true)

### Diagnostics

`diagnoseRuntime()` produces a `DiagnosticReport` covering:
- Primary backend status
- Vector plane status (embedding provider, vector store, circuit breaker)
- Cache stats
- Retrieval engine configuration
- Rollout policy

## Memory Profiles

Profiles apply defaults for unconfigured fields:

| Profile            | Backend    | Embedding Provider | Hybrid | Auto-save |
|--------------------|------------|-------------------|--------|-----------|
| `hybrid_keyword`   | (default)  | none              | off    | true      |
| `local_keyword`    | sqlite     | none              | off    | true      |
| `markdown_only`    | (default)  | none              | off    | true      |
| `postgres_keyword` | postgres   | none              | off    | true      |
| `local_hybrid`     | sqlite     | openai            | on     | true      |
| `postgres_hybrid`  | postgres   | openai            | on     | true      |
| `minimal_none`     | none       | none              | off    | false     |
| `custom`           | —          | —                 | —      | —         |

## MemoryRuntime

Bundles all memory components into a single runtime object:

| Field             | Type             | Description                      |
|-------------------|------------------|----------------------------------|
| `memory`          | Memory           | Primary store                    |
| `session_store`   | SessionStore?    | Session persistence              |
| `response_cache`  | ResponseCache?   | LLM response cache               |
| `capabilities`    | BackendCapabilities| Backend feature flags           |
| `resolved`        | ResolvedConfig   | Actual resolved configuration    |

### ResolvedConfig

Captures what was actually resolved during initialization:
- `primary_backend`, `retrieval_mode`, `vector_mode`
- `embedding_provider`, `rollout_mode`, `vector_sync_mode`
- Feature flags: hygiene, snapshot, cache, semantic_cache, summarizer

### High-Level Search

`MemoryRuntime.search()` uses rollout policy to decide:
- `keyword_only` → bypass engine, use `recall()` directly
- `hybrid` → use retrieval engine if available, else fallback
- `shadow_hybrid` → run both, serve keyword, log hybrid

### Vector Sync

`syncVectorAfterStore()` — best-effort async embedding + upsert after
each `store()` call. Errors are logged, never propagated.

## Bootstrap Integration

Memory keys with `__bootstrap.prompt.*` prefix store workspace identity
files (AGENTS.md, SOUL.md, etc.) for database-backed memory backends.

## Integration Points

- **Agent core**: auto-save user/assistant messages, memory enrichment
- **Memory tools**: `memory_store`, `memory_recall`, `memory_list`, `memory_forget`
- **Session management**: persistent message history via SessionStore
- **Bootstrap provider**: workspace files in database backends
- **Response cache**: deduplication in agent turn loop
- **Diagnostics**: `/doctor` command runtime health check
