---
layout: default
title: Configuration
nav_order: 4
---

# Configuration

NilClaw is configured in **pure Common Lisp** — no JSON, no YAML.

## Configuration File

Default locations (searched in order):

1. `~/.nilclaw/init.lisp`
2. `~/.nilclaw/config.lisp`
3. `~/.config/nilclaw/init.lisp`

## Basic Example

```lisp
;;; ~/.nilclaw/init.lisp

(configure
  :default-model "anthropic/claude-sonnet-4-20250514"
  :default-provider "openrouter"
  :default-temperature 0.7d0

  :gateway (:port 3000
            :host "127.0.0.1"
            :token "my-secret-token")

  :memory (:backend "hybrid"
           :auto-save t)

  :channels ((:type :cli :enabled t)
             (:type :web :enabled t
              :path "/" :transport :relay))

  :security (:sandbox-enabled t
             :audit-enabled t))
```

Because it's Lisp, you can use the full language:

```lisp
;;; Dynamic configuration

(defvar *dev-mode* (uiop:getenv "NILCLAW_DEV"))

(configure
  :default-model (if *dev-mode*
                     "openai/gpt-4o-mini"
                     "anthropic/claude-sonnet-4-20250514")
  :default-temperature (if *dev-mode* 1.0d0 0.7d0)
  :gateway (:port (if *dev-mode* 8080 3000)
            :host "127.0.0.1")
  :security (:sandbox-enabled (not *dev-mode*)))
```

## Configuration Reference

### Top-Level Options

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `:default-model` | string | `nil` | Default LLM model |
| `:default-provider` | string | `"openrouter"` | Default provider |
| `:default-temperature` | double-float | `0.7d0` | Sampling temperature |
| `:workspace-dir` | string | `nil` | Workspace directory |
| `:reasoning-effort` | string | `nil` | Reasoning effort level |

### Gateway

```lisp
:gateway (:port 3000
          :host "127.0.0.1"
          :token nil
          :require-pairing t
          :keepalive-interval-ms 30000
          :reconnect-initial-backoff-ms 500
          :reconnect-max-backoff-ms 30000)
```

### Memory

```lisp
:memory (:backend "hybrid"        ; "none", "markdown", "lru", "hybrid"
         :profile "hybrid_keyword"
         :auto-save t
         :citations "auto")
```

### Channels

```lisp
:channels ((:type :cli :enabled t)
           (:type :web :enabled t
            :path "/"
            :transport :relay
            :relay-url "wss://relay.example.com"
            :auth-token "secret"
            :allowed-origins ("https://example.com")
            :message-auth-mode :token))
```

### Security

```lisp
:security (:sandbox-enabled nil
           :sandbox-backend "auto"
           :max-memory-mb 512
           :max-cpu-time-seconds 60
           :audit-enabled t
           :audit-log-path "audit.log")
```

### Agent

```lisp
:agent (:max-tool-iterations 1000
        :max-history-messages 100
        :parallel-tools nil
        :tool-dispatcher "auto"
        :token-limit 200000)
```

### Scheduler (Cron)

```lisp
:scheduler (:enabled t
            :max-tasks 64
            :max-concurrent 4
            :agent-timeout-secs 0)
```

### Reliability

```lisp
:reliability (:provider-retries 2
              :provider-backoff-ms 500
              :fallback-providers nil)
```

### Cost Limits

```lisp
:cost (:enabled nil
       :daily-limit-usd 10.0d0
       :monthly-limit-usd 100.0d0)
```

### Heartbeat

```lisp
:heartbeat (:enabled nil
            :interval-minutes 30)
```

## Sub-Config Merging

Sub-configs merge with defaults — you only need to specify overrides:

```lisp
;; Only override port; all other gateway defaults preserved
:gateway (:port 8080)
```

## Migrating from OpenClaw

A migration script converts OpenClaw JSON config to NilClaw Lisp config:

```bash
# Auto-detect OpenClaw config location
sbcl --script scripts/migrate-openclaw-config.lisp

# Explicit paths
sbcl --script scripts/migrate-openclaw-config.lisp \
    ~/.openclaw/config.json \
    ~/.nilclaw/init.lisp
```

The generated file is pure Common Lisp — edit it directly.

## Programmatic Configuration

```lisp
;; Load config from file
(defparameter *cfg* (nilclaw/config:load-config))

;; Create config from plist
(defparameter *cfg*
  (nilclaw/config:apply-config-plist
    '(:default-model "gpt-4o"
      :gateway (:port 8080))))

;; Serialize config to readable sexp
(nilclaw/config:config-to-sexp-string *cfg*)
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `NILCLAW_CONFIG` | Explicit config file path |
| `OPENAI_API_KEY` | OpenAI API key |
| `ANTHROPIC_API_KEY` | Anthropic API key |
