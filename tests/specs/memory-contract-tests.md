---
Layer: L2
Lane: integration
Spec ID: L2-INT-memory-contract-tests
Status: draft
Last Updated: 2026-03-10
Traceability:
  L1: [L1-EXT-memory-system, L1-REL-baseline-reliability]
  L0: [F-MEM-PERSISTENCE, F-MEM-RECALL, C-REL-DEGRADATION]
---

# Memory Engine Contract Test Specifications

## Overview
Contract tests verify that all memory backends (SQLite, None, Markdown, InMemoryLRU) satisfy the same interface invariants. Every backend must pass these shared contracts plus backend-specific behavioral tests.

---

## Shared Contract: Basics

For every backend:
- **name()** returns a non-empty string
- **healthCheck()** returns true after initialization
- **count()** is 0 on empty store
- **get("nonexistent")** returns null
- **recall("query", 10, null)** returns empty on empty store
- **list(null, null)** returns empty on empty store

### Tested backends
- SQLite (in-memory)
- NoneMemory
- MarkdownMemory (temp directory)
- InMemoryLRU

---

## Shared Contract: CRUD

For persisting backends (SQLite, InMemoryLRU):

1. **Store** → entry with key, content, category=core
2. **Get** → returns matching entry with correct key, content, category
3. **Recall** → query matches stored content
4. **List** by category → includes stored entry
5. **Count** → 1
6. **Store second** → count=2
7. **Forget first** → count=1, first entry returns null on get

### Tested backends
- SQLite
- InMemoryLRU

---

## Shared Contract: session_id

For every backend:
- **store** with session_id parameter does not crash
- **recall** with session_id parameter does not crash
- **list** with session_id parameter does not crash

### Tested backends
- SQLite, NoneMemory, MarkdownMemory, InMemoryLRU

---

## NoneMemory Contract

- name() returns "none"
- store does not crash (no-op)
- get always returns null
- recall always returns empty
- list always returns empty
- count always returns 0
- forget always returns false
- Multiple stores → count still 0

---

## MarkdownMemory Contract

- name() returns "markdown"
- healthCheck() returns true
- count starts at 0
- After store → count=1
- get returns entry containing both key and content (markdown-formatted)
- recall finds entries by query
- list by category returns entries
- Second store → count=2
- **forget always returns false** (append-only backend)
- Count unchanged after forget attempt (still 2)
