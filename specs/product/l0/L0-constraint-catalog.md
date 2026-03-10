# NilClaw Constraint Catalog (Baseline)

- **Layer:** L0
- **Spec ID:** L0-constraint-catalog
- **Status:** active
- **Owner:** Human
- **Last Updated:** 2026-03-10

## Description
This catalog defines non-negotiable constraints and invariants that bound NilClaw behavior. Constraints are distinct from features.

## Constraint Truths

### Security Constraints
- **C-SEC-POLICY-ENFORCEMENT:** Command/tool execution MUST be governed by explicit policy rules.
- **C-SEC-SANDBOX-BOUNDARY:** High-risk execution paths MUST respect sandbox boundaries where configured.
- **C-SEC-AUTH-BOUNDARY:** Protected interfaces MUST require authentication/authorization.
- **C-SEC-SECRET-HANDLING:** Secrets MUST NOT be exposed in unsafe contexts (logs/prompts/errors) beyond approved policy.

### Safety Constraints
- **C-SAFE-PRIORITY:** Safety constraints MUST take precedence over task completion.
- **C-SAFE-EXTERNAL-ACTION-GATING:** External-impacting actions MUST remain auditable and policy-constrained.

### Reliability Constraints
- **C-REL-TIMEOUT-RETRY:** External operations MUST have bounded timeout/retry behavior.
- **C-REL-DEGRADATION:** On subsystem/provider failure, NilClaw SHOULD degrade gracefully rather than catastrophically.

### Testability & Governance Constraints
- **C-TEST-TRACEABILITY:** Implemented behavior MUST be traceable through L2/L3 tests back to L1/L0.
- **C-CONFIG-EXPLICITNESS:** Runtime behavior MUST be governed by explicit config/policy surfaces, not hidden implicit state.

## Traceability Hooks
- L1 lane mappings expected in security/reliability/testing-policy/operations.

## Change Control
L0 is human-owned and frozen-by-default.
Changes require explicit human request.
