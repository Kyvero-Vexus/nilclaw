;;;; tui-tests.lisp — Tests for NilClaw native TUI client
;;;; NilClaw - Statically typed Common Lisp agent harness

(in-package #:nilclaw/tests)
(in-suite tui-suite)

;;; ====================================================================
;;; Helper: create a connected local TUI client with test fixtures
;;; ====================================================================

(defun make-test-tui-client (&key (session-key "test-tui")
                                   (agents nil)
                                   (models nil))
  "Create a local TUI client connected to a test runtime.
Optionally pre-populate agents and models."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime
                   :agents agents
                   :models models))
         (client (nilclaw/tui:make-local-tui-client runtime :session-key session-key)))
    (nilclaw/tui:local-tui-connect client)
    client))

;;; ====================================================================
;;; Entrypoint availability
;;; ====================================================================

(test tui-entrypoint-available
  "TUI entrypoint must be available."
  (is (nilclaw/tui:tui-entrypoint-available-p)))

;;; ====================================================================
;;; Local TUI client lifecycle
;;; ====================================================================

(test local-tui-client-creation
  "Local TUI client can be created with a gateway runtime."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (client (nilclaw/tui:make-local-tui-client runtime :session-key "test-tui")))
    (is (typep client 'nilclaw/tui:local-tui-client))
    (is (string= "test-tui" (nilclaw/tui:local-tui-client-session-key client)))
    (is (not (nilclaw/tui:local-tui-client-connected-p client)))))

(test local-tui-connect-handshake
  "Local TUI client performs connect handshake successfully."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (client (nilclaw/tui:make-local-tui-client runtime :session-key "test-connect")))
    (is (nilclaw/tui:local-tui-connect client))
    (is (nilclaw/tui:local-tui-client-connected-p client))
    (is (not (null (nilclaw/tui:local-tui-client-connection client))))))

;;; ====================================================================
;;; Send/receive through TUI path
;;; ====================================================================

(test local-tui-send-receive
  "Local TUI client can send a message and receive a response."
  (let ((client (make-test-tui-client :session-key "test-chat")))
    (multiple-value-bind (response success-p)
        (nilclaw/tui:local-tui-send client "hello from tui")
      (is-true success-p)
      (is (stringp response))
      (is (search "hello from tui" response)))))

(test local-tui-send-before-connect-fails
  "Sending before connecting returns failure."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (client (nilclaw/tui:make-local-tui-client runtime :session-key "test-noconn")))
    (multiple-value-bind (response success-p)
        (nilclaw/tui:local-tui-send client "should fail")
      (is (null response))
      (is (not success-p)))))

;;; ====================================================================
;;; History through TUI path
;;; ====================================================================

(test local-tui-history-retrieval
  "Local TUI client can retrieve chat history after sending messages."
  (let ((client (make-test-tui-client :session-key "test-history")))
    (nilclaw/tui:local-tui-send client "first message")
    (let ((history (nilclaw/tui:local-tui-history client)))
      (is (>= (length history) 2))  ; user + assistant
      (let ((first-msg (first history)))
        (is (string= "user" (getf first-msg :role)))
        (is (string= "first message" (getf first-msg :content)))))))

(test local-tui-history-before-connect-empty
  "History before connecting returns nil."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (client (nilclaw/tui:make-local-tui-client runtime :session-key "test-nohist")))
    (is (null (nilclaw/tui:local-tui-history client)))))

;;; ====================================================================
;;; Multi-turn conversation
;;; ====================================================================

(test local-tui-multi-turn
  "Local TUI client supports multi-turn conversation."
  (let ((client (make-test-tui-client :session-key "test-multi")))
    (multiple-value-bind (r1 s1) (nilclaw/tui:local-tui-send client "turn one")
      (is-true s1)
      (is (stringp r1)))
    (multiple-value-bind (r2 s2) (nilclaw/tui:local-tui-send client "turn two")
      (is-true s2)
      (is (stringp r2)))
    (let ((history (nilclaw/tui:local-tui-history client)))
      (is (>= (length history) 4)))))

;;; ====================================================================
;;; Remote TUI client type
;;; ====================================================================

