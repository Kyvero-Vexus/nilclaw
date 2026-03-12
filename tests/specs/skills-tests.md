---
Layer: L2
Lane: integration
Spec ID: L2-INT-skills-tests
Status: draft
Last Updated: 2026-03-10
Traceability:
  L1: [L1-EXT-skills-system, L1-OPS-baseline-operations]
  L0: [F-CAP-SKILLS, C-CONFIG-EXPLICITNESS]
---

# Skills Test Specifications

## Overview
The skills module manages the lifecycle of extensible skill packages: parsing manifests (JSON, TOML, markdown-only), loading skill directories, listing/discovering skills, installing from paths or Git repositories, removing skills, auditing for security, and managing community skill synchronization.

---

## Manifest Parsing (JSON)

### Full JSON manifest
- **Input**: `{"name": "code-review", "version": "1.2.0", "description": "Automated code review", "author": "nilclaw"}`
- **Expected**: All fields populated correctly

### Minimal JSON (name only)
- **Input**: `{"name": "minimal-skill"}`
- **Expected**: name="minimal-skill", version defaults to "0.0.1", description and author default to ""

### Missing name → MissingField error
### Empty JSON object → MissingField error

### Handles whitespace in JSON
- Pretty-printed JSON with indentation → parsed correctly

### Handles escaped quotes
- Description containing `\"hello\"` → preserved in output

### Reads "always" field
- `{"name": "x", "always": true}` → always=true
- Default: always=false

### parseManifestAlloc reads requires_bins
- `{"name": "x", "requires_bins": ["ffmpeg", "convert"]}` → parsed array

### parseManifestAlloc reads requires_env
- `{"name": "x", "requires_env": ["API_KEY"]}` → parsed array

---

## Field Parsing Utilities

### parseStringField
- Key present with string value → returns value
- Key missing → null
- Key present with non-string value (number) → null

### parseIntField
- Key present with integer value → returns value
- Key missing → null
- Non-numeric value → null

### parseBoolField
- "true" → true, "false" → false, missing → null

### parseStringArray
- Array with elements → parsed list
- Empty array → empty list
- Missing key → null
- Single element → list of 1

---

## Skill Struct

### Defaults
- version="0.0.1", description="", author="", instructions="", enabled=true

### Custom values
- All fields accept custom values including enabled=false

### Progressive loading defaults
- available defaults based on requirements check status

---

## Skill Loading

### Reads manifest and instructions
- **Setup**: Directory with skill.json + SKILL.md
- **Expected**: All fields from manifest + instructions from SKILL.md

### Without SKILL.md still works
- **Setup**: Directory with only skill.json
- **Expected**: Manifest parsed, instructions=""

### Without skill.json falls back to markdown-only
- **Setup**: Directory with only SKILL.md
- **Expected**: name=directory name, version="0.0.1", instructions=file contents, available=true

### Reads metadata from SKILL.toml
- **Setup**: Directory with SKILL.toml containing [skill] section
- **Expected**: name, version, description, author from TOML

### Prefers SKILL.toml over skill.json when both exist
- **Setup**: Both SKILL.toml and skill.json present
- **Expected**: TOML metadata takes precedence

### Missing manifest → ManifestNotFound error
- **Setup**: Empty directory without any manifest files

### Reads always field
- **Setup**: skill.json with `"always": true`
- **Expected**: always=true on loaded skill

---

## Skill Discovery (listSkills)

### Nonexistent directory → empty list
### Empty directory → empty list

### Discovers subdirectories with manifests
- **Setup**: Two skill subdirectories + a regular file
- **Expected**: 2 skills found, regular file skipped

### Discovers markdown-only skill directories
- **Setup**: Directory with only SKILL.md
- **Expected**: 1 skill found

### Skips directories without valid manifest
- **Setup**: One valid skill + one empty directory
- **Expected**: Only valid skill listed

---

## listSkillsMerged

### Workspace overrides builtin
- When same skill name exists in workspace and builtin, workspace version takes priority

### Nonexistent dirs → empty list

### Runs checkRequirements on loaded skills
- Skills with met/unmet requirements get correct available status

---

## Requirements Checking

### No requirements → available
### Missing env var → unavailable with reason
### Missing binary → unavailable with reason
### Both missing bin and env → unavailable with combined reasons

