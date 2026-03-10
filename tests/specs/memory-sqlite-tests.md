---
Layer: L2
Lane: integration
Spec ID: L2-INT-memory-sqlite-tests
Status: draft
Last Updated: 2026-03-10
Traceability:
  L1: [L1-EXT-memory-system]
  L0: [F-MEM-PERSISTENCE, F-MEM-RECALL]
---

# Memory SQLite Engine Test Specifications

## Overview
The SQLite memory engine provides persistent key-value storage with full-text search (FTS5), category filtering, session scoping, message history, and auto-save cleanup. It serves as the primary memory backend for the agent system.

---

## Mountinfo Parser

### Decodes escaped mount point and picks network filesystem
- **Input**: Mount entries for root (ext4) and network share (9p with octal-escaped space in path)
- **Expected**: Correctly identifies network filesystem for the matching path

### Enforces directory boundary on prefix matches
- Mount for `/mnt/share`, path is `/mnt/share2/memory.db`
- **Expected**: Does not match (no directory boundary at position)

---

## Initialization

### In-memory database
- Init with ":memory:" → succeeds, can store messages

### Configures busy timeout
- After init, PRAGMA busy_timeout ≥ configured BUSY_TIMEOUT_MS

### Name returns "sqlite"

### Health check passes
- After init → healthCheck() returns true

### Health check after operations
- Store, recall, forget operations → healthCheck still returns true

---

## Basic CRUD

### Store and get
- Store key="user_lang", content="Prefers Zig", category=core
- Get "user_lang" → key, content, and category all match

### Store upsert (same key replaces)
- Store "pref"="likes Zig", then "pref"="loves Zig"
- Get → content is "loves Zig", count is 1

### Get nonexistent → null

### Count empty → 0

### Store empty content → retrievable with empty string
### Store empty key → retrievable with empty string key

### Store unicode content → roundtrips correctly
### Store long content → stored and retrievable

### Store with special chars in key → roundtrips correctly
### Store newlines in content → roundtrips correctly

---

## Category Support

### Category roundtrip
- Store entries with categories: core, daily, conversation, custom("project")
- Get each → category matches original

### List all → returns all entries regardless of category

### List by category
- 2 core + 1 daily → list(.core) returns 2, list(.daily) returns 1

### List custom category
- 2 entries with custom="project" + 1 core → list(custom="project") returns 2

### List empty db → empty list

### Upsert changes category
- Store key with one category, upsert with different category → category updated

### Multiple categories count
- Entries across multiple categories → count reflects total

---

## Full-Text Search (Recall)

### Keyword search
- 3 entries, 2 containing "Zig" → recall("Zig") returns 2

### No match → empty results

### Empty query → empty results
### Whitespace query → empty results

### Matches by key not just content
- Key "zig_preferences", content without "zig" → recall("zig") still finds it (searches keys too)

### Respects limit
- 10 searchable entries, limit=3 → ≤3 results

### Results have scores
- Each recalled entry has a non-null score

### Multi-word query
- Searches for multi-word terms

### Recall with quotes in query
- Query containing quote characters → handled safely

### Unicode query → finds unicode content

### SQL injection attempt
- Query: `'; DROP TABLE memories; --`
- **Expected**: Data intact, count unchanged (parameterized queries prevent injection)

### SQL LIKE wildcard percent in content
- Content containing literal "%" character → recalled without treating as wildcard

### SQL LIKE wildcard underscore in content
- Content containing literal "_" character → recalled without treating as wildcard

### escapeLikePattern escapes wildcards
- "%" and "_" are escaped in LIKE patterns

---

## Forget (Delete)

### Forget existing entry → returns true, count decremented
### Forget nonexistent → returns false

### Forget then recall: no ghost results
- Store, forget, recall same content → 0 results (FTS index cleaned)

### Forget and re-store same key
- Store, forget, re-store → only 1 entry, content is new version

### Store and forget multiple keys
- Store 3, forget 2 → count is 1

---

## FTS5 Synchronization

### Schema has fts5 table
- `memories_fts` table exists in sqlite_master

### FTS syncs on insert
- After store → content findable via direct FTS5 MATCH query

### FTS syncs on delete
- After forget → content no longer in FTS5 index

### FTS syncs on update
- After upsert → old content removed from FTS, new content present

---

## Reindex

### Reindex after store → recall still works
- Store 2 entries, reindex, recall → both found

---

## List

### List returns all entries
- Multiple entries → list returns all with correct fields

---

## Session Scoping

### Store with session_id persists
- Store with session_id="sess-1" → get returns entry with session_id

### Store without session_id → session_id is null

### Recall with session_id filters correctly
- 2 entries in different sessions → recall with session_id returns only matching session's entries

### Recall with null session_id returns all
- Entries across sessions → null session_id search returns all

### List with session_id filter
- Filters entries to matching session

### List with session_id and category filter
- Combines both filters

### Cross-session recall isolation
- Session A and B entries → recall from A sees only A's data

### Schema has session_id column
### Schema migration is idempotent (re-init doesn't fail)

### Upsert updates session_id from null to value
### Upsert updates session_id from value to null

---

## Auto-Save Cleanup

### clearAutoSaved removes autosave entries
- Entries with key prefix indicating autosave → cleared

### clearAutoSaved scoped by session_id
- Only clears autosave entries for the specified session

### clearAutoSaved preserves non-autosave entries
### clearAutoSaved no-op on empty database

---

## Session Store (Message History)

### sessionStore returns valid vtable

### saveMessage + loadMessages roundtrip
- Save messages to session → loadMessages returns them

### clearMessages
- Clear messages for a session → loadMessages returns empty

### clearAutoSaved via session store interface

### loadMessages empty session → empty list

### loadMessages preserves order
- Messages returned in insertion order

### clearMessages does not affect other sessions
- Clear session A → session B messages intact

---

## KV Table

### sqlite kv table exists
- Key-value table present in schema

---

## saveMessage

### Stores messages correctly
- Role and content persisted and retrievable
