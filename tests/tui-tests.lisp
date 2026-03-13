;;;; tui-tests.lisp — Tests for NilClaw native TUI client
;;;; NilClaw - Statically typed Common Lisp agent harness

(in-package #:nilclaw/tests)
(in-suite tui-suite)

;;; --- Entrypoint availability ---

(test tui-entrypoint-available
  "TUI entrypoint must be available."
  (is (nilclaw/tui:tui-entrypoint-available-p)))

;;; --- Local TUI client lifecycle ---

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

;;; --- Send/receive through TUI path ---

(test local-tui-send-receive
  "Local TUI client can send a message and receive a response."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (client (nilclaw/tui:make-local-tui-client runtime :session-key "test-chat")))
    (nilclaw/tui:local-tui-connect client)
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

;;; --- History through TUI path ---

(test local-tui-history-retrieval
  "Local TUI client can retrieve chat history after sending messages."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (client (nilclaw/tui:make-local-tui-client runtime :session-key "test-history")))
    (nilclaw/tui:local-tui-connect client)
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

;;; --- Multi-turn conversation ---

(test local-tui-multi-turn
  "Local TUI client supports multi-turn conversation."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (client (nilclaw/tui:make-local-tui-client runtime :session-key "test-multi")))
    (nilclaw/tui:local-tui-connect client)
    ;; Send multiple messages
    (multiple-value-bind (r1 s1) (nilclaw/tui:local-tui-send client "turn one")
      (is-true s1)
      (is (stringp r1)))
    (multiple-value-bind (r2 s2) (nilclaw/tui:local-tui-send client "turn two")
      (is-true s2)
      (is (stringp r2)))
    ;; History should have 4 messages (2 user + 2 assistant)
    (let ((history (nilclaw/tui:local-tui-history client)))
      (is (>= (length history) 4)))))

;;; --- Remote TUI client type ---

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
