# NilClaw Traceability Matrix

- L0 IDs total: 28
- L1 specs total: 30
- L2 specs total: 24
- Clean L1->L0 mappings: 30/30
- Clean L2->L1+L0 mappings: 24/24
- Clean L2->L3 mappings: 24/24
- Clean L3->L4 mappings: 12/12 mapped L3 artifacts

## L0 IDs
- C-CONFIG-EXPLICITNESS
- C-REL-DEGRADATION
- C-REL-TIMEOUT-RETRY
- C-SAFE-EXTERNAL-ACTION-GATING
- C-SAFE-PRIORITY
- C-SEC-AUTH-BOUNDARY
- C-SEC-POLICY-ENFORCEMENT
- C-SEC-SANDBOX-BOUNDARY
- C-SEC-SECRET-HANDLING
- C-TEST-TRACEABILITY
- F-AGENT-SCHEDULING
- F-AGENT-SESSIONS
- F-AGENT-SUBAGENTS
- F-CAP-MCP
- F-CAP-SKILLS
- F-CAP-TOOLS
- F-CH-MULTICHANNEL
- F-CH-WEBHOOK
- F-CONFIG-MUTABILITY
- F-LLM-COMPAT
- F-LLM-MULTIPROVIDER
- F-MEM-PERSISTENCE
- F-MEM-RECALL
- F-ROUTING-AGENT
- F-UI-CLI
- F-UI-GATEWAY
- F-UI-STREAMING
- F-UI-TERMINAL-CLIENT

## L0 without L1 refs

None.

## E2E validation snapshot (2026-03-10)

- E2E L3 artifact: `tests/e2e-smoke-tests.lisp`
- Total E2E cases from `tests/e2e-specs/*`: 14
- PASS: 4
- FAIL: 0
- SKIPPED: 10 (explicit requirements documented in `tests/E2E-RUN-REPORT.md` and `tests/E2E-REQUIREMENTS-INVENTORY.md`)
