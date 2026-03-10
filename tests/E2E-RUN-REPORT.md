# NilClaw E2E Run Report

Run date: 2026-03-10
Command:

```bash
sbcl --non-interactive \
  --eval '(require :asdf)' \
  --eval '(asdf:load-asd (truename "nilclaw.asd"))' \
  --eval '(asdf:load-system :nilclaw/tests)' \
  --eval '(fiveam:run! (quote nilclaw/tests::e2e-suite))'
```

## Summary

- Total E2E tests: **14**
- Passed: **4**
- Failed: **0**
- Skipped: **10**

## Per-test status

| Test Case | Source Spec | Status | Details |
|---|---|---|---|
| E2E-CONFIGURATION | tests/e2e-specs/configuration-e2e.md | PASS | Config parse + validation smoke passed |
| E2E-MEMORY-SYSTEM | tests/e2e-specs/memory-system-e2e.md | PASS | In-memory backend store/get/count smoke passed |
| E2E-SECURITY-SANDBOXING | tests/e2e-specs/security-sandboxing-e2e.md | PASS | Command validation/risk blocking smoke passed |
| E2E-TOOL-SYSTEM | tests/e2e-specs/tool-system-e2e.md | PASS | XML tool-call parse smoke passed |
| E2E-AGENT-CORE | tests/e2e-specs/agent-core-e2e.md | SKIPPED | NILCLAW_CLI_BIN missing |
| E2E-CHANNEL-SYSTEM | tests/e2e-specs/channel-system-e2e.md | SKIPPED | TELEGRAM_BOT_TOKEN and SLACK_BOT_TOKEN and DISCORD_TOKEN missing |
| E2E-CRON-HEARTBEAT | tests/e2e-specs/cron-heartbeat-e2e.md | SKIPPED | NILCLAW_CRON_RUNTIME missing |
| E2E-GATEWAY-CONTROL-PLANE | tests/e2e-specs/gateway-control-plane-e2e.md | SKIPPED | NILCLAW_GATEWAY_BIN missing |
| E2E-IDENTITY-WORKSPACE | tests/e2e-specs/identity-workspace-e2e.md | SKIPPED | NILCLAW_BOOTSTRAP_ENTRYPOINT missing |
| E2E-MCP-CLIENT | tests/e2e-specs/mcp-client-e2e.md | SKIPPED | MCP_SERVER_URL missing |
| E2E-PROVIDER-ABSTRACTION | tests/e2e-specs/provider-abstraction-e2e.md | SKIPPED | NILCLAW_PROVIDER_INTEGRATION missing |
| E2E-SKILLS-SYSTEM | tests/e2e-specs/skills-system-e2e.md | SKIPPED | NILCLAW_SKILLS_LOADER_ENTRYPOINT missing |
| E2E-STREAMING-VOICE | tests/e2e-specs/streaming-voice-e2e.md | SKIPPED | OPENAI_API_KEY and ELEVENLABS_API_KEY missing; NILCLAW_STREAMING_RUNTIME missing |
| E2E-SUBAGENT-SYSTEM | tests/e2e-specs/subagent-system-e2e.md | SKIPPED | NILCLAW_SUBAGENT_RUNTIME missing |

## Notes

- New L3 artifact added: `tests/e2e-smoke-tests.lisp`.
- This run converts currently implementable E2E specs into executable smoke coverage and marks unavailable interfaces/credentials explicitly as SKIPPED.
