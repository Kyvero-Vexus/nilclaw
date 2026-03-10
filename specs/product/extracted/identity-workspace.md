---
Layer: L1
Lane: engineering-policy
Spec ID: L1-EXT-identity-workspace
Status: draft
Last Updated: 2026-03-10
Traceability:
  L0: [F-AGENT-SESSIONS, F-MEM-PERSISTENCE, C-CONFIG-EXPLICITNESS]
---

# Identity & Workspace Files Specification

## Overview

The identity and workspace system manages the agent's persona, operational
rules, and user context through a set of markdown workspace files and an
optional structured identity format (AIEOS). These files are loaded at prompt
build time, injected into the system prompt, and tracked for changes via
fingerprinting. A bootstrap provider abstraction handles storage backend
differences.

## Workspace Bootstrap Files

### Canonical File List and Loading Order

Files are injected into the system prompt in this exact order:

1. `AGENTS.md` — operational guidance, startup routines, red-line constraints
2. `SOUL.md` — persona, tone, and character
3. `TOOLS.md` — user-authored tool usage guidance (does NOT control tool availability)
4. `IDENTITY.md` — agent identity metadata
5. `USER.md` — information about the human user
6. `HEARTBEAT.md` — heartbeat polling instructions
7. `BOOTSTRAP.md` — first-run instructions
8. `MEMORY.md` (preferred) or `memory.md` (fallback) — long-term memory

### Memory Key Mapping

When stored in database backends (non-file), each file maps to a memory key:

| File          | Memory Key                             |
|---------------|----------------------------------------|
| `AGENTS.md`   | `__bootstrap.prompt.AGENTS.md`        |
| `SOUL.md`     | `__bootstrap.prompt.SOUL.md`          |
| `TOOLS.md`    | `__bootstrap.prompt.TOOLS.md`         |
| `IDENTITY.md` | `__bootstrap.prompt.IDENTITY.md`      |
| `USER.md`     | `__bootstrap.prompt.USER.md`          |
| `HEARTBEAT.md`| `__bootstrap.prompt.HEARTBEAT.md`     |
| `BOOTSTRAP.md`| `__bootstrap.prompt.BOOTSTRAP.md`     |
| `MEMORY.md`   | `__bootstrap.prompt.MEMORY.md`        |

### Size Limits

| Constant                       | Value    | Description                           |
|--------------------------------|----------|---------------------------------------|
| `BOOTSTRAP_MAX_CHARS`          | `20000`  | Max chars from a single file          |
| `BOOTSTRAP_TOTAL_MAX_CHARS`    | `24000`  | Max total chars from all files combined |
| `MAX_WORKSPACE_BOOTSTRAP_FILE_BYTES` | `2 MB` | Hard limit on file size for reading |

When a single file exceeds `BOOTSTRAP_MAX_CHARS`, its content is truncated
with a marker. The provider reads `BOOTSTRAP_MAX_CHARS + 1` bytes to
distinguish "exactly at cap" from "truncated beyond cap".

When the cumulative total across all files exceeds `BOOTSTRAP_TOTAL_MAX_CHARS`,
remaining files are skipped and a truncation notice is appended:
```
[... project context truncated at 24000 chars total -- use `read` for full files]
```

## System Prompt Assembly

### Identity Section

The identity section is injected at the beginning of the system prompt with
preamble guidance:

1. **Preamble**: Explains that workspace files define identity, behavior, and context.
2. **AGENTS.md guidance**: "If present, follow its operational guidance including startup
   routines and red-line constraints unless higher-priority instructions override it."
3. **SOUL.md guidance**: "If present, embody its persona and tone. Avoid stiff, generic
   replies; follow its guidance unless higher-priority instructions override it."
4. **TOOLS.md guidance**: "Does not control tool availability; it is user guidance
   for how to use external tools."
5. **File injection**: Each file is injected in order with a markdown header and
   its file path.

### Full Prompt Sections (in order)

