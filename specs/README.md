# Specs Layout

This repository separates **product specs** from **meta/specops specs**.

## Product Specs (NilClaw-specific)
Located under `specs/product/`.

- `specs/product/l0/` — NilClaw top-level product truth
- `specs/product/extracted/` — behavioral product specs
- `specs/product/adapted/` — adapted upstream references

These describe NilClaw itself.

## Meta Specs (portable SpecOps)
Located under `specs/meta/`.

- `specs/meta/SPECOPS-SOURCE-OF-TRUTH.md` — pyramid/governance model
- `specs/meta/templates/` — reusable L0/L1/L2 templates

These describe how specs are managed, and are portable to other projects.

## Compatibility Links
For continuity with existing tasks/tools, the old paths are kept as symlinks:
- `specs/extracted` -> `specs/product/extracted`
- `specs/nullclaw-adapted` -> `specs/product/adapted`
- `specs/l0` -> `specs/product/l0`
- `specs/templates` -> `specs/meta/templates`
