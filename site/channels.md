---
layout: default
title: Channels
nav_order: 7
---

# Channels

The channel system provides message routing for CLI and Web interfaces.

## Overview

Channels are the interface between NilClaw and external systems:

- **CLI Channel** — Standard input/output for terminal usage
- **Web Channel** — HTTP/WebSocket for browser and API clients

## Channel Protocol

All channels implement the channel protocol:

```lisp
;; Generic functions
channel-start (channel)        ; Start the channel
channel-stop (channel)         ; Stop the channel
channel-send (channel target message &optional media)  ; Send a message
channel-name (channel)         ; Get channel name
channel-health-check (channel) ; Check channel health
```

## Channel Manager

### Creating a Manager

```lisp
(defparameter *manager* (nilclaw/channel:make-channel-manager))
```

### Registering Channels

```lisp
;; Register CLI channel
(nilclaw/channel:register-channel *manager* "cli"
  (nilclaw/channel:make-cli-channel))

;; Register Web channel
(nilclaw/channel:register-channel *manager* "web"
  (nilclaw/channel:make-web-channel
    :path "/"
    :transport :relay
    :relay-url "wss://relay.example.com"))
```

### Starting/Stopping

```lisp
;; Start all channels
(nilclaw/channel:start-all-channels *manager*)

;; Stop all channels
(nilclaw/channel:stop-all-channels *manager*)

;; Health check
(nilclaw/channel:health-check-all *manager*)
;; => (("cli" . t) ("web" . t))
```

### Finding Channels

```lisp
(nilclaw/channel:find-channel *manager* "cli")
;; => #<CLI-CHANNEL>
```

## CLI Channel

The CLI channel uses stdin/stdout:

```lisp
(defparameter *cli* (nilclaw/channel:make-cli-channel))

;; Start
(nilclaw/channel:channel-start *cli*)

;; Send to stdout
(nilclaw/channel:channel-send *cli* "user" "Hello, terminal!")
;; Prints: Hello, terminal!

;; Health check (always true when running)
(nilclaw/channel:channel-health-check *cli*)
;; => t
```

## Web Channel

The Web channel supports browser and API clients:

```lisp
(defparameter *web*
  (nilclaw/channel:make-web-channel
    :path "/chat"
    :auth-token "secret-token"
    :allowed-origins '("https://example.com")
    :transport :relay
    :relay-url "wss://relay.example.com/ws"
    :message-auth-mode :token))
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `path` | string | `"/"` | URL path prefix |
| `auth-token` | string | `null` | Bearer token |
| `allowed-origins` | list | `[]` | CORS origins |
| `transport` | keyword | `:relay` | `:relay` or `:local` |
| `relay-url` | string | `null` | WebSocket relay URL |
| `message-auth-mode` | keyword | `:none` | `:none` or `:token` |

## Permission System

### DM Policy

```lisp
;; Allow all DMs
(defparameter *allow-dm* (nilclaw/channel:make-dm-policy-allow))

;; Deny all DMs
(defparameter *deny-dm* (nilclaw/channel:make-dm-policy-deny))

;; Allowlist only
(defparameter *allowlist-dm*
  (nilclaw/channel:make-dm-policy-allowlist
    :allowed '("user-1" "user-2")))
```

### Group Policy

```lisp
;; Open group (all can post)
(defparameter *open-group*
  (nilclaw/channel:make-group-policy-open))

;; Mention only (only @mentions trigger)
(defparameter *mention-only*
  (nilclaw/channel:make-group-policy-mention-only))

;; Allowlist
(defparameter *allowlist-group*
  (nilclaw/channel:make-group-policy-allowlist
    :allowed '("user-1" "user-2")))
```

### Permission Check

```lisp
(nilclaw/channel:check-dm-permission *allow-dm* "user-123")
;; => t

(nilclaw/channel:check-group-permission *mention-only* message)
;; => t or nil
```

## Auto-Reply

### Creating Auto-Reply

```lisp
;; Define rules
(defparameter *rules*
  (list
    (nilclaw/channel:make-auto-reply-rule
      :name "greeting"
      :trigger-type :keyword
      :trigger-pattern "hello"
      :response "Hi! How can I help?"
      :priority 10)
    (nilclaw/channel:make-auto-reply-rule
      :name "help"
      :trigger-type :exact
      :trigger-pattern "help"
      :response "Available commands: ..."
      :priority 5)))

;; Create config
(defparameter *config*
  (nilclaw/channel:make-auto-reply-config
    :enabled t
    :max-replies-per-hour 10
    :rules *rules*
    :fallback-response "I'm here to help!"))

;; Create runtime
(defparameter *auto-reply*
  (nilclaw/channel:make-auto-reply-runtime :config *config*))
```

### Trigger Types

| Type | Description | Example |
|------|-------------|---------|
| `:keyword` | Case-insensitive substring | "help" matches "I need help" |
| `:exact` | Exact match required | "ping" matches only "ping" |
| `:regex` | Regular expression | `issue-\d+` matches "issue-123" |

### Rate Limiting

```lisp
;; Max 10 replies per hour per session
(nilclaw/channel:make-auto-reply-config
  :max-replies-per-hour 10)
```

### Processing Messages

```lisp
(multiple-value-bind (response should-reply)
    (nilclaw/channel:channel-receive-with-auto-reply
      *web* *auto-reply* "Hello!" "session-123")
  (when should-reply
    (format t "Auto-reply: ~A~%" response)))
```

## Channel Messages

```lisp
;; Create a message
(defparameter *msg*
  (nilclaw/channel:make-channel-message
    :id "msg-123"
    :sender "user-456"
    :content "Hello!"
    :channel "web"
    :timestamp (get-universal-time)))

;; Access fields
(nilclaw/channel:channel-message-content *msg)
;; => "Hello!"
```
