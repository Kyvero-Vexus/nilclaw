---
Layer: L2
Lane: integration
Spec ID: L2-INT-adp-architecture-tests
Status: draft
Last Updated: 2026-03-10
Traceability:
  L1: [L1-ADP-architecture]
  L0: [F-UI-GATEWAY, F-AGENT-SESSIONS]
---

# L2-INT-adp-architecture-tests

## Overview
L2 traceability bridge for L1-ADP-architecture. This spec is covered by linkage tests in `tests/traceability-linkage-tests.lisp` and mapped in `tests/TRACEABILITY-L3-MATRIX.md`.

## Assertions
- The corresponding L1 specification artifact exists and remains parseable.
- The L2 spec remains linked to L1 and L0 IDs listed in frontmatter.
- A downstream L3 mapping exists for this L2 spec.