(test tui-client-struct
  "Remote TUI client struct can be created with defaults."
  (let ((client (nilclaw/tui:make-tui-client)))
    (is (typep client 'nilclaw/tui:tui-client))
    (is (string= "ws://127.0.0.1:18789" (nilclaw/tui:tui-client-gateway-url client)))
    (is (not (nilclaw/tui:tui-client-connected-p client)))
    (is (not (nilclaw/tui:tui-client-ready-p client)))))

(test tui-client-custom-url
  "Remote TUI client can be created with custom gateway URL."
  (let ((client (nilclaw/tui:make-tui-client :gateway-url "ws://example.com:9999"
                                              :session-key "custom-session")))
    (is (string= "ws://example.com:9999" (nilclaw/tui:tui-client-gateway-url client)))
    (is (string= "custom-session" (nilclaw/tui:tui-client-session-key client)))))

;;; ====================================================================
;;; Phase 1 Parity: Default state values
;;; ====================================================================

(test tui-default-state-values
  "New local TUI client has correct default state values."
  (let ((client (make-test-tui-client)))
    (is (string= "default" (nilclaw/tui:local-tui-client-agent-id client)))
    (is (string= "" (nilclaw/tui:local-tui-client-model-id client)))
    (is (not (nilclaw/tui:local-tui-client-deliver-p client)))
    (is (eq :off (nilclaw/tui:local-tui-client-think-level client)))
    (is (eq :off (nilclaw/tui:local-tui-client-verbose-mode client)))
    (is (eq :off (nilclaw/tui:local-tui-client-reasoning-mode client)))))

;;; ====================================================================
;;; Phase 1 Parity: Slash command — /help
;;; ====================================================================

(test slash-help
  "/help returns command list."
  (let ((client (make-test-tui-client)))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/help")
      (is (eq :continue action))
      (is (search "/help" output))
      (is (search "/status" output))
      (is (search "/sessions" output))
      (is (search "/exit" output))
      (is (search "/deliver" output))
      (is (search "/think" output)))))

;;; ====================================================================
;;; Phase 1 Parity: Slash command — /status
;;; ====================================================================

(test slash-status
  "/status shows connection state and toggles."
  (let ((client (make-test-tui-client)))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/status")
      (is (eq :continue action))
      (is (search "connected: yes" output))
      (is (search "deliver:   off" output))
      (is (search "think:     off" output))
      (is (search "reasoning: off" output)))))

;;; ====================================================================
;;; Phase 1 Parity: Slash command — /sessions
;;; ====================================================================

(test slash-sessions
  "/sessions lists sessions from gateway."
  (let ((client (make-test-tui-client :session-key "sess-1")))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/sessions")
      (is (eq :continue action))
      (is (search "sess-1" output)))))

;;; ====================================================================
;;; Phase 1 Parity: Slash command — /session <key>
;;; ====================================================================

(test slash-session-switch
  "/session <key> switches session."
  (let ((client (make-test-tui-client :session-key "old-session")))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/session new-session")
      (is (eq :continue action))
      (is (search "new-session" output))
      (is (string= "new-session" (nilclaw/tui:local-tui-client-session-key client))))))

(test slash-session-no-arg
  "/session without arg shows error."
  (let ((client (make-test-tui-client)))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/session")
      (is (eq :continue action))
      (is (search "Usage" output)))))

;;; ====================================================================
;;; Phase 1 Parity: Slash command — /agents
;;; ====================================================================

(test slash-agents-empty
  "/agents with no registered agents shows (none)."
  (let ((client (make-test-tui-client)))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/agents")
      (is (eq :continue action))
      (is (search "none" output)))))

(test slash-agents-with-data
  "/agents with registered agents lists them."
  (let ((client (make-test-tui-client
                 :agents (list (nilclaw/gateway:make-gateway-agent
                                :id "main" :display-name "Main Agent")
                               (nilclaw/gateway:make-gateway-agent
                                :id "research" :display-name "Research Agent")))))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/agents")
      (is (eq :continue action))
      (is (search "main" output))
      (is (search "research" output)))))

;;; ====================================================================
;;; Phase 1 Parity: Slash command — /agent <id>
;;; ====================================================================

(test slash-agent-switch
  "/agent <id> switches agent."
  (let ((client (make-test-tui-client)))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/agent research")
      (is (eq :continue action))
      (is (search "research" output))
      (is (string= "research" (nilclaw/tui:local-tui-client-agent-id client))))))

(test slash-agent-no-arg
  "/agent without arg shows error."
  (let ((client (make-test-tui-client)))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/agent")
      (is (eq :continue action))
      (is (search "Usage" output)))))

