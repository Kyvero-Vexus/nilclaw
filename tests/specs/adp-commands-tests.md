---
Layer: L2
Lane: unit
Spec ID: L2-UNIT-adp-commands-tests
Status: draft
Last Updated: 2026-03-10
Traceability:
  L1: [L1-ADP-commands]
  L0: [F-UI-CLI, F-CONFIG-MUTABILITY]
---

# L2-UNIT-adp-commands-tests

## Overview
L2 traceability bridge for L1-ADP-commands. This spec is covered by linkage tests in `tests/traceability-linkage-tests.lisp` and mapped in `tests/TRACEABILITY-L3-MATRIX.md`.

## Assertions
- The corresponding L1 specification artifact exists and remains parseable.
- The L2 spec remains linked to L1 and L0 IDs listed in frontmatter.
- A downstream L3 mapping exists for this L2 spec.
