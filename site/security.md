---
layout: default
title: Security
nav_order: 9
---

# Security

NilClaw implements a comprehensive security model for safe agent execution.

## Overview

The security system provides:

- **Policy-based access control**
- **Tool allowlisting/denylisting**
- **Sandboxed execution**
- **Permission checking**

## Security Policy

### Policy Types

| Policy | Description |
|--------|-------------|
| `permissive` | Allow all unless explicitly denied |
| `strict` | Deny all unless explicitly allowed |

### Creating a Policy

```lisp
;; Permissive policy (default)
(defparameter *policy*
  (nilclaw/security:make-security-policy
    :mode :permissive
    :denylist '("rm" "sudo" "format")))

;; Strict policy
(defparameter *strict-policy*
  (nilclaw/security:make-security-policy
    :mode :strict
    :allowlist '("read" "write" "exec" "ls")))
```

### Policy Fields

| Field | Type | Description |
|-------|------|-------------|
| `mode` | keyword | `:permissive` or `:strict` |
| `allowlist` | list | Allowed tools (strict mode) |
| `denylist` | list | Denied tools (permissive mode) |

## Permission Checking

### Check Tool Permission

```lisp
;; Permissive mode: denied if in denylist
(nilclaw/security:check-tool-permission *policy* "rm")
;; => nil

(nilclaw/security:check-tool-permission *policy* "read")
;; => t

;; Strict mode: allowed only if in allowlist
(nilclaw/security:check-tool-permission *strict-policy* "read")
;; => t

(nilclaw/security:check-tool-permission *strict-policy* "delete")
;; => nil
```

### Check Command Permission

```lisp
(nilclaw/security:check-command-permission *policy* "ls" "-la")
;; => t

(nilclaw/security:check-command-permission *policy* "rm" "-rf" "/")
;; => nil
```

## Sandboxed Execution

### Execute with Restrictions

```lisp
;; Execute a command with security policy
(nilclaw/security:with-security-policy (*policy*)
  (nilclaw/dispatcher:execute-tool *registry* tool-call))
```

### Command Filtering

```lisp
;; Filter dangerous commands
(nilclaw/security:filter-command *policy* "rm -rf /home")
;; => nil (blocked)

(nilclaw/security:filter-command *policy* "ls -la /home")
;; => "ls -la /home" (allowed)
```

## File System Security

### Path Restrictions

```lisp
;; Restrict to specific directories
(defparameter *fs-policy*
  (nilclaw/security:make-filesystem-policy
    :allow-paths '("/home/user/workspace" "/tmp")
    :deny-paths '("/etc" "/root")))

(nilclaw/security:check-path-permission *fs-policy* "/home/user/workspace/file.txt")
;; => t

(nilclaw/security:check-path-permission *fs-policy* "/etc/passwd")
;; => nil
```

## Network Security

### Domain Allowlisting

```lisp
(defparameter *net-policy*
  (nilclaw/security:make-network-policy
    :allow-domains '("api.openai.com" "api.anthropic.com")
    :deny-domains '()))

(nilclaw/security:check-domain-permission *net-policy* "api.openai.com")
;; => t

(nilclaw/security:check-domain-permission *net-policy* "malicious.com")
;; => nil
```

## Security Commands

### Query Current Policy

```lisp
(nilclaw/security:get-current-policy)
;; => #<SECURITY-POLICY ...>
```

### Update Policy

```lisp
;; Add to denylist
(nilclaw/security:policy-add-deny *policy* "format")

;; Add to allowlist
(nilclaw/security:policy-add-allow *strict-policy* "mkdir")
```

## Error Handling

### Security Violations

```lisp
(handler-case
    (nilclaw/security:enforce-permission *policy* "rm")
  (nilclaw/security:security-violation (e)
    (format t "Blocked: ~A~%" e)))
```

## Configuration

Security policy is configured in `config.json`:

```json
{
  "security": {
    "policy": "strict",
    "allowlist": ["read", "write", "exec", "ls", "mkdir"],
    "denylist": ["rm", "sudo", "format"]
  }
}
```

## Best Practices

1. **Use strict mode in production**
2. **Minimize allowlist to essential tools**
3. **Deny destructive operations** (`rm -rf`, `format`, `dd`)
4. **Restrict file system access** to workspace directories
5. **Limit network domains** to required APIs
6. **Log all security decisions** for audit

## Security Checklist

- [ ] Policy mode configured
- [ ] Allowlist/denylist populated
- [ ] File system paths restricted
- [ ] Network domains allowlisted
- [ ] Commands filtered
- [ ] Audit logging enabled
