# NullClaw Baseline Feature Mapping (L1)

- **Layer:** L1
- **Lane:** behavior-e2e
- **Spec ID:** L1-BHV-nullclaw-baseline-feature-mapping
- **Status:** draft
- **Last Updated:** 2026-03-10

## Purpose
Map L0 feature truths to concrete L1 behavioral spec surfaces currently available in NilClaw spec corpus.

## Feature Mapping

### Interface & Interaction
- **F-UI-TERMINAL** -> `specs/product/extracted/agent-core.md`, `specs/product/extracted/channel-system.md`
- **F-UI-GATEWAY** -> `specs/product/extracted/gateway-control-plane.md`
- **F-UI-STREAMING** -> `specs/product/extracted/streaming-voice.md`

### Agent Runtime
- **F-AGENT-SESSIONS** -> `specs/product/extracted/agent-core.md`, `specs/product/extracted/identity-workspace.md`
- **F-AGENT-SUBAGENTS** -> `specs/product/extracted/subagent-system.md`
- **F-AGENT-SCHEDULING** -> `specs/product/extracted/cron-heartbeat.md`

### Capabilities
- **F-CAP-TOOLS** -> `specs/product/extracted/tool-system.md`
- **F-CAP-MCP** -> `specs/product/extracted/mcp-client.md`
- **F-CAP-SKILLS** -> `specs/product/extracted/skills-system.md`

### Memory & State
- **F-MEM-PERSISTENCE** -> `specs/product/extracted/memory-system.md`
- **F-MEM-RECALL** -> `specs/product/extracted/memory-system.md`
- **F-CONFIG-MUTABILITY** -> `specs/product/extracted/configuration.md`

### Providers & Routing
- **F-LLM-MULTIPROVIDER** -> `specs/product/extracted/provider-abstraction.md`
- **F-LLM-COMPAT** -> `specs/product/extracted/provider-abstraction.md`
- **F-ROUTING-AGENT** -> `specs/product/extracted/agent-core.md`, `specs/product/extracted/channel-system.md`

### Security
- **F-SEC-POLICY** -> `specs/product/extracted/security-sandboxing.md`
- **F-SEC-SANDBOX** -> `specs/product/extracted/security-sandboxing.md`
- **F-SEC-AUTH** -> `specs/product/extracted/gateway-control-plane.md`, `specs/product/extracted/security-sandboxing.md`

### Channels
- **F-CH-MULTICHANNEL** -> `specs/product/extracted/channel-system.md`
- **F-CH-WEBHOOK** -> `specs/product/extracted/gateway-control-plane.md`

### Reliability & Observability
- **F-REL-RETRY-TIMEOUT** -> `specs/product/extracted/provider-abstraction.md`, `specs/product/extracted/gateway-control-plane.md`
- **F-OBS-LOGGING** -> `specs/product/extracted/agent-core.md`, `specs/product/extracted/gateway-control-plane.md`

## Gaps / Follow-up Needed
- L1 lane docs are still mostly represented by extracted module specs; they should be normalized into lane-native docs over time.
- Several L0 features currently map to broad module docs; finer-grained L1 sections should be split by feature.

## Traceability
- **Traces up to L0:** `L0-feature-catalog`
- **Traces down to L2:** `tests/specs/*` and planned `tests/e2e-specs/*`


## Constraint Mapping

- **C-SEC-POLICY-ENFORCEMENT** -> `specs/product/extracted/security-sandboxing.md`
- **C-SEC-SANDBOX-BOUNDARY** -> `specs/product/extracted/security-sandboxing.md`
- **C-SEC-AUTH-BOUNDARY** -> `specs/product/extracted/gateway-control-plane.md`, `specs/product/extracted/security-sandboxing.md`
- **C-SEC-SECRET-HANDLING** -> `specs/product/extracted/security-sandboxing.md`
- **C-SAFE-PRIORITY** -> `specs/product/extracted/agent-core.md`
- **C-REL-TIMEOUT-RETRY** -> `specs/product/extracted/provider-abstraction.md`, `specs/product/extracted/gateway-control-plane.md`
- **C-CONFIG-EXPLICITNESS** -> `specs/product/extracted/configuration.md`
