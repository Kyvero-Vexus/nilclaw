# NilClaw Usage Metaphors

- **Layer:** L0
- **Spec ID:** L0-usage-metaphors
- **Status:** active
- **Owner:** Human
- **Last Updated:** 2026-03-10

## Description
Define the symbolic objects users and developers reason with when using NilClaw.

## Normative Truths
- T1: Session is a primary metaphor: interaction state lives in named, durable sessions.
- T2: Agent is a primary metaphor: identity + policy + tools + memory as one operational persona.
- T3: Tool call is a primary metaphor: capabilities are explicit invocations with observable inputs/outputs.
- T4: Memory is a primary metaphor: recall and persistence are explicit and testable, not implicit hidden context.
- T5: Beads/tasks are a primary metaphor for work decomposition and progress tracking.
- T6: Spec pyramid is a primary metaphor for authority flow: L0 intention -> L1 design -> L2 test specs -> L3 tests -> L4 implementation.

## Optional Additional Sections
### Terminology Guardrails
- “Behavioral parity” means parity of externally observable outcomes, not implementation language parity.

## Traceability Hooks
- Downstream L1 specs expected to reference this L0 ID:
  - L1 behavior-e2e
  - L1 architecture
  - L1 testing-policy
  - L1 operations

## Change Control
L0 is human-owned and frozen-by-default.
Changes require explicit human request.
