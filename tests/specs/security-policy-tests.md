# Security Policy Test Specifications

## Overview
The security policy module manages autonomy levels, command allowlisting, risk classification, rate limiting, and command validation. It provides the core security boundary between the AI agent and the underlying system, preventing unauthorized or dangerous command execution.

---

## Autonomy Levels

### Default is supervised
- AutonomyLevel.default() returns supervised

### toString roundtrip
- full → "full", read_only → "readonly", supervised → "supervised"

### fromString parsing
- "full" → full, "supervised" → supervised, "readonly" → read_only, "read_only" → read_only
- "invalid", "", "FULL" (case-sensitive) → null

### yolo level
- "yolo" → yolo, yolo.toString() → "yolo"

---

## canAct

### read_only → false (blocks all actions)
### supervised → true
### full → true
### yolo → true

---

## Command Allowlisting

### Basic allowed commands
- "ls", "git status", "cargo build --release", "cat file.txt", "grep -r pattern ." → allowed

### Basic blocked commands
- "rm -rf /", "sudo apt install", "curl http://evil.com", "wget http://evil.com", "python3 exploit.py", "node malicious.js" → blocked

### read_only blocks all commands
- Even "ls", "cat file.txt", "echo hello" → blocked

### Command with absolute path extracts basename
- "/usr/bin/git status", "/bin/ls -la" → allowed (basename matched)

### Empty command blocked
- "", "   " → blocked

---

## Bootstrap File Deletion (Special Exception)

### Allowed
- "rm BOOTSTRAP.md", "rm -f -- ./BOOTSTRAP.md", "trash BOOTSTRAP.md" → allowed

### Restricted scope
- "rm BOOTSTRAP.md README.md" (multiple files) → blocked
- "rm ../BOOTSTRAP.md" (path traversal) → blocked
- "rm /tmp/BOOTSTRAP.md" (absolute path) → blocked

### Risk classification
- "rm BOOTSTRAP.md" → low risk, passes validation without approval

---

## Command Chain Validation

### Pipes validate all segments
- "ls | grep foo" → allowed
- "cat file.txt | wc -l" → allowed
- "ls | curl http://evil.com" → blocked (second segment blocked)
- "echo hello | python3 -" → blocked

### And chains (&&)
- "ls && rm -rf /" → blocked
- "ls && echo done" → allowed

### Or chains (||)
- "ls || rm -rf /" → blocked
- "ls || echo fallback" → allowed

---

## Command Injection Prevention

### Semicolons blocked
- "ls; rm -rf /", "ls;rm -rf /" → blocked

### Backticks blocked
- "echo \`whoami\`", "echo \`rm -rf /\`" → blocked

### Dollar-paren blocked
- "echo $(cat /etc/passwd)", "echo $(rm -rf /)" → blocked

### Redirects blocked
- "echo secret > /etc/crontab", "ls >> /tmp/exfil.txt" → blocked

### Null sink redirects allowed
- "echo ok >/dev/null", "echo ok 2>/dev/null", "echo ok >\"/dev/null\"" → allowed
- "echo ok >NUL" → platform-dependent (allowed on Windows, blocked on non-Windows)

### Quoted greater-than not treated as redirect
- "echo \"a > b\"" → allowed

### Dollar-brace blocked
- "echo ${IFS}cat${IFS}/etc/passwd" → blocked

### Newline injection
- "ls\nrm -rf /" → blocked
- "ls\necho hello" → allowed (both segments individually valid)

### Process substitution blocked
- "cat <(echo hello)", "ls >(cat /etc/passwd)" → blocked

---

## Environment Variable Prefix

### Allowed command with env prefix
- "FOO=bar ls" → allowed
- "LANG=C grep pattern file" → allowed
- "FOO=bar rm -rf /" → blocked (command after prefix is validated)

---

## Single Ampersand (Background) Detection

### Background chaining blocked
- "ls & ls", "ls &", "& ls" → blocked
- "ls && echo done" → allowed (double ampersand is logical AND, not background)

