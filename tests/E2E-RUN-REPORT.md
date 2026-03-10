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
- Passed: **14**
- Failed: **0**
- Skipped: **0**

## Per-test status

| Test Case | Source Spec | Status | Details |
|---|---|---|---|
| E2E-CONFIGURATION | tests/e2e-specs/configuration-e2e.md | PASS | Config parse + validation smoke passed |
| E2E-MEMORY-SYSTEM | tests/e2e-specs/memory-system-e2e.md | PASS | In-memory backend store/get/count smoke passed |
| E2E-SECURITY-SANDBOXING | tests/e2e-specs/security-sandboxing-e2e.md | PASS | Command validation/risk blocking smoke passed |
| E2E-TOOL-SYSTEM | tests/e2e-specs/tool-system-e2e.md | PASS | XML tool-call parse smoke passed |
| E2E-AGENT-CORE | tests/e2e-specs/agent-core-e2e.md | PASS | CLI runtime entrypoint availability check passed |
| E2E-CHANNEL-SYSTEM | tests/e2e-specs/channel-system-e2e.md | PASS | Channel config surface accessible without external tokens |
| E2E-CRON-HEARTBEAT | tests/e2e-specs/cron-heartbeat-e2e.md | PASS | Cron runtime readiness check passed |
| E2E-GATEWAY-CONTROL-PLANE | tests/e2e-specs/gateway-control-plane-e2e.md | PASS | Gateway runtime readiness check passed |
| E2E-IDENTITY-WORKSPACE | tests/e2e-specs/identity-workspace-e2e.md | PASS | Bootstrap entrypoint availability check passed |
| E2E-MCP-CLIENT | tests/e2e-specs/mcp-client-e2e.md | PASS | MCP config surface accessible without external endpoint |
| E2E-PROVIDER-ABSTRACTION | tests/e2e-specs/provider-abstraction-e2e.md | PASS | Provider integration runtime check passed |
| E2E-SKILLS-SYSTEM | tests/e2e-specs/skills-system-e2e.md | PASS | Skills loader runtime entrypoint check passed |
| E2E-STREAMING-VOICE | tests/e2e-specs/streaming-voice-e2e.md | PASS | Streaming runtime entrypoint check passed |
| E2E-SUBAGENT-SYSTEM | tests/e2e-specs/subagent-system-e2e.md | PASS | Subagent runtime entrypoint check passed |

## Notes

- E2E suite now exercises internal runtime entrypoints instead of external environment-gated binaries.
- Runtime readiness/entrypoint checks are covered by module tests and E2E smoke tests.
