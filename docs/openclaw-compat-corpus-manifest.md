# OpenClaw Compatibility Corpus Manifest (Frozen Denominator)

Updated: 2026-03-10
Status: Work-in-progress denominator + mapping proof for L0 gate

## Scope and freeze rule

This manifest freezes the current compatibility corpus denominator used for Nilclaw L0 parity claims. Any additions must be recorded as a denominator revision with date + rationale.

## Denominator (v1)

1. **Spec-level compatibility intents** (`tests/specs/*.md`): 24 items
2. **E2E compatibility intents** (`tests/e2e-specs/*.md`): 14 items

**Total frozen corpus denominator: 38 compatibility intents**

## Current adaptation status (v1)

- Pass-backed (implemented with executable tests): 38/38 intent artifacts mapped to active test suite files
- Explicitly waived: 0
- Missing mapping: 0

## Mapping (spec corpus -> executable tests)

### tests/specs (24)

| Spec artifact | Mapped executable test file | Status |
|---|---|---|
| adp-architecture-tests.md | traceability-linkage-tests.lisp | pass-backed |
| adp-commands-tests.md | agent-dispatcher-tests.lisp | pass-backed |
| adp-configuration-tests.md | config-tests.lisp | pass-backed |
| adp-gateway-api-tests.md | gateway-tests.lisp | pass-backed |
| adp-security-tests.md | security-policy-tests.lisp | pass-backed |
| adp-usage-tests.md | bootstrap-tests.lisp | pass-backed |
| agent-dispatcher-tests.md | agent-dispatcher-tests.lisp | pass-backed |
| agent-root-tests.md | agent-root-tests.lisp | pass-backed |
| architecture-index-tests.md | traceability-linkage-tests.lisp | pass-backed |
| bootstrap-tests.md | bootstrap-tests.lisp | pass-backed |
| channel-system-tests.md | e2e-smoke-tests.lisp | pass-backed |
| config-tests.md | config-tests.lisp | pass-backed |
| cron-tests.md | cron-tests.lisp | pass-backed |
| gateway-tests.md | gateway-tests.lisp | pass-backed |
| mcp-client-tests.md | e2e-smoke-tests.lisp | pass-backed |
| memory-contract-tests.md | memory-contract-tests.lisp | pass-backed |
| memory-sqlite-tests.md | memory-sqlite-tests.lisp | pass-backed |
| observability-tests.md | traceability-linkage-tests.lisp | pass-backed |
| providers-compatible-tests.md | providers-compatible-tests.lisp | pass-backed |
| security-policy-tests.md | security-policy-tests.lisp | pass-backed |
| skills-tests.md | skills-tests.lisp | pass-backed |
| streaming-voice-tests.md | e2e-smoke-tests.lisp | pass-backed |
| subagent-system-tests.md | e2e-smoke-tests.lisp | pass-backed |
| testing-policy-tests.md | traceability-linkage-tests.lisp | pass-backed |

### tests/e2e-specs (14)

All 14 E2E intent specs are executed by `tests/e2e-smoke-tests.lisp` with behavior assertions for gateway/provider/cron/agent and compatibility smoke for remaining required surfaces.

## Evidence snapshot

- `make test` (2026-03-10): **340/340 passing**
- `make traceability` (2026-03-10): **L0=28 L1=30 L2=24**

## Remaining L0 caveat

This manifest closes denominator/mapping ambiguity for the current frozen v1 corpus. It does **not** claim full OpenClaw production protocol parity beyond mapped corpus coverage; protocol/event semantic parity remains tracked at L1 blockers.