1. **Project Context** — workspace identity files (AGENTS, SOUL, TOOLS, etc.)
2. **Tools** — registered tool definitions with parameter schemas
3. **Channel Attachments** — file/image/video/audio marker conventions
4. **Channel Choices** — inline button/choice conventions for supported channels
5. **Conversation Context** — channel-specific metadata (sender, group, etc.)
6. **Capabilities** — optional capabilities section
7. **Safety** — hardcoded safety rules:
   - Do not exfiltrate private data
   - Do not run destructive commands without asking
   - Do not bypass oversight or approval mechanisms
   - Prefer `trash` over `rm`
   - When in doubt, ask before acting externally
   - Never expose internal memory implementation keys in user-facing replies
8. **Group Chat Behavior** — `[NO_REPLY]` marker usage (Telegram groups)
9. **Scheduled Tasks** — schedule tool guidance
10. **Skills** — progressive skill loading (always/on-demand)
11. **Workspace** — working directory path
12. **DateTime** — current date and time
13. **Runtime** — OS and model name

## File Security Guards

When loading workspace files, the following safety checks apply:

### Filename Validation
- Must NOT be an absolute path
- Must NOT contain null bytes
- Must NOT contain `..` path components (traversal blocked)

### Path Traversal Protection
- The file's canonical (realpath-resolved) path must start with the workspace
  root's canonical path
- Symlinks pointing outside the workspace are blocked — the file is treated
  as not found and `[File not found: <filename>]` is injected
- The canonical path comparison uses actual filesystem resolution, not string
  manipulation

### Size Guard
- Files larger than 2 MB are silently skipped (treated as not found)

## Fingerprinting

The system detects workspace file changes to trigger system prompt rebuild.

### File-Based Fingerprinting (default fallback)
Uses FNV-1a 64-bit hash over the tracked files:

For each file in the tracked list:
1. Hash the filename and newline separator
2. If file doesn't exist: hash `"missing"`
3. If file exists: hash `"present"` + canonical path + device ID + inode +
   mtime (nanoseconds) + size (bytes)

Tracked files for fingerprinting: `AGENTS.md`, `SOUL.md`, `TOOLS.md`,
`IDENTITY.md`, `USER.md`, `HEARTBEAT.md`, `BOOTSTRAP.md`, `MEMORY.md`,
`memory.md` (note: both MEMORY.md and memory.md are tracked).

### Bootstrap Provider Fingerprinting
When a bootstrap provider is available, fingerprinting is delegated to it
(the provider may use database checksums instead of file stats).

## Bootstrap Provider Interface

Abstracts where workspace identity files are stored. Three implementations:

### Interface Operations

| Operation      | Signature                                    | Description                    |
|----------------|----------------------------------------------|--------------------------------|
| `load`         | (filename) → content or null                 | Load full file content         |
| `load_excerpt` | (filename, max_bytes) → content or null      | Load first N bytes             |
| `store`        | (filename, content) → void                   | Write/overwrite file           |
| `remove`       | (filename) → bool (was removed)              | Delete file                    |
| `exists`       | (filename) → bool                            | Check file existence           |
| `list`         | () → list of filenames                       | List all stored files          |
| `fingerprint`  | () → u64 hash                                | Compute change fingerprint     |

### File Bootstrap Provider
Used when `memory.backend` is `hybrid` or `markdown`.
Reads and writes files directly in the workspace directory.
Requires `workspace_dir` at construction time.

### Memory Bootstrap Provider
Used for database backends (`sqlite`, `postgres`, `redis`, etc.).
Stores bootstrap documents as memory entries using the `__bootstrap.prompt.*`
key convention. Requires a memory backend instance.

### Null Bootstrap Provider
Used when `memory.backend` is `none` or `memory`.
All operations are no-ops: `load` returns null, `store`/`remove` are no-ops.

### Factory Selection

