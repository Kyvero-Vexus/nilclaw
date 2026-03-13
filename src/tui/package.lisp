;;;; package.lisp — TUI client package definition
;;;; NilClaw - Statically typed Common Lisp agent harness

(defpackage #:nilclaw/tui
  (:use #:cl)
  (:export ;; TUI client types
           #:tui-client
           #:tui-client-gateway-url
           #:tui-client-session-key
           #:tui-client-connected-p
           #:tui-client-protocol-version
           #:tui-client-history
           #:make-tui-client
           ;; TUI operations
           #:tui-connect
           #:tui-send-message
           #:tui-receive-response
           #:tui-disconnect
           #:tui-client-ready-p
           ;; TUI REPL
           #:run-tui
           #:tui-entrypoint-available-p
           ;; Gateway-backed TUI (in-process, no network)
           #:make-local-tui-client
           #:local-tui-connect
           #:local-tui-send
           #:local-tui-history
           #:local-tui-client
           #:local-tui-client-runtime
           #:local-tui-client-session-key
           #:local-tui-client-connected-p
           #:local-tui-client-connection
           ;; Phase 1 parity: state accessors
           #:local-tui-client-agent-id
           #:local-tui-client-model-id
           #:local-tui-client-deliver-p
           #:local-tui-client-think-level
           #:local-tui-client-verbose-mode
           #:local-tui-client-reasoning-mode
           ;; Phase 2 parity: extended state accessors
           #:local-tui-client-elevated-p
           #:local-tui-client-activation-mode
           #:local-tui-client-shell-allowed-p
           #:local-tui-client-token-usage
           ;; Slash command dispatch
           #:tui-handle-slash-command
           ;; Shell exec
           #:tui-handle-shell-command
           ;; Display helpers
           #:tui-format-status
           #:tui-format-footer
           #:tui-format-history-entry
           #:tui-format-help
           #:tui-format-context
           #:tui-format-usage
           #:tui-format-settings
           ;; Picker helpers
           #:tui-pick-from-list
           ;; Streaming display
           #:tui-streaming-state
           #:make-tui-streaming-state
           #:tui-streaming-state-buffer
           #:tui-streaming-state-chunks-received
           #:tui-streaming-state-started-at
           #:tui-streaming-state-finished-p
           #:tui-streaming-append
           #:tui-streaming-finish
           #:tui-streaming-elapsed-ms))
