# NilClaw Key Technical Attributes

- **Layer:** L0
- **Spec ID:** L0-key-technical-attributes
- **Status:** active
- **Owner:** Human
- **Last Updated:** 2026-03-10

## Description
These are foundational technical properties required for NilClaw to unfold behavior correctly over time.

## Normative Truths
- T1: NilClaw implementation MUST be Common Lisp-first, with strict static typing discipline (SBCL declarations; Coalton for appropriate pure-core modules).
- T2: NilClaw runtime model MUST remain agentic: sessions, tool invocation, memory, scheduling, and subagents are first-class runtime concepts.
- T3: NilClaw MUST expose behavior through stable interfaces (CLI/gateway/channels) decoupled from internal module implementation.
- T4: NilClaw MUST maintain explicit configuration and policy surfaces rather than hidden magic behavior.
- T5: NilClaw MUST keep testability as a core property of every major subsystem.

## Optional Additional Sections
### Runtime Philosophy
- Treat the system as a programmable agent runtime, not merely a chat wrapper.

## Traceability Hooks
- Downstream L1 specs expected to reference this L0 ID:
  - L1 engineering-policy
  - L1 architecture
  - L1 contracts
  - L1 observability

## Change Control
L0 is human-owned and frozen-by-default.
Changes require explicit human request.
