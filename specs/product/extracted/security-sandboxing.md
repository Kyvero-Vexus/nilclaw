# Security & Sandboxing Specification

## Overview

The security system enforces least-privilege execution through layered
controls: autonomy-based policy, command risk classification, sandbox
isolation, secret encryption, pairing authentication, audit logging,
and rate limiting.

## Autonomy Levels

| Level        | Shell Access | Risk Gate                          | Security Bypass |
|--------------|-------------|-------------------------------------|-----------------|
| `read_only`  | Denied      | All commands blocked               | None            |
| `supervised` | Allowlisted | Medium: approval required. High: blocked | None        |
| `full`       | All allowed | High: still blocked by default     | Allowlist bypass|
| `yolo`       | All allowed | All security checks bypassed       | Complete        |

Default: `supervised`

## Command Security Policy

### SecurityPolicy Structure

| Field                              | Type    | Default            | Description                     |
|------------------------------------|---------|--------------------|---------------------------------|
| `autonomy`                         | enum    | `supervised`       | Autonomy level                  |
| `workspace_dir`                    | string  | `"."`              | Workspace directory             |
| `workspace_only`                   | bool    | `true`             | Restrict to workspace           |
| `allowed_commands`                 | list    | conservative list  | Command allowlist               |
| `max_actions_per_hour`             | u32     | `20`               | Rate limit                      |
| `require_approval_for_medium_risk` | bool    | `true`             | Approval for medium-risk        |
| `block_high_risk_commands`         | bool    | `true`             | Block high-risk commands        |
| `allow_raw_url_chars`              | bool    | `false`            | Skip single-`&` check          |

### Default Allowed Commands (supervised)

`git`, `npm`, `cargo`, `ls`, `cat`, `grep`, `find`, `echo`, `pwd`, `wc`,
`head`, `tail`

### Full Autonomy Default

`["*"]` (wildcard — all commands allowed)

### Command Allowlist Resolution

1. If explicit config provided → use it
2. If `full` autonomy + empty list → `["*"]`
3. Otherwise → conservative default list

### Risk Classification

#### High-Risk Commands (Always)

`rm`, `mkfs`, `dd`, `shutdown`, `reboot`, `halt`, `poweroff`, `sudo`, `su`,
`chown`, `chmod`, `useradd`, `userdel`, `usermod`, `passwd`, `mount`,
`umount`, `iptables`, `ufw`, `firewall-cmd`, `curl`, `wget`, `nc`, `ncat`,
`netcat`, `scp`, `ssh`, `ftp`, `telnet`

#### High-Risk Patterns

- `rm -rf /` or `rm -fr /` (recursive root delete)
- `:(){:|:&};:` (fork bomb)
- Commands exceeding max analysis length

#### Medium-Risk Detection

Commands that modify system state but are not in the high-risk list
(e.g., package managers with install arguments, service management).

#### Safe Exception: Bootstrap Delete

Deleting only `BOOTSTRAP.md` via `rm` or `trash` is classified as low-risk
(lifecycle cleanup for onboarding flow).

### Command Analysis

Commands are analyzed by:
1. Normalizing separators (`;`, `&&`, `||`, `|`) to split segments
2. Skipping environment variable assignments (`KEY=val cmd`)
3. Extracting basename from full paths (`/usr/bin/rm` → `rm`)
4. Case-insensitive matching against risk lists

### Blocked Shell Operators