### checkBinaryExists
- Common binary (e.g., "sh") → true
- Nonexistent binary → false

---

## Git Source Detection (isGitSource)

### Accepts remote protocols
- `https://`, `http://`, `ssh://`, `git://`, `git@host:` → true

### Rejects local paths and invalid inputs
- `./skills/local`, `/tmp/skills/local`, `C:\\skills\\local` → false
- `git@github.com` (no colon-path), `ssh://`, `not-a-url` → false
- Subdirectory containing git URL → false

---

## Git Clone Error Classification

### Maps common failures
- "repository not found" → GitCloneRepositoryNotFound
- "URL returned error: 404" → GitCloneRepositoryNotFound
- "could not read from remote repository" → GitCloneAuthFailed
- "could not resolve host" → GitCloneNetworkError
- Other → GitCloneFailed

---

## Snapshot and Detection

### snapshotSkillChildren + detectNewlyInstalledDirectory roundtrip
- Snapshot before, add directory, detect → finds the new directory

### detectNewlyInstalledDirectory errors
- No new directory → GitCloneNoNewDirectory error
- Multiple new directories → GitCloneAmbiguousDirectory error

---

## Security Audit (auditSkillDirectory)

### Rejects symlink entries
- Symlink to /etc/passwd in skill directory → SkillSecurityAuditFailed

### Allows large non-script files
- Large .bin file (>audit limit) → allowed (not a script)

### Rejects script suffix files
- .sh files → SkillSecurityAuditFailed

### Rejects shell shebang files
- File starting with `#!/bin/bash` → SkillSecurityAuditFailed

### Rejects markdown links escaping skill root
- `[escape](../outside.md)` → SkillSecurityAuditFailed

### Rejects TOML tool command with shell chaining
- `command = "echo ok && rm -rf /"` → SkillSecurityAuditFailed

### Rejects TOML tool entries without command
- Shell tool missing command field → SkillSecurityAuditFailed

### Rejects TOML shell tool with empty command
- `command = "   "` → SkillSecurityAuditFailed

### Rejects invalid TOML manifest syntax
- Malformed TOML → SkillSecurityAuditFailed

### Rejects TOML prompts with high-risk content
- Prompt containing "curl … | sh" → SkillSecurityAuditFailed

### Rejects multiline TOML prompts with high-risk content
- Same as above but in multiline array format

### Rejects malformed TOML string literals
- Unclosed string → SkillSecurityAuditFailed

### Accepts root with legacy skill.json marker
### Rejects root without any skill markers

---

## Install and Remove

### installSkill and removeSkill roundtrip
- Install from source → skill directory created, loadable
- Remove → directory gone, no longer loadable

### installSkillFromPath copies full source directory
- Source with skill.json + SKILL.md → both files in destination

### installSkillFromPath supports markdown-only source
### installSkillFromPath supports legacy skill.json-only source
### installSkillFromPath supports relative source path
### installSkillFromPath supports SKILL.toml-only source

### installSkillFromPath uses source directory name even when manifest name is unsafe
- Unsafe manifest name → ignored, source dir name used instead

### installSkillFromPath rejects missing manifest
- Source without any marker files → error

### installSkillFromGit from local repository
- Local git repo → cloned and installed

### installSkillFromGit supports root markdown-only repository
### installSkillFromGit installs all skills from repository skills directory
### installSkillFromGit installs SKILL.toml entry from repository skills directory
### installSkillFromGit keeps clone directory name when manifest name differs

### removeSkill nonexistent → SkillNotFound error
### removeSkill rejects unsafe names (path traversal)

---

## Community Skills

### syncCommunitySkills disabled when env not set
### loadCommunitySkills from nonexistent directory → empty
### loadCommunitySkills loads .md files
### mergeCommunitySkills: workspace takes priority over community
### CommunitySkillsSync struct has expected fields
### OPEN_SKILLS_REPO_URL is set (not empty)
### COMMUNITY_SYNC_INTERVAL_DAYS is 7
### syncCommunitySkillsResult disabled when env not set

### SyncResult struct fields
- Has status, message, skills_count fields

### countMdFiles returns zero for nonexistent dir
### countMdFiles counts only .md files (ignores other extensions)
### freeSyncResult frees message
