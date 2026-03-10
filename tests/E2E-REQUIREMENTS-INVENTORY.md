# NilClaw E2E Requirements Inventory

Updated: 2026-03-10

| E2E Spec | Test Case ID | Requirements |
|---|---|---|
| tests/e2e-specs/agent-core-e2e.md | E2E-AGENT-CORE | Internal runtime entrypoint (`nilclaw/agent:cli-entrypoint-available-p`) |
| tests/e2e-specs/channel-system-e2e.md | E2E-CHANNEL-SYSTEM | Internal config surface (`config-channels`) |
| tests/e2e-specs/configuration-e2e.md | E2E-CONFIGURATION | Local SBCL build/runtime only |
| tests/e2e-specs/cron-heartbeat-e2e.md | E2E-CRON-HEARTBEAT | Internal cron runtime readiness (`nilclaw/cron:cron-runtime-ready-p`) |
| tests/e2e-specs/gateway-control-plane-e2e.md | E2E-GATEWAY-CONTROL-PLANE | Internal gateway runtime readiness (`nilclaw/gateway:gateway-runtime-ready-p`) |
| tests/e2e-specs/identity-workspace-e2e.md | E2E-IDENTITY-WORKSPACE | Internal bootstrap entrypoint availability (`nilclaw/bootstrap:bootstrap-entrypoint-available-p`) |
| tests/e2e-specs/mcp-client-e2e.md | E2E-MCP-CLIENT | Internal config surface (`config-mcp-servers`) |
| tests/e2e-specs/memory-system-e2e.md | E2E-MEMORY-SYSTEM | Local SBCL build/runtime only |
| tests/e2e-specs/provider-abstraction-e2e.md | E2E-PROVIDER-ABSTRACTION | Internal provider integration readiness (`nilclaw/provider:provider-integration-ready-p`) |
| tests/e2e-specs/security-sandboxing-e2e.md | E2E-SECURITY-SANDBOXING | Local SBCL build/runtime only |
| tests/e2e-specs/skills-system-e2e.md | E2E-SKILLS-SYSTEM | Internal skills loader entrypoint availability (`nilclaw/skills:skills-loader-entrypoint-available-p`) |
| tests/e2e-specs/streaming-voice-e2e.md | E2E-STREAMING-VOICE | Internal streaming runtime availability (`nilclaw/agent:streaming-runtime-available-p`) |
| tests/e2e-specs/subagent-system-e2e.md | E2E-SUBAGENT-SYSTEM | Internal subagent runtime availability (`nilclaw/agent:subagent-runtime-available-p`) |
| tests/e2e-specs/tool-system-e2e.md | E2E-TOOL-SYSTEM | Local SBCL build/runtime only |
