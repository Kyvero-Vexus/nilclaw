# NilClaw Source-of-Truth Pyramid

Status: Draft v0.1  
Owner: Human (top-level authority), executed by agents

## Purpose

Define a strict, version-controlled authority hierarchy for how NilClaw is specified, tested, and implemented.

Core principle:
- **Meaning is concentrated at the top.**
- **Volume and literal detail increase downward.**
- **Lower layers must trace back to higher layers.**

---

## Authority Layers

## L0 — Product Constitution / Behavioral Truth (Top Authority)

Human-owned, frozen-by-default.

Contents:
- Core behavioral truths (what NilClaw must do)
- Key technical attributes (runtime invariants, language constraints, foundational properties)
- Usage metaphors (core symbolic objects and interaction model)

Change policy:
- Only by explicit direct human request.
- Agents may propose edits, but cannot autonomously rewrite L0 intent.

Current mapping targets:
- `specs/extracted/*.md` clauses tagged as `L0:<id>` where applicable

---

## L1 — System Design Specifications

Human+agent, human-ratified.

Contents:
- End-to-end behavior specs (observable flows)
- Architecture specs (module boundaries, interfaces, composition)
- Engineering policy specs (typing, library constraints, style)
- Testing policy specs (taxonomy, pass criteria, quality gates)

Change policy:
- Rare.
- GM/agents may edit with strong rationale.
- Human can approve/veto.

Planned structure:
- `specs/l1/e2e/`
- `specs/l1/architecture/`
- `specs/l1/engineering-policy/`
- `specs/l1/testing-policy/`

---

## L2 — Test Specifications

Agent-heavy, human-auditable.

Contents:
- Behavioral test specs per module/feature
- Scenario-level expected outcomes
- Traceability links to L1/L0 clauses

Change policy:
- Frequent.
- Must preserve upward traceability.

Current mapping targets:
- `tests/specs/*.md`
- Future: `tests/e2e-specs/*.md`

---

## L3 — Test Code

Primarily agent-generated executable validation.

Contents:
- Unit/integration test code (FiveAM)
- E2E automation code where possible
- Test fixtures, harnesses, runners

Change policy:
- Frequent.
- Must faithfully implement L2 specs.

Notes on E2E:
- Not all E2E scenarios are automatable.
- Requirement: **automate as much as possible**.
- For non-automated E2E, keep executable manual procedures in L2 with reproducible steps.

---

## L4 — Program Implementation

Lowest authority, highest volume; fully constrained by higher layers.

Contents:
- Production Common Lisp code
- Module wiring, integration glue

Change policy:
- Very frequent.
- Must satisfy L3 tests, and therefore L2/L1/L0 indirectly.

---

## Traceability (Mandatory)

Every layer must link upward:

- **L4 code** ↔ **L3 tests**
- **L3 tests** ↔ **L2 test specs**
- **L2 test specs** ↔ **L1/L0 clauses**

Minimum linking rules:
1. Every test file must declare which L2 spec file(s) it implements.
2. Every L2 spec section must reference relevant L1/L0 IDs.
3. Every implementation module bead should reference the test bead(s) that validate it.

Planned enhancement:
- Add explicit trace IDs (`L0-...`, `L1-...`, `L2-...`) and machine-readable link index.

---

## Complexity/Volume Gradient

As you move down from L0 → L4:
- Material volume increases
- Information compression decreases
- Operational detail increases
- Autonomy of agents increases
- Allowed semantic drift decreases

Interpretation:
- Top layers decide meaning.
- Bottom layers realize meaning.

---

## Change-Control Summary

- **L0**: Human-only authority; frozen except explicit change requests.
- **L1**: Rare changes; strong rationale; human oversight expected.
- **L2**: Agent-driven updates allowed; must keep traceability.
- **L3/L4**: High-change layers; validated by tests and bead workflow.

---

## Immediate Next Iterations

1. Define template set for L1 specs (progressively strict variants).
2. Define template set for L2 specs (unit/integration/e2e-manual/e2e-automated).
3. Add traceability ID convention and backfill current specs/tests.
4. Add CI checks for missing trace links.
5. Add E2E automation strategy matrix (fully auto / semi-auto / manual verified).

---

## Relationship to Existing NilClaw Assets

Existing:
- Behavioral specs: `specs/extracted/`
- Adapted references: `specs/nullclaw-adapted/`
- Behavioral test specs: `tests/specs/`
- Planned E2E test specs: beads created under `nilclaw-54s` children

This document governs how those artifacts evolve.
