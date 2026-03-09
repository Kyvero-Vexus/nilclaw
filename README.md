# NilClaw

**Common Lisp agent harness — clean-room rewrite inspired by NullClaw.**

NilClaw is a statically-typed Common Lisp implementation of a personal AI
agent harness, extracting behavioral specifications from NullClaw (Zig) and
reimplementing them in idiomatic CL with SBCL strict type declarations and
Coalton for core modules.

## Status

**Phase 0: Spec Extraction** — Converting NullClaw's architecture and behavior
into language-agnostic specifications.

## Structure

```
specs/nullclaw-adapted/  — NullClaw docs adapted to spec format (frozen)
specs/extracted/         — Hyper-specific behavioral specs from source analysis
docs/                    — Reference docs from NullClaw
src/                     — Common Lisp implementation
tests/                   — Behavioral tests
```

## License

AGPL-3.0-or-later. See [LICENSE](LICENSE) and [ATTRIBUTION.md](ATTRIBUTION.md).
