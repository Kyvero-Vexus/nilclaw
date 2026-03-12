---
layout: default
title: Subagents
nav_order: 8
---

# Subagents (ACP)

The ACP (Agent Capability Protocol) subsystem manages subagent tasks with concurrency limits.

## Overview

Subagents are spawned to handle complex, parallelizable work:

- Task lifecycle management
- Concurrency enforcement
- State tracking
- Error handling

## Task Manager

### Creating a Manager

```lisp
;; Default configuration (max 4 concurrent tasks)
(defparameter *manager* (nilclaw/subagent:make-default-subagent-manager))

;; Custom configuration
(defparameter *manager*
  (nilclaw/subagent:make-subagent-manager
    :config (nilclaw/subagent:make-subagent-config
              :max-concurrent 8
              :max-iterations 20)))
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `max-concurrent` | integer | 4 | Maximum parallel tasks (1-16) |
| `max-iterations` | integer | 15 | Max tool iterations per task |
| `task-runner` | function | `nil` | Custom task runner function |

## Task Lifecycle

### Spawning Tasks

```lisp
(multiple-value-bind (task-id state)
    (nilclaw/subagent:spawn-task *manager*
      "Analyze the codebase"
      :label "analyzer"
      :session-key "session-123")
  (format t "Spawned task ~A~%" task-id))
```

### Task Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `task-text` | string | Task description |
| `label` | string | Optional label |
| `session-key` | string | Parent session identifier |

### Task State

```lisp
;; Get task state
(nilclaw/subagent:get-task *manager* task-id)
;; => #<TASK-STATE status=:running ...>

;; List all tasks
(nilclaw/subagent:list-tasks *manager*)
;; => (#<TASK-STATE> #<TASK-STATE> ...)
```

### State Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Task ID |
| `status` | keyword | `:running`, `:completed`, `:failed` |
| `label` | string | Task label |
| `session-key` | string | Parent session |
| `started-at` | integer | Start timestamp |
| `completed-at` | integer | End timestamp (or nil) |
| `result` | string | Result (if completed) |
| `error-msg` | string | Error message (if failed) |

### Completing Tasks

```lisp
;; Successful completion
(nilclaw/subagent:complete-task *manager* task-id "Analysis complete")

;; Failure
(nilclaw/subagent:fail-task *manager* task-id "Network error")
```

## Concurrency

### Checking Availability

```lisp
;; Can spawn more tasks?
(nilclaw/subagent:concurrency-available-p *manager*)
;; => t or nil

;; Current running count
(nilclaw/subagent:running-count *manager*)
;; => 2
```

### Limit Enforcement

Attempting to spawn beyond the limit signals an error:

```lisp
(handler-case
    (nilclaw/subagent:spawn-task *manager* "task 5")
  (nilclaw/subagent:concurrency-limit-exceeded (e)
    (format t "Max ~A concurrent tasks~%"
            (nilclaw/subagent:concurrency-limit-max e))))
```

## Thread Safety

The manager uses mutex-protected state:

```lisp
;; All operations are thread-safe
(sb-thread:make-thread
  (lambda ()
    (nilclaw/subagent:spawn-task *manager* "parallel task 1")))

(sb-thread:make-thread
  (lambda ()
    (nilclaw/subagent:spawn-task *manager* "parallel task 2")))
```

## Error Conditions

### Condition Types

| Condition | Description |
|-----------|-------------|
| `concurrency-limit-exceeded` | Max concurrent tasks reached |
| `unknown-task` | Task ID not found |

### Handling Errors

```lisp
(handler-case
    (nilclaw/subagent:complete-task *manager* 999 "done")
  (nilclaw/subagent:unknown-task (e)
    (format t "Task ~A not found~%"
            (nilclaw/subagent:unknown-task-id e))))
```

## Example Workflow

```lisp
;; Create manager
(defparameter *mgr* (nilclaw/subagent:make-default-subagent-manager))

;; Spawn multiple tasks
(loop for i from 1 to 3
      do (nilclaw/subagent:spawn-task *mgr*
           (format nil "Process item ~D" i)
           :label (format nil "processor-~D" i)))

;; List running tasks
(format t "Running: ~A~%" (nilclaw/subagent:running-count *mgr*))

;; Complete tasks
(dolist (task (nilclaw/subagent:list-tasks *mgr*))
  (when (eq :running (nilclaw/subagent:task-state-status task))
    (nilclaw/subagent:complete-task *mgr*
      (nilclaw/subagent:task-state-id task)
      "Done")))
```

## Integration with Agent Core

Subagent tasks integrate with the main agent:

1. Agent receives complex request
2. Spawns subagent task
3. Subagent executes with limited scope
4. Result returned to main agent
5. Task state updated

This enables parallel processing and task delegation while maintaining clean state boundaries.