These operators are always blocked (regardless of autonomy):
- Backtick substitution (`` ` ``)
- `$(` command substitution
- `${` variable expansion
- `<(` and `>(` process substitution
- `%VAR%` on Windows

### Validation Flow

```
validateCommandExecution(command, approved)
  → yolo: return low
  → !isCommandAllowed: error CommandNotAllowed
  → classify risk:
    high + block_high_risk: error HighRiskBlocked
    high + supervised + !approved: error ApprovalRequired
    medium + supervised + require_approval + !approved: error ApprovalRequired
    → return risk level
```

## Sandbox Isolation

### Sandbox Interface

| Method         | Signature                            | Description              |
|----------------|--------------------------------------|--------------------------|
| `wrapCommand`  | (argv, buf) → modified argv         | Wrap command with sandbox|
| `isAvailable`  | () → bool                            | Backend availability     |
| `name`         | () → string                          | Backend name             |
| `description`  | () → string                          | Backend description      |

### Sandbox Backends

| Backend     | Platform | Detection              | Isolation Level          |
|-------------|----------|------------------------|--------------------------|
| Landlock    | Linux    | Kernel feature probe    | Filesystem access control|
| Firejail    | Linux    | Binary exists in PATH   | Process + filesystem     |
| Bubblewrap  | Linux    | Binary exists in PATH   | Namespace isolation      |
| Docker      | Any      | Docker daemon available | Full container isolation |
| None (Noop) | Any      | Always available        | No additional isolation  |

### Auto-Detection Priority

**Linux**: Landlock → Firejail → Bubblewrap → Docker → Noop

**macOS**: Docker → Noop

If explicitly requested backend is unavailable, falls back to Noop.

## Secret Encryption

### Algorithm: ChaCha20-Poly1305

- Key length: 32 bytes (256-bit)
- Nonce length: 12 bytes
- Tag length: 16 bytes (128-bit authentication)

### Encrypted Value Format

Encrypted values use `enc2:` prefix with hex-encoded nonce:ciphertext:tag.

### Key Management

- Random 256-bit encryption key generated at first run
- Key stored in config directory
- Credentials encrypted at rest in config file

### Operations

| Operation | Input             | Output               |
|-----------|-------------------|-----------------------|
| `encrypt` | key, nonce, data  | ciphertext + tag     |
| `decrypt` | key, nonce, data  | plaintext            |

### HMAC-SHA256

Used for webhook signature verification (e.g., WhatsApp webhook).

## Pairing System

### PairingGuard

Manages gateway authentication state.

| Field                | Type              | Description                      |
|----------------------|-------------------|----------------------------------|
| `require_pairing_flag`| bool             | Whether pairing is required      |
| `pairing_code`       | [6]u8?            | One-time 6-digit code            |
| `paired_tokens`      | hash map          | SHA-256 hashes of bearer tokens  |
| `failed_count`       | u32               | Consecutive failed attempts      |
| `lockout_time`       | timestamp?        | Lockout expiration               |

### Pairing Flow

1. System generates random 6-digit numeric pairing code on startup
2. Code is displayed to operator (logged or shown in terminal)
3. Client sends `POST /pair` with `X-Pairing-Code` header
4. On match: generate random bearer token, return to client, store hash
5. All subsequent API calls require `Authorization: Bearer <token>`

### Security Controls

- **Max attempts**: 5 failed attempts before lockout
- **Lockout duration**: 5 minutes (300 seconds)
- **Token storage**: SHA-256 hash only (plaintext never stored)
- **Code consumed**: pairing code nullified after successful pair

### Pair Attempt Results

| Result          | Condition                           |
|-----------------|-------------------------------------|
| `paired`        | Code matches, token generated       |
| `missing_code`  | No code provided                    |
| `invalid_code`  | Code doesn't match                  |
| `already_paired`| Code already consumed               |
| `disabled`      | Pairing not required                |
| `locked_out`    | Too many failed attempts            |
| `internal_error`| Token generation failure            |

### Token Validation

Bearer tokens are validated by:
1. Extract token from `Authorization: Bearer <token>` header
2. Hash token with SHA-256
3. Check if hash exists in paired_tokens map

Pre-configured tokens in `gateway.paired_tokens` are stored as hashes
(detected by length = 64 hex chars) or hashed on load.

## Audit Logging

### Configuration

| Field            | Type   | Default       | Description              |
|------------------|--------|---------------|--------------------------|
| `enabled`        | bool   | `true`        | Enable audit logging     |
| `log_file`       | string?| null          | Custom log file path     |
| `log_path`       | string | `"audit.log"` | Default log path         |
| `retention_days` | u32    | `90`          | Log retention period     |
| `max_size_mb`    | u32    | `100`         | Max log file size        |
| `sign_events`    | bool   | `false`       | Cryptographic signatures |

### Audit Events

Events are recorded as structured log entries with timestamp, event type,
and relevant metadata. Event types include:
- Tool executions (tool name, success/failure)
- Authentication events (pair attempts, token validation)
- Configuration changes
- Security policy violations

## Rate Limiting

### RateTracker

Sliding window rate limiter for action counting:
- Tracks action timestamps in a circular buffer
- Counts actions within the configured window
- Used for `max_actions_per_hour` enforcement

### Gateway Rate Limits

| Endpoint | Config Field                     | Default |
|----------|----------------------------------|---------|
| `/pair`  | `pair_rate_limit_per_minute`     | 10      |
| `/webhook`| `webhook_rate_limit_per_minute` | 60      |

### Idempotency

Gateway supports idempotency keys:
- TTL: `idempotency_ttl_secs` (default 300 = 5 minutes)
- Duplicate requests within TTL return cached response

## Path Security

File tools enforce path restrictions:
1. Resolve symlinks via realpath
2. Check resolved path starts with workspace_dir
3. Check resolved path starts with any allowed_path entry
4. System-critical paths always blocked regardless of allowlist

## Integration Points

- **Shell tool**: checks `SecurityPolicy.validateCommandExecution()` before exec
- **File tools**: check path security before read/write/edit
- **Gateway**: uses PairingGuard for authentication
- **Audit**: observer records security events
- **Config**: `autonomy.*` and `security.*` configure all behavior
