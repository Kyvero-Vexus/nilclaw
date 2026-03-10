# NilClaw Feature Catalog (Baseline from NullClaw)

- **Layer:** L0
- **Spec ID:** L0-feature-catalog
- **Status:** active
- **Owner:** Human
- **Last Updated:** 2026-03-10

## Description
This catalog defines top-level product features NilClaw must provide (baseline from current NullClaw behavior). These are high-authority feature truths, not implementation details or constraints.

## Feature Truths

### Interface & Interaction Features
- **F-UI-TERMINAL:** NilClaw MUST provide an interactive terminal interface (TUI/REPL) for direct use.
- **F-UI-GATEWAY:** NilClaw MUST provide a gateway interface for non-terminal integrations.
- **F-UI-STREAMING:** NilClaw MUST support streamed assistant responses where configured.

### Agent Runtime Features
- **F-AGENT-SESSIONS:** NilClaw MUST support durable conversational sessions.
- **F-AGENT-SUBAGENTS:** NilClaw MUST support spawning and managing sub-agents.
- **F-AGENT-SCHEDULING:** NilClaw MUST support scheduled autonomous execution (cron/heartbeat).

### Capability Features
- **F-CAP-TOOLS:** NilClaw MUST expose explicit tool-calling capabilities.
- **F-CAP-MCP:** NilClaw MUST support MCP servers as capability providers.
- **F-CAP-SKILLS:** NilClaw MUST support skill/instruction loading for agent behavior extension.

### Memory & State Features
- **F-MEM-PERSISTENCE:** NilClaw MUST persist memory/state across runs.
- **F-MEM-RECALL:** NilClaw MUST provide structured recall/search over stored memory.
- **F-CONFIG-MUTABILITY:** NilClaw MUST support explicit configuration for runtime behavior.

### Provider & Routing Features
- **F-LLM-MULTIPROVIDER:** NilClaw MUST support multiple LLM providers.
- **F-LLM-COMPAT:** NilClaw MUST support OpenAI-compatible provider APIs.
- **F-ROUTING-AGENT:** NilClaw MUST route requests/events to the correct agent/session.

### Channel & Integration Features
- **F-CH-MULTICHANNEL:** NilClaw MUST support external channel integrations beyond terminal.
- **F-CH-WEBHOOK:** NilClaw MUST support webhook-based inbound message handling where applicable.

## Non-goals
- This catalog does NOT define low-level implementation design.
- This catalog does NOT define exact UI rendering details.

## Traceability Hooks
- Downstream L1 specs expected to reference these IDs in each section.

## Change Control
L0 is human-owned and frozen-by-default.
Changes require explicit human request.