;;; ====================================================================
;;; Phase 1 Parity: Slash command — /models
;;; ====================================================================

(test slash-models-empty
  "/models with no registered models shows (none)."
  (let ((client (make-test-tui-client)))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/models")
      (is (eq :continue action))
      (is (search "none" output)))))

(test slash-models-with-data
  "/models with registered models lists them."
  (let ((client (make-test-tui-client
                 :models (list (nilclaw/gateway:make-gateway-model
                                :id "claude-3" :name "Claude 3" :provider "anthropic")
                               (nilclaw/gateway:make-gateway-model
                                :id "gpt-4" :name "GPT-4" :provider "openai")))))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/models")
      (is (eq :continue action))
      (is (search "claude-3" output))
      (is (search "gpt-4" output)))))

;;; ====================================================================
;;; Phase 1 Parity: Slash command — /model <id>
;;; ====================================================================

(test slash-model-set
  "/model <id> sets model."
  (let ((client (make-test-tui-client)))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/model anthropic/claude-3")
      (is (eq :continue action))
      (is (search "anthropic/claude-3" output))
      (is (string= "anthropic/claude-3" (nilclaw/tui:local-tui-client-model-id client))))))

(test slash-model-no-arg
  "/model without arg shows error."
  (let ((client (make-test-tui-client)))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/model")
      (is (eq :continue action))
      (is (search "Usage" output)))))

;;; ====================================================================
;;; Phase 1 Parity: Slash command — /new, /reset
;;; ====================================================================

(test slash-new-resets-session
  "/new creates a new session."
  (let ((client (make-test-tui-client :session-key "old")))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/new")
      (is (eq :reset action))
      (is (search "New session" output))
      (is (not (string= "old" (nilclaw/tui:local-tui-client-session-key client)))))))

(test slash-reset-resets-session
  "/reset creates a new session."
  (let ((client (make-test-tui-client :session-key "old")))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/reset")
      (is (eq :reset action))
      (is (search "New session" output)))))

;;; ====================================================================
;;; Phase 1 Parity: Slash command — /deliver
;;; ====================================================================

(test slash-deliver-on
  "/deliver on enables delivery."
  (let ((client (make-test-tui-client)))
    (is (not (nilclaw/tui:local-tui-client-deliver-p client)))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/deliver on")
      (is (eq :continue action))
      (is (search "on" output))
      (is (nilclaw/tui:local-tui-client-deliver-p client)))))

(test slash-deliver-off
  "/deliver off disables delivery."
  (let ((client (make-test-tui-client)))
    (nilclaw/tui:tui-handle-slash-command client "/deliver on")
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/deliver off")
      (is (eq :continue action))
      (is (search "off" output))
      (is (not (nilclaw/tui:local-tui-client-deliver-p client))))))

(test slash-deliver-bad-arg
  "/deliver with bad arg shows error."
  (let ((client (make-test-tui-client)))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/deliver maybe")
      (is (eq :continue action))
      (is (search "Usage" output)))))

;;; ====================================================================
;;; Phase 1 Parity: Slash command — /think
;;; ====================================================================

(test slash-think-levels
  "/think sets correct levels."
  (let ((client (make-test-tui-client)))
    (dolist (pair '(("off" :off) ("minimal" :minimal) ("low" :low)
                    ("medium" :medium) ("high" :high)))
      (let ((arg (first pair))
            (expected (second pair)))
        (nilclaw/tui:tui-handle-slash-command client (format nil "/think ~A" arg))
        (is (eq expected (nilclaw/tui:local-tui-client-think-level client)))))))

(test slash-think-bad-arg
  "/think with bad arg shows error."
  (let ((client (make-test-tui-client)))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/think ultra")
      (is (eq :continue action))
      (is (search "Usage" output)))))

;;; ====================================================================
;;; Phase 1 Parity: Slash command — /verbose
;;; ====================================================================

(test slash-verbose-modes
  "/verbose sets correct modes."
  (let ((client (make-test-tui-client)))
    (dolist (pair '(("on" :on) ("full" :full) ("off" :off)))
      (let ((arg (first pair))
            (expected (second pair)))
        (nilclaw/tui:tui-handle-slash-command client (format nil "/verbose ~A" arg))
        (is (eq expected (nilclaw/tui:local-tui-client-verbose-mode client)))))))

(test slash-verbose-bad-arg
  "/verbose with bad arg shows error."
  (let ((client (make-test-tui-client)))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/verbose partial")
      (is (eq :continue action))
      (is (search "Usage" output)))))

