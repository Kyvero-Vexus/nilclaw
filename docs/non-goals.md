# NilClaw Non-Goals and Intentional Exclusions

## Document Purpose

This document explicitly lists what NilClaw will **NOT** support at cutover to prevent scope confusion and set clear expectations.

---

## Explicit Non-Goals

### 1. Multi-Tenancy
- **Excluded:** User isolation, per-tenant quotas, tenant management
- **Rationale:** Single-user/single-team deployment model
- **Future Consideration:** If multi-tenant needs arise, significant architecture changes required

### 2. Horizontal Scaling
- **Excluded:** Distributed deployment, load balancing, sharding
- **Rationale:** Single-node deployment sufficient for current use case
- **Future Consideration:** Would require session state externalization

### 3. Cloud-Native Deployment
- **Excluded:** Kubernetes operators, auto-scaling, managed services
- **Rationale:** Bare-metal/VM deployment model
- **Future Consideration:** Container packaging exists but orchestration is out of scope

### 4. Web UI Dashboard
- **Excluded:** Admin dashboard, metrics visualization, configuration UI
- **Rationale:** CLI and config-file based operation
- **Future Consideration:** Could be added as separate project

### 5. Plugin/Extension System
- **Excluded:** Third-party plugin loading, extension marketplace
- **Rationale:** All functionality compiled into binary
- **Future Consideration:** ASDF systems provide extension mechanism for Lisp users

### 6. Multiple LLM Provider Simultaneous Use
- **Excluded:** Load balancing across providers, provider failover
- **Rationale:** Single configured provider
- **Future Consideration:** Provider abstraction exists, multi-provider could be added

### 7. Conversation Persistence to Cloud
- **Excluded:** Cloud storage backends, remote database support
- **Rationale:** Local SQLite sufficient
- **Future Consideration:** Could add PostgreSQL/MySQL support

### 8. Voice/Audio Processing
- **Excluded:** Speech-to-text, text-to-speech integration
- **Rationale:** Text-only interface
- **Future Consideration:** External TTS/STT services could be integrated

### 9. Image Generation
- **Excluded:** DALL-E, Stable Diffusion integration
- **Rationale:** Text-focused LLM harness
- **Future Consideration:** Could add as tool/skill

### 10. Embeddings/Vector Storage
- **Excluded:** Semantic search, RAG, vector databases
- **Rationale:** Memory uses simple text search
- **Future Consideration:** Could add vector store integration

---

## Deferred Channel Implementations

These channels exist in OpenClaw but are NOT implemented in NilClaw at cutover:

| Channel | Reason | Migration Impact |
|---------|--------|------------------|
| WhatsApp | Not used in deployment | None |
| Discord | Not used in deployment | None |
| iMessage | Not used in deployment | None |
| Slack | Not used in deployment | None |
| IRC | Not used in deployment | None |
| Google Chat | Not used in deployment | None |

**Risk Acceptance:** No existing integrations to migrate. Future channel additions require new code.

---

## Features Deliberately Simplified

### Memory System
- **Simplified:** Flat file + SQLite search
- **Not Included:** Vector embeddings, semantic clustering, automatic summarization
- **Rationale:** KISS principle for initial release

### Tool System
- **Simplified:** Static tool definitions
- **Not Included:** Dynamic tool discovery, tool marketplace
- **Rationale:** Tools are defined at build time

### Provider System
- **Simplified:** HTTP-based providers
- **Not Included:** WebSocket streaming, custom protocols
- **Rationale:** HTTP is universal and testable

---

## Scope Boundary

### In Scope
- ✅ Gateway protocol compatible with OpenClaw clients
- ✅ Tool execution framework
- ✅ Memory management (basic)
- ✅ Configuration system
- ✅ Security policy
- ✅ Cron scheduling
- ✅ Provider HTTP layer
- ✅ Channel adapters (CLI, Web)
- ✅ ACP (subagent task management)

### Out of Scope
- ❌ All items listed in Non-Goals above
- ❌ All deferred channels
- ❌ Simplified features (advanced modes)

---

## Preventing Scope Assumptions

When evaluating go/no-go decisions:

1. **If a feature is not listed as "In Scope" → Assume it is NOT included**
2. **If a channel is not listed as implemented → Assume it is NOT available**
3. **If a feature is listed as "Simplified" → Assume only basic functionality**

**Do not assume feature parity beyond explicitly documented scope.**

---

## Revision History

| Date | Change | Author |
|------|--------|--------|
| 2026-03-12 | Initial non-goals document | Chrysolambda |

---

*This document defines scope boundaries. Updates require user approval.*
