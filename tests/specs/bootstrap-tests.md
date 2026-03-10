---
Layer: L2
Lane: unit
Spec ID: L2-UNIT-bootstrap-tests
Status: draft
Last Updated: 2026-03-10
Traceability:
  L1: [L1-EXT-identity-workspace]
  L0: [F-AGENT-SESSIONS, F-MEM-PERSISTENCE]
---

# Bootstrap Provider Test Specifications

## Overview
The bootstrap module provides a pluggable provider system for storing and loading workspace bootstrap files (SOUL.md, AGENTS.md, IDENTITY.md, etc.). Implementations include FileBootstrapProvider (disk), MemoryBootstrapProvider (SQLite/LRU-backed), and NullBootstrapProvider (no-op). A factory creates the appropriate provider based on the configured backend.

---

## Contract Tests (Shared Across Persisting Providers)

### Store and load roundtrip
- **Action**: Store "SOUL.md" with content "# Soul v1"
- **Expected**: load("SOUL.md") returns "# Soul v1"

### Exists
- Stored file → exists returns true
- Non-stored file → exists returns false

### Overwrite
- Store "SOUL.md" v1, then v2
- **Expected**: load returns v2

### Excerpt loading
- Store "SOUL.md" = "# Soul v2", load_excerpt with limit=3
- **Expected**: Returns "# S" (first 3 characters)

### List contains stored files
- Store 2 files → list returns ≥2 items

### Remove
- Remove stored file → returns true, exists returns false

### Fingerprint changes on modification
- Get fingerprint, store new file, get fingerprint again
- **Expected**: Fingerprints differ

### Load missing file → null

### Tested with:
- FileBootstrapProvider (temp directory)
- MemoryBootstrapProvider (InMemoryLRU backend)

---

## NullBootstrapProvider Contract

### No-op semantics
- store does not crash
- load always returns null
- load_excerpt always returns null
- exists always returns false
- list returns empty (length 0)
- remove returns false
- fingerprint always returns 0

---

## Integration Tests (Factory)

### Factory creates FileBootstrapProvider for "hybrid" backend
- **Setup**: Temp directory, backend="hybrid"
- **Expected**: Store/load works, file actually exists on disk

### Factory creates MemoryBootstrapProvider for "sqlite" backend
- **Setup**: InMemoryLRU, backend="sqlite"
- **Expected**: Store/load works, data lives in memory (not disk)

### MemoryBootstrapProvider disk fallback
- **Setup**: File written to disk ("IDENTITY.md"), then create sqlite provider with workspace path
- **Expected**: load("IDENTITY.md") finds file via disk fallback, returns disk content

### Factory creates NullBootstrapProvider for "none" backend
- Store "SOUL.md" → load returns null

### Factory creates NullBootstrapProvider for "memory" backend
- Store "AGENTS.md" → load returns null