;;; ====================================================================
;;; Phase 1 Parity: Slash command — /reasoning
;;; ====================================================================

(test slash-reasoning-modes
  "/reasoning sets correct modes."
  (let ((client (make-test-tui-client)))
    (dolist (pair '(("on" :on) ("off" :off) ("stream" :stream)))
      (let ((arg (first pair))
            (expected (second pair)))
        (nilclaw/tui:tui-handle-slash-command client (format nil "/reasoning ~A" arg))
        (is (eq expected (nilclaw/tui:local-tui-client-reasoning-mode client)))))))

(test slash-reasoning-bad-arg
  "/reasoning with bad arg shows error."
  (let ((client (make-test-tui-client)))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/reasoning always")
      (is (eq :continue action))
      (is (search "Usage" output)))))

;;; ====================================================================
;;; Phase 1 Parity: Slash command — /abort
;;; ====================================================================

(test slash-abort
  "/abort returns graceful message."
  (let ((client (make-test-tui-client)))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/abort")
      (is (eq :continue action))
      (is (search "abort" (string-downcase output))))))

;;; ====================================================================
;;; Phase 1 Parity: Slash command — /exit
;;; ====================================================================

(test slash-exit
  "/exit returns :exit action."
  (let ((client (make-test-tui-client)))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/exit")
      (is (eq :exit action))
      (is (search "Goodbye" output)))))

;;; ====================================================================
;;; Phase 1 Parity: Unknown slash command
;;; ====================================================================

(test slash-unknown
  "Unknown slash command returns error."
  (let ((client (make-test-tui-client)))
    (multiple-value-bind (output action)
        (nilclaw/tui:tui-handle-slash-command client "/foobar")
      (is (eq :continue action))
      (is (search "Unknown command" output))
      (is (search "/help" output)))))

;;; ====================================================================
;;; Phase 1 Parity: Display helpers
;;; ====================================================================

(test tui-format-history-entry-with-timestamp
  "History entry formats as [HH:MM] role> content."
  (let* ((ts (encode-universal-time 0 30 14 1 1 2026))
         (entry (list :role "user" :content "hello" :timestamp ts))
         (formatted (nilclaw/tui:tui-format-history-entry entry)))
    (is (search "[14:30]" formatted))
    (is (search "user>" formatted))
    (is (search "hello" formatted))))

(test tui-format-history-entry-zero-timestamp
  "History entry with zero timestamp shows [--:--]."
  (let* ((entry (list :role "assistant" :content "hi" :timestamp 0))
         (formatted (nilclaw/tui:tui-format-history-entry entry)))
    (is (search "[--:--]" formatted))
    (is (search "assistant>" formatted))))

(test tui-format-status-output
  "tui-format-status includes all state fields."
  (let ((client (make-test-tui-client :session-key "my-sess")))
    (setf (nilclaw/tui:local-tui-client-agent-id client) "test-agent")
    (setf (nilclaw/tui:local-tui-client-model-id client) "anthropic/claude")
    (setf (nilclaw/tui:local-tui-client-deliver-p client) t)
    (setf (nilclaw/tui:local-tui-client-think-level client) :high)
    (let ((status (nilclaw/tui:tui-format-status client)))
      (is (search "connected: yes" status))
      (is (search "my-sess" status))
      (is (search "test-agent" status))
      (is (search "anthropic/claude" status))
      (is (search "deliver:   on" status))
      (is (search "think:     high" status)))))

(test tui-format-footer-output
  "tui-format-footer includes connection+agent+session+model+toggles."
  (let ((client (make-test-tui-client :session-key "s1")))
    (setf (nilclaw/tui:local-tui-client-agent-id client) "main")
    (setf (nilclaw/tui:local-tui-client-model-id client) "gpt-4")
    (let ((footer (nilclaw/tui:tui-format-footer client)))
      (is (search "connected" footer))
      (is (search "agent:main" footer))
      (is (search "session:s1" footer))
      (is (search "model:gpt-4" footer))
      (is (search "deliver:off" footer))
      (is (search "think:off" footer)))))

