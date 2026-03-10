---
Layer: L2
Lane: unit
Spec ID: L2-UNIT-adp-security-tests
Status: draft
Last Updated: 2026-03-10
Traceability:
  L1: [L1-ADP-security]
  L0: [C-SEC-POLICY-ENFORCEMENT, C-SEC-SANDBOX-BOUNDARY, C-SEC-SECRET-HANDLING]
---

# L2-UNIT-adp-security-tests

## Overview
L2 traceability bridge for L1-ADP-security. This spec is covered by linkage tests in `tests/traceability-linkage-tests.lisp` and mapped in `tests/TRACEABILITY-L3-MATRIX.md`.

## Assertions
- The corresponding L1 specification artifact exists and remains parseable.
- The L2 spec remains linked to L1 and L0 IDs listed in frontmatter.
- A downstream L3 mapping exists for this L2 spec.