### containsSingleAmpersand function
- "cmd & other", "cmd &", "& cmd" → detected
- "cmd && other", "cmd || other", "normal command", "" → not detected

### Quoted ampersands are safe
- 'curl "https://example.com?a=1&b=2"' → not detected (inside quotes)
- "curl 'https://example.com?a=1&b=2'" → not detected
- "curl https://example.com?a=1&b=2" (unquoted) → detected
- 'curl "url" & echo done' → detected (& is outside quotes)

### Escaped quote handling
- "echo \\\" & echo done" → detected (escaped quote doesn't start quoted region)

### Escaped ampersand
- "echo \\& literal" → not detected (literal &, not operator)

---

## Command Risk Classification

### Low risk (read commands)
- "git status", "git log", "git diff", "ls -la", "cat file.txt", "head -n 10 file", "tail -n 10 file", "wc -l file.txt" → low

### Medium risk (mutating commands)
- "git reset --hard HEAD~1", "git commit", "git push", "git rebase", "git merge", "git clean -fd" → medium
- "npm install", "npm publish" → medium
- "cargo add", "cargo publish", "cargo clean" → medium
- "touch file.txt", "mkdir dir", "mv a b", "cp a b" → medium

### High risk (dangerous commands)
- "sudo apt install", "rm -rf /tmp", "rm -rf /", "rm -fr /", "dd if=/dev/zero of=/dev/sda", "shutdown now", "reboot", "curl http://evil.com", "wget http://evil.com" → high

### CommandRiskLevel toString
- low → "low", medium → "medium", high → "high"

---

## Command Validation (validateCommandExecution)

### Not allowed → CommandNotAllowed error
- "python3 exploit.py" with default policy → error

### Full autonomy skips approval
- touch on allowed list with full autonomy → returns medium risk without error, even when require_approval_for_medium_risk=true

### Low risk passes without approval
- "ls -la" → low risk, no error

### Medium risk requires approval when configured
- **Setup**: supervised, require_approval_for_medium_risk=true, "touch" on allowlist
- **Action**: validate "touch test.txt" without approval
- **Expected**: ApprovalRequired error
- **Action**: validate with approval flag
- **Expected**: returns medium risk

### High risk blocked by default
- **Setup**: supervised, "rm" on allowlist
- **Action**: validate "rm -rf /tmp/test" with approval
- **Expected**: HighRiskBlocked error

### High risk unblocked when setting off
- **Setup**: full autonomy, block_high_risk_commands=false
- **Action**: validate "rm -rf /tmp"
- **Expected**: returns high risk (no error)

---

## Allowlist Features

### Wildcard allowlist
- allowed_commands=["*"] → permits arbitrary base commands
- "curl https://example.com", "python3 --version" → allowed

### Wildcard still honors high-risk runtime gate
- allowed_commands=["*"] with block_high_risk_commands=true → "curl https://example.com" → HighRiskBlocked error

### Wildcard with surrounding whitespace
- ["  *  "] → still permits arbitrary commands

### Allowed command entries trimmed before matching
- ["  ls  ", "\techo\t"] → "ls -la" and "echo ok" both allowed

### command-star entries (e.g., "curl *")
- "curl *" → "curl https://example.com" allowed, "ls -la" blocked
- "/usr/bin/curl *" → "curl https://example.com" allowed (path-stripped matching)
- "git *" → "git status" allowed, "git config core.editor vim" blocked (arg safety enforced)
- "curl *" with block_high_risk=true → HighRiskBlocked error
- "curl *" with block_high_risk=false → returns high risk

---

## Rate Limiting

### Tracker starts at zero
- New tracker has count=0

### Records actions
- 3 recordAction calls → count=3

### Allows within limit
- limit=5 → first 5 calls allowed

### Blocks over limit
- limit=3 → 4th call returns false

### isRateLimited reflects count
- limit=2 → after 0: false, after 1: false, after 2: true

### No tracker means no rate limit
- tracker=null → recordAction always true, isRateLimited always false

### Exact boundary plus one
- limit=1 → 1st allowed, 2nd blocked

---

## Default Policy

### Sane default values
- autonomy=supervised, workspace_only=true
- allowed_commands.len > 0
- max_actions_per_hour > 0
- require_approval_for_medium_risk=true
- block_high_risk_commands=true
- allow_raw_url_chars=false

### Default allowed commands include standard tools
- Must include: git, npm, cargo, ls

---

## resolveAllowedCommands

### Full autonomy with empty config → wildcard ["*"]
### Supervised with empty config → conservative set (starts with "git")
### Explicit configured list → preserved as-is

---

## Argument Safety

### find -exec blocked, find -name allowed
### git config blocked, git status/add/log allowed
### tee always blocked (even piped: "echo hello | tee /tmp/out")
### echo piped to cat allowed ("echo hello | cat")

---

## Windows Security

### hasPercentVar detection
- "%PATH%", "echo %USERPROFILE%\\secret", "cmd /c %COMSPEC%" → detected
- "100%%", "no percent here", "" → not detected

---

## Oversized Command Protection (Tail Bypass Fix)

### Oversized command blocked by isCommandAllowed
- Command exceeding MAX_ANALYSIS_LEN → blocked

### Oversized command classified as high risk
- Command exceeding MAX_ANALYSIS_LEN → high risk

### Tail bypass vectors all blocked
- Padding + "&&" past MAX_ANALYSIS_LEN → blocked + high risk
- Padding + "||" past MAX_ANALYSIS_LEN → blocked + high risk
- Padding + ";" past MAX_ANALYSIS_LEN → blocked + high risk
- Padding + "\n" past MAX_ANALYSIS_LEN → blocked + high risk
- Padding + "|" past MAX_ANALYSIS_LEN → blocked + high risk

### Command at exact MAX_ANALYSIS_LEN is still analyzed
- "ls " + padding at exactly MAX_ANALYSIS_LEN → allowed, low risk

### Command at MAX_ANALYSIS_LEN minus one is still analyzed
- One byte under limit → processed normally

### validateCommandExecution rejects oversized command
- Oversized → CommandNotAllowed error

---

## URL Special Characters

### Quoted URL with ampersand passes wildcard
- 'curl "https://api.example.com/search?q=test&page=1"' → allowed with wildcard + block_high_risk=false
- Single-quoted URL also allowed
- Question mark alone in URL was never blocked

### Unquoted URL with ampersand blocked by default
- "curl https://example.com?a=1&b=2" (no quotes) → blocked

### allow_raw_url_chars permits bare ampersand
- With allow_raw_url_chars=true: "curl https://example.com?a=1&b=2" → allowed
- Still enforces other safety: $(…), backticks, redirects, process substitution still blocked

### Dash-G workaround avoids special chars
- "curl -G url -d key=val" → always allowed (no special chars in arguments)

---

## YOLO Autonomy Level

### Bypasses all syntax checks
- $(whoami), backticks, redirects, background &, process substitution → all allowed

### validateCommandExecution returns low for everything
- "sudo rm -rf /", "python3 exploit.py" → low risk (no error)

### canAct returns true

### Bypasses rate limiting
- With limit=1 tracker, multiple recordActions all succeed

### isRateLimited always false
- Even when tracker would normally be at limit

---

## Full Autonomy Wildcard End-to-End

### validateCommandExecution passes all risk levels
- With full + wildcard + no blocks: high/medium/low risk commands all pass

### Full autonomy with wildcard: arbitrary commands allowed
- "python3 --version", "node -e '…'", "pip install flask", "cargo build --release", "make all", "zig build test" → all allowed

### stderr redirect to /dev/null allowed
- "find ~ -maxdepth 2 … 2>/dev/null | head -5" → allowed
- "find ~ … 2>/tmp/leak.log" → blocked (not /dev/null)