| Memory Backend     | Provider Selected     | Requires         |
|--------------------|-----------------------|-------------------|
| `hybrid`           | FileBootstrapProvider | workspace_dir    |
| `markdown`         | FileBootstrapProvider | workspace_dir    |
| `none`             | NullBootstrapProvider | (nothing)        |
| `memory`           | NullBootstrapProvider | (nothing)        |
| All others         | MemoryBootstrapProvider| memory instance |

## AIEOS Identity Format (v1.1)

An alternative structured identity specification. Activated when
`identity.format = "aieos"` and either `identity.aieos_path` or
`identity.aieos_inline` is set.

### Schema

```json
{
  "identity": {
    "names": {
      "first": "string?",
      "last": "string?",
      "nickname": "string?",
      "full": "string?"
    },
    "bio": "string?",
    "origin": "string?",
    "residence": "string?"
  },
  "psychology": {
    "mbti": "string?",
    "ocean": {
      "openness": "float?",
      "conscientiousness": "float?",
      "extraversion": "float?",
      "agreeableness": "float?",
      "neuroticism": "float?"
    },
    "moral_compass": ["string"]
  },
  "linguistics": {
    "style": "string?",
    "formality": "string?",
    "catchphrases": ["string"],
    "forbidden_words": ["string"]
  },
  "motivations": {
    "core_drive": "string?",
    "short_term_goals": ["string"],
    "long_term_goals": ["string"],
    "fears": ["string"]
  },
  "capabilities": {
    "skills": ["string"],
    "tools": ["string"]
  },
  "physicality": {
    "appearance": "string?",
    "avatar_description": "string?"
  },
  "history": {
    "origin_story": "string?",
    "education": ["string"],
    "occupation": "string?"
  },
  "interests": {
    "hobbies": ["string"],
    "lifestyle": "string?"
  }
}
```

All sections and all fields within sections are optional.

### AIEOS to System Prompt Conversion

Each present section is rendered as a markdown `##` section:

| AIEOS Section  | Prompt Header           | Key fields rendered                  |
|----------------|-------------------------|--------------------------------------|
| `identity`     | `## Identity`           | Name, full name, nickname, bio, origin, residence |
| `psychology`   | `## Personality`        | MBTI, OCEAN traits, moral compass    |
| `linguistics`  | `## Communication Style`| Style, formality, catchphrases, forbidden words |
| `motivations`  | `## Motivations`        | Core drive, goals (short/long), fears|
| `capabilities` | `## Capabilities`       | Skills list, tools list              |
| `history`      | `## Background`         | Origin story, education, occupation  |
| `physicality`  | `## Appearance`         | Appearance, avatar description       |
| `interests`    | `## Interests`          | Hobbies, lifestyle                   |

Name resolution order:
1. If `first` is set, use it as the name
2. If `first` and `last` are both set, also show "Full Name: first last"
3. If only `full` is set, use it as the name
4. If `nickname` is set, always show it

OCEAN traits are rendered as decimal values with 2 decimal places.

The final prompt is trimmed of trailing whitespace. An empty identity
(no sections set) produces an empty string.

### AIEOS Detection

AIEOS is considered configured when:
- `identity.format == "aieos"` (case-sensitive, lowercase only)
- AND (`identity.aieos_path != null` OR `identity.aieos_inline != null`)

## Integration Points

- **Agent core** (`buildSystemPrompt`): calls identity section builder during
  each turn's system prompt construction.
- **Session management**: uses fingerprint to detect when prompt needs rebuild.
- **Memory system**: provides bootstrap provider factory and memory key mapping.
- **Workspace edit CLI**: allows editing bootstrap files via `workspace edit`.
- **Skills system**: skills section is appended after identity in the prompt.

## Constraints

- Workspace file injection is a read-only operation from the agent's perspective
  during prompt build; writes happen through the bootstrap provider or file tools.
- Symlink escape prevention is critical — files pointing outside workspace MUST
  be blocked to prevent prompt injection attacks.
- The 24 KB total bootstrap limit prevents context window exhaustion from
  oversized workspace files.
