# Skills System Specification

## Overview

Skills are user-defined capabilities loaded from disk that extend the
agent's behavior through instruction injection into the system prompt.
They support dependency checking, progressive loading (always vs on-demand),
and multiple manifest formats (TOML preferred, JSON legacy).

## Skill Directory Structure

```
<workspace>/skills/<skill-name>/
  ├── SKILL.toml       # Preferred manifest format
  ├── skill.json       # Legacy manifest (fallback)
  └── SKILL.md         # Instruction text
```

Base path: `<config_dir>/workspace/skills/` (or custom workspace path).

## Skill Definition

| Field          | Type     | Default  | Description                          |
|----------------|----------|----------|--------------------------------------|
| `name`         | string   | —        | Skill identifier (directory name)    |
| `version`      | string   | `"0.0.1"`| Semver version                       |
| `description`  | string   | `""`     | Human-readable description           |
| `author`       | string   | `""`     | Author name                          |
| `instructions` | string   | `""`     | Loaded from SKILL.md                 |
| `enabled`      | bool     | `true`   | Whether skill is active              |
| `always`       | bool     | `false`  | Always include in system prompt      |
| `requires_bins`| string[] | `[]`     | Required CLI binaries (e.g., "docker")|
| `requires_env` | string[] | `[]`     | Required env vars (e.g., "OPENAI_API_KEY")|
| `available`    | bool     | `true`   | All requirements satisfied           |
| `missing_deps` | string   | `""`     | Description of missing dependencies  |
| `path`         | string   | `""`     | Skill directory path on disk         |

## Manifest Formats

### TOML (Preferred)

```toml
name = "my-skill"
version = "1.0.0"
description = "Does something useful"
author = "User"
always = false
requires_bins = ["git", "docker"]
requires_env = ["API_KEY"]
```

### JSON (Legacy)

```json
{
  "name": "my-skill",
  "version": "1.0.0",
  "description": "Does something useful",
  "author": "User",
  "always": false,
  "requires_bins": ["git"],
  "requires_env": ["API_KEY"]
}
```

### Manifest Resolution Order

1. `SKILL.toml` — if present, use TOML manifest
2. `skill.json` — fallback to JSON manifest
3. Neither — skip skill (log warning)

## Loading Process

### Discovery

1. Scan `<workspace>/skills/` for directories
2. For each directory with a valid manifest:
   a. Parse manifest (TOML or JSON)
   b. Load `SKILL.md` as instructions (if exists)
   c. Check requirements
   d. Build Skill struct

### Requirement Checking

For each required binary (`requires_bins`):
- Check if binary exists in PATH (platform-specific lookup)
- On failure: mark `available = false`, populate `missing_deps`

For each required env var (`requires_env`):
- Check if environment variable is set and non-empty
- On failure: mark `available = false`, populate `missing_deps`

A skill with `available = false` is still loaded but its instructions
are not injected into the system prompt.

## System Prompt Injection

### Progressive Loading

Skills use two injection modes:

**Always mode** (`always = true`):
- Full instruction text included in the system prompt
- Consumes context window tokens every turn

**On-demand mode** (`always = false`, default):
- Only an XML summary is included:
  ```xml
  <skill name="skill-name" path="skills/skill-name/SKILL.md">
    Description text
  </skill>
  ```
- Agent must use `read_file` tool to load full instructions when needed

### Injection Order

Skills are injected after workspace identity files and before runtime sections:
1. Always-on skills: full instructions
2. On-demand skills: XML summaries

### Reload

`reloadSkillsAll()` on the session manager invalidates `has_system_prompt`
on all active sessions, causing skills to be re-discovered and re-loaded
on the next turn.

## Skill Installation

Skills can be installed from:
1. Local directory copy to `<workspace>/skills/<name>/`
2. Git clone (repository URL)
3. Archive extraction (tar/zip)

Installation validates manifest presence and required fields.

## Skill Removal

Removes the skill directory from `<workspace>/skills/<name>/`.
Triggers skills reload on active sessions.

## Integration Points

- **Agent prompt**: skills section injected during system prompt build
- **Session management**: `reloadSkillsAll()` forces prompt rebuild
- **Workspace**: skills stored in workspace directory
- **File tools**: on-demand skills loaded via `file_read`
- **CLI**: `workspace edit` can modify skill files
