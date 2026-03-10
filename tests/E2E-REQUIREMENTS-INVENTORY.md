# NilClaw E2E Requirements Inventory

Updated: 2026-03-10

| E2E Spec | Test Case ID | Requirements |
|---|---|---|
| tests/e2e-specs/agent-core-e2e.md | E2E-AGENT-CORE | NILCLAW_CLI_BIN |
| tests/e2e-specs/channel-system-e2e.md | E2E-CHANNEL-SYSTEM | At least one channel token: TELEGRAM_BOT_TOKEN or SLACK_BOT_TOKEN or DISCORD_TOKEN |
| tests/e2e-specs/configuration-e2e.md | E2E-CONFIGURATION | Local SBCL build/runtime only |
| tests/e2e-specs/cron-heartbeat-e2e.md | E2E-CRON-HEARTBEAT | NILCLAW_CRON_RUNTIME |
| tests/e2e-specs/gateway-control-plane-e2e.md | E2E-GATEWAY-CONTROL-PLANE | NILCLAW_GATEWAY_BIN |
| tests/e2e-specs/identity-workspace-e2e.md | E2E-IDENTITY-WORKSPACE | NILCLAW_BOOTSTRAP_ENTRYPOINT |
| tests/e2e-specs/mcp-client-e2e.md | E2E-MCP-CLIENT | MCP_SERVER_URL |
| tests/e2e-specs/memory-system-e2e.md | E2E-MEMORY-SYSTEM | Local SBCL build/runtime only |
| tests/e2e-specs/provider-abstraction-e2e.md | E2E-PROVIDER-ABSTRACTION | Provider API key (OPENAI_API_KEY or ANTHROPIC_API_KEY or GOOGLE_API_KEY) + NILCLAW_PROVIDER_INTEGRATION |
| tests/e2e-specs/security-sandboxing-e2e.md | E2E-SECURITY-SANDBOXING | Local SBCL build/runtime only |
| tests/e2e-specs/skills-system-e2e.md | E2E-SKILLS-SYSTEM | NILCLAW_SKILLS_LOADER_ENTRYPOINT |
| tests/e2e-specs/streaming-voice-e2e.md | E2E-STREAMING-VOICE | OPENAI_API_KEY or ELEVENLABS_API_KEY + NILCLAW_STREAMING_RUNTIME |
| tests/e2e-specs/subagent-system-e2e.md | E2E-SUBAGENT-SYSTEM | NILCLAW_SUBAGENT_RUNTIME |
| tests/e2e-specs/tool-system-e2e.md | E2E-TOOL-SYSTEM | Local SBCL build/runtime only |
