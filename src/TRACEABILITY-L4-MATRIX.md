# NilClaw L4 Coverage Matrix (L3 -> L4)

Generated/updated: 2026-03-10

## Mapping

| L3 Test Artifact | L4 Implementation Artifact(s) |
|---|---|
| tests/config-tests.lisp | src/config/types.lisp, src/config/parse.lisp, src/config/validate.lisp, src/config/serialize.lisp |
| tests/security-policy-tests.lisp | src/security/types.lisp, src/security/policy.lisp, src/security/commands.lisp |
| tests/memory-contract-tests.lisp | src/memory/contract.lisp, src/memory/none-backend.lisp, src/memory/markdown-backend.lisp, src/memory/lru-backend.lisp |
| tests/agent-dispatcher-tests.lisp | src/dispatcher/types.lisp, src/dispatcher/xml-parser.lisp, src/dispatcher/native-parser.lisp, src/dispatcher/function-tag-parser.lisp, src/dispatcher/json-repair.lisp, src/dispatcher/json-extract.lisp, src/dispatcher/format-results.lisp, src/dispatcher/dispatcher.lisp |
| tests/memory-sqlite-tests.lisp | src/memory/contract.lisp, src/config/types.lisp |
| tests/providers-compatible-tests.lisp | src/provider/types.lisp, src/provider/compatible.lisp |
| tests/skills-tests.lisp | src/skills/types.lisp, src/skills/registry.lisp |
| tests/bootstrap-tests.lisp | src/bootstrap/bootstrap.lisp |
| tests/cron-tests.lisp | src/cron/types.lisp, src/cron/scheduler.lisp |
| tests/gateway-tests.lisp | src/gateway/types.lisp, src/gateway/gateway.lisp |
| tests/agent-root-tests.lisp | src/agent/types.lisp, src/agent/agent.lisp |
| tests/traceability-linkage-tests.lisp | src/bootstrap/bootstrap.lisp, src/gateway/gateway.lisp, src/security/policy.lisp, src/agent/agent.lisp |
| tests/e2e-smoke-tests.lisp | src/config/parse.lisp, src/config/validate.lisp, src/memory/lru-backend.lisp, src/security/commands.lisp, src/dispatcher/dispatcher.lisp |

## Unmapped src modules

None.
