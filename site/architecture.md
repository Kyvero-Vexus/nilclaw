---
layout: default
title: Architecture
nav_order: 3
---

# Architecture

## System Overview

NilClaw is organized as a layered architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────┐
│                      Gateway API                         │
│              (HTTP/WebSocket Protocol)                   │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                    Agent Core                            │
│         (Session management, message routing)            │
└──┬──────────┬──────────┬──────────┬──────────┬──────────┘
   │          │          │          │          │
   ▼          ▼          ▼          ▼          ▼
┌─────┐  ┌─────────┐  ┌─────┐  ┌─────────┐  ┌─────┐
│Tools│  │Channels │  │ MCP │  │Provider │  │ ACP │
│     │  │CLI+Web  │  │     │  │  HTTP   │  │     │
└─────┘  └─────────┘  └─────┘  └─────────┘  └─────┘
   │          │          │          │          │
   ▼          ▼          ▼          ▼          ▼
┌─────────────────────────────────────────────────────────┐
│               Infrastructure Layer                       │
│  Config │ Security │ Memory │ Cron │ Auto-Reply         │
└─────────────────────────────────────────────────────────┘
```

## Module Reference

### Gateway Layer

| Module | Files | Purpose |
|--------|-------|---------|
| `gateway` | `src/gateway/` | HTTP/WebSocket protocol handler, request routing, response formatting |

### Agent Core

| Module | Files | Purpose |
|--------|-------|---------|
| `agent` | `src/agent/` | Session management, message routing, agent identity |

### Capability Layer

| Module | Files | Purpose |
|--------|-------|---------|
| `dispatcher` | `src/dispatcher/` | Tool call parsing (XML, native, function-tag), execution framework, result formatting |
| `channel` | `src/channel/` | Channel adapters (CLI, Web), permission system, auto-reply engine |
| `provider` | `src/provider/` | HTTP transport, 429/backoff handling, error taxonomy, Dexador backend |
| `subagent` | `src/subagent/` | ACP task management, concurrency limits, state tracking |
| `skills` | `src/skills/` | Skill registry and lookup |
| `bootstrap` | `src/bootstrap/` | Agent initialization and bootstrapping |

### Infrastructure Layer

| Module | Files | Purpose |
|--------|-------|---------|
| `config` | `src/config/` | JSON parsing, validation, provider runtime construction |
| `security` | `src/security/` | Policy enforcement, sandboxing, permission controls |
| `memory` | `src/memory/` | Contract-based storage with none, markdown, LRU backends |
| `cron` | `src/cron/` | Scheduled task execution |

## Data Flow

### Incoming Message Flow

```
Gateway receives request
       │
       ▼
Parse JSON-RPC method/params
       │
       ▼
Route to agent core
       │
       ├──► Channel send → CLI/Web output
       │
       ├──► Tool execution → Dispatcher → Tool handler
       │
       ├──► Provider request → HTTP layer → LLM API
       │
       └──► Memory operation → Storage backend
```

### Tool Execution Flow

```
LLM response contains tool call
       │
       ▼
Dispatcher parses tool call (XML/native/function-tag)
       │
       ▼
Tool registry lookup
       │
       ▼
Execute tool handler (with error protection)
       │
       ▼
Format result for LLM
       │
       ▼
Return to conversation
```

### Channel Message Flow

```
Channel receives message
       │
       ▼
Permission check
       │
       ├──► Denied → Drop or error response
       │
       ▼
Auto-reply evaluation (if enabled)
       │
       ├──► Match found → Send response
       │
       ▼
Route to agent core
       │
       ▼
Process via standard message flow
```

## Static Typing

NilClaw uses strict static typing throughout:

### SBCL Declarations

Every function includes type declarations:

```lisp
(declaim (ftype (function (string) (values string &optional))
                process-message))
(defun process-message (input)
  (declare (type string input))
  ...)
```

### Structure Types

All data structures use typed slots:

```lisp
(defstruct tool-call
  (name "" :type string)
  (arguments-json "{}" :type string)
  (id nil :type (or null string)))
```

### Optimization

Default optimization settings:

```lisp
(declaim (optimize (safety 3) (debug 3)))
```

Safety is prioritized over speed for reliability.

## Error Handling

NilClaw uses Common Lisp conditions:

```lisp
;; Condition types
(define-condition concurrency-limit-exceeded (error)
  ((max :reader concurrency-limit-max :initarg :max)))

(define-condition unknown-task (error)
  ((id :reader unknown-task-id :initarg :id)))
```

All errors are recoverable via the condition system.

## Thread Safety

Subagent manager uses mutex-protected state:

```lisp
(sb-thread:with-mutex ((subagent-manager-mutex manager))
  ;; Critical section
  ...)
```

This ensures safe concurrent access to shared state.
