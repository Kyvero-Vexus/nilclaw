# NilClaw Spec Extraction Task

## Context
NilClaw is a clean-room Common Lisp rewrite of NullClaw (a Zig-based AI agent harness).
Source reference: `~/external_src/nullclaw/`
Target repo: `~/projects/nilclaw/`

## Your Job
Work through the beads in `~/projects/nilclaw/` (run `bd ready --json` to see what's unblocked).
For each bead, extract behavioral specifications from NullClaw's Zig source code.

## Rules

### Language-Agnostic Specs
- Describe WHAT the system does, not HOW it's implemented in Zig
- No Zig types, no allocator patterns, no comptime, no `std.mem` references
- Use abstract terms: "interface" not "vtable", "map" not "StringHashMap", "string" not "[]const u8"
- Describe data structures as schemas (JSON-like or table format)
- Describe protocols as sequences of steps

### Spec Format (per file)
```markdown
# [Module Name] Specification

## Overview
Brief description of this subsystem's purpose and boundaries.

## Data Model
Schemas, types, state that this module manages.

## Behavior
### [Behavior Name]
Step-by-step description of what happens, when, and why.
Include: inputs, outputs, error conditions, edge cases.

## Constraints
Safety invariants, limits, required guarantees.

## Configuration
Config keys that affect this module, their types, defaults, and effects.

## Integration Points
How this module interacts with other modules.
```

### Process Per Bead
1. `bd update <id> --claim`
2. Read the relevant Zig source files listed in the bead description
3. Extract behavioral spec into the target file
4. `git add && git commit` with descriptive message
5. `bd close <id> --reason "Spec extracted"`
6. Move to next bead

### Quality Bar
- A competent programmer who has never seen Zig should be able to implement
  the system from your spec alone
- Include specific numbers (buffer sizes, timeouts, limits) when they appear in source
- Include error handling behavior — what happens on failure?
- Include config schema with exact key names, types, and defaults

### Priority
Work P0 beads first, then P1, then P2. Within same priority, any order is fine.

### Commit Convention
```
feat(specs): extract [module] specification

[brief description of what was extracted]

Co-authored-by: htayj <htayj@users.noreply.github.com>
```

### Push
Push after every 3-4 specs or when done. Push to GitHub origin.