(test tui-format-footer-disconnected
  "Footer shows disconnected when client not connected."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (client (nilclaw/tui:make-local-tui-client runtime)))
    (let ((footer (nilclaw/tui:tui-format-footer client)))
      (is (search "disconnected" footer)))))

(test tui-format-help-output
  "tui-format-help includes all phase 1 commands."
  (let ((help (nilclaw/tui:tui-format-help)))
    (dolist (cmd '("/help" "/status" "/sessions" "/session" "/agents" "/agent"
                   "/models" "/model" "/new" "/reset" "/deliver" "/think"
                   "/verbose" "/reasoning" "/abort" "/exit"))
      (is (search cmd help) (format nil "Help should mention ~A" cmd)))))

;;; ====================================================================
;;; Phase 1 Parity: State persistence across commands
;;; ====================================================================

(test state-persists-across-commands
  "State changes persist across multiple slash commands."
  (let ((client (make-test-tui-client)))
    ;; Set multiple states
    (nilclaw/tui:tui-handle-slash-command client "/agent custom-agent")
    (nilclaw/tui:tui-handle-slash-command client "/model openai/gpt-4")
    (nilclaw/tui:tui-handle-slash-command client "/deliver on")
    (nilclaw/tui:tui-handle-slash-command client "/think high")
    (nilclaw/tui:tui-handle-slash-command client "/verbose full")
    (nilclaw/tui:tui-handle-slash-command client "/reasoning stream")
    ;; Verify all states
    (is (string= "custom-agent" (nilclaw/tui:local-tui-client-agent-id client)))
    (is (string= "openai/gpt-4" (nilclaw/tui:local-tui-client-model-id client)))
    (is (nilclaw/tui:local-tui-client-deliver-p client))
    (is (eq :high (nilclaw/tui:local-tui-client-think-level client)))
    (is (eq :full (nilclaw/tui:local-tui-client-verbose-mode client)))
    (is (eq :stream (nilclaw/tui:local-tui-client-reasoning-mode client)))
    ;; Status should reflect all
    (multiple-value-bind (status _) (nilclaw/tui:tui-handle-slash-command client "/status")
      (declare (ignore _))
      (is (search "custom-agent" status))
      (is (search "openai/gpt-4" status))
      (is (search "deliver:   on" status))
      (is (search "think:     high" status))
      (is (search "verbose:   full" status))
      (is (search "reasoning: stream" status)))))

;;; ====================================================================
;;; Phase 1 Parity: E2E — full session workflow
;;; ====================================================================

(test tui-e2e-session-workflow
  "E2E: connect → send → switch session → send → check history."
  (let ((client (make-test-tui-client :session-key "sess-a")))
    ;; Send in first session
    (nilclaw/tui:local-tui-send client "msg in a")
    (let ((hist-a (nilclaw/tui:local-tui-history client)))
      (is (>= (length hist-a) 2)))
    ;; Switch session
    (nilclaw/tui:tui-handle-slash-command client "/session sess-b")
    (is (string= "sess-b" (nilclaw/tui:local-tui-client-session-key client)))
    ;; Send in second session
    (nilclaw/tui:local-tui-send client "msg in b")
    ;; History in new session should have new messages
    (let ((hist-b (nilclaw/tui:local-tui-history client)))
      (is (>= (length hist-b) 2))
      ;; First message should be "msg in b"
      (is (string= "msg in b" (getf (first hist-b) :content))))))

(test tui-e2e-state-toggle-workflow
  "E2E: set toggles → verify status → verify footer."
  (let ((client (make-test-tui-client :session-key "toggle-test")))
    (nilclaw/tui:tui-handle-slash-command client "/deliver on")
    (nilclaw/tui:tui-handle-slash-command client "/think medium")
    (nilclaw/tui:tui-handle-slash-command client "/verbose on")
    (nilclaw/tui:tui-handle-slash-command client "/reasoning stream")
    ;; Status reflects toggles
    (let ((status (nilclaw/tui:tui-format-status client)))
      (is (search "deliver:   on" status))
      (is (search "think:     medium" status))
      (is (search "verbose:   on" status))
      (is (search "reasoning: stream" status)))
    ;; Footer reflects toggles
    (let ((footer (nilclaw/tui:tui-format-footer client)))
      (is (search "deliver:on" footer))
      (is (search "think:medium" footer))
      (is (search "verbose:on" footer))
      (is (search "reasoning:stream" footer)))))
