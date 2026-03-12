---
layout: default
title: Getting Started
nav_order: 2
---

# Getting Started

## Prerequisites

- **SBCL** 2.5.2+ (Steel Bank Common Lisp)
- **Quicklisp** (Common Lisp package manager)

### Installing SBCL

```bash
# Debian/Ubuntu
sudo apt-get install sbcl

# macOS (via Homebrew)
brew install sbcl

# From source
# See https://sbcl.org/getting.html
```

### Installing Quicklisp

```bash
curl -O https://beta.quicklisp.org/quicklisp.lisp
sbcl --load quicklisp.lisp \
     --eval '(quicklisp-quickstart:install)' \
     --eval '(ql:add-to-init-file)'
```

## Installation

### Clone the Repository

```bash
git clone https://github.com/Kyvero-Vexus/nilclaw.git
cd nilclaw
```

### Install Dependencies

```bash
sbcl --load ~/quicklisp/setup.lisp \
     --eval '(ql:quickload (list :alexandria :cl-json :cl-ppcre :fiveam))'
```

### Build and Test

```bash
# Load the system
make load

# Run tests
make test

# Validate traceability
make traceability
```

Expected output:

```
Did 838 checks.
   Pass: 838 (100%)
   Skip: 0 ( 0%)
   Fail: 0 ( 0%)
```

## Basic Usage

### REPL Session

```lisp
;; Load NilClaw
(asdf:load-system "nilclaw")

;; Import the channel package
(use-package :nilclaw/channel)

;; Create a channel manager
(defparameter *manager* (make-channel-manager))

;; Register a CLI channel
(register-channel *manager* "cli" (make-cli-channel))

;; Start all channels
(start-all-channels *manager*)

;; Send a message
(channel-send (find-channel *manager* "cli") 
              "user" 
              "Hello, NilClaw!")
```

### Tool Execution

```lisp
;; Load dispatcher
(use-package :nilclaw/dispatcher)

;; Create a tool registry
(defparameter *registry* (make-tool-registry))

;; Register a tool
(register-tool *registry* "greet"
  (lambda (args)
    (format nil "Hello, ~A!" (gethash "name" args))))

;; Create a tool call
(defparameter *call* (make-tool-call 
                       :name "greet" 
                       :arguments-json "{\"name\":\"World\"}"))

;; Execute
(execute-tool *registry* *call)
;; => "Hello, World!"
```

### Subagent Management

```lisp
;; Load subagent package
(use-package :nilclaw/subagent)

;; Create a manager
(defparameter *subagent-mgr* (make-default-subagent-manager))

;; Spawn a task
(multiple-value-bind (task-id state)
    (spawn-task *subagent-mgr* "Process document"
                :label "doc-processor"
                :session-key "session-123")
  (format t "Spawned task ~A~%" task-id))

;; List running tasks
(list-tasks *subagent-mgr*)

;; Complete a task
(complete-task *subagent-mgr* task-id "Done")
```

## Next Steps

- [Configuration](configuration.html) — Set up providers, channels, and memory
- [Architecture](architecture.html) — Understand the system design
- [API Reference](api-reference.html) — Gateway API documentation
- [Channels](channels.html) — Channel system details
- [Tools](tools.html) — Tool execution framework
