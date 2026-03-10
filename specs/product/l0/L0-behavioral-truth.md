# NilClaw Behavioral Truth

- **Layer:** L0
- **Spec ID:** L0-behavioral-truth
- **Status:** active
- **Owner:** Human
- **Last Updated:** 2026-03-10

## Description
NilClaw is a personal agent harness whose primary truth is observable behavior: a user can interact with an autonomous assistant through supported interfaces, and the assistant behaves consistently according to configured identity, memory, tools, and safety boundaries.

## Normative Truths
- T1: NilClaw MUST preserve externally observable behavior defined by behavioral specs before optimizing implementation internals.
- T2: NilClaw MUST provide deterministic-enough operational semantics for sessions, tools, memory, and routing so that behavior can be validated by tests.
- T3: NilClaw MUST prioritize safety constraints over task completion when those conflict.
- T4: NilClaw MUST treat L0/L1 specs as higher authority than implementation convenience.
- T5: NilClaw MUST support testable behavior via unit/integration/E2E pathways, with maximum feasible E2E automation.

## Optional Additional Sections
### Non-goals
- Preserving Zig implementation details is NOT a goal.
- Byte-for-byte parity with any upstream source code is NOT a goal.

## Traceability Hooks
- Downstream L1 specs expected to reference this L0 ID:
  - L1 behavior-e2e lane specs
  - L1 testing-policy lane specs
  - L1 reliability lane specs

## Change Control
L0 is human-owned and frozen-by-default.
Changes require explicit human request.
