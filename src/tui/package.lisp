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
           #:local-tui-client-connection))
