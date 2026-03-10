# NilClaw

**Statically typed Common Lisp agent harness inspired by NullClaw.**

NilClaw is a clean-room Common Lisp reimplementation of an agent harness in the
same general problem space as NullClaw, with an emphasis on:

- **SBCL strict type declarations** across the codebase
- **Coalton** for strongly typed core logic where appropriate
- **Spec-driven development** from extracted and adapted behavioral documents
- **Libre software** distribution under **AGPL-3.0-or-later**

## Status

NilClaw is **early-stage and not yet production-ready**.

Current work is focused on:

1. extracting product behavior into portable specifications,
2. building a typed Common Lisp implementation, and
3. validating compatibility with spec-oriented tests.

## Repository Layout

```text
specs/nullclaw-adapted/  adapted product/spec documents
specs/extracted/         extracted behavioral specs from source analysis
specs/product/           normalized product-facing specification set
src/                     Common Lisp implementation
tests/                   behavioral and regression tests
docs/                    reference docs and notes
scripts/                 project helpers
```

## Goals

- Build a capable personal-agent harness in Common Lisp
- Preserve a clear separation between **specification** and **implementation**
- Push toward a **typed Lisp** architecture instead of ad hoc dynamic sprawl
- Keep the project understandable enough to serve as a research base for future
  Lisp-native agent systems

## License

Licensed under **AGPL-3.0-or-later**. See [LICENSE](LICENSE).

Third-party provenance and attribution notes live in
[ATTRIBUTION.md](ATTRIBUTION.md).
