;;;; channel-tests.lisp - Channel system tests
;;;; NilClaw - Statically typed Common Lisp agent harness

(in-package #:nilclaw/tests)

(in-suite channel-suite)

;;; Channel manager tests

(test channel-manager-basics
  (let ((manager (nilclaw/channel:make-channel-manager)))
    (is (typep manager 'nilclaw/channel:channel-manager))
    (is (null (nilclaw/channel:find-channel manager "test")))))

(test channel-manager-register
  (let ((manager (nilclaw/channel:make-channel-manager))
        (channel (nilclaw/channel:make-cli-channel)))
    (nilclaw/channel:register-channel manager "cli" channel)
    (is (eq channel (nilclaw/channel:find-channel manager "cli")))
    (nilclaw/channel:unregister-channel manager "cli")
    (is (null (nilclaw/channel:find-channel manager "cli")))))

;;; CLI channel tests

(test cli-channel-lifecycle
  (let ((channel (nilclaw/channel:make-cli-channel)))
    (is (string= "cli" (nilclaw/channel:channel-name channel)))
    (is (not (nilclaw/channel:channel-health-check channel)))
    (nilclaw/channel:channel-start channel)
    (is (nilclaw/channel:channel-health-check channel))
    (nilclaw/channel:channel-stop channel)
    (is (not (nilclaw/channel:channel-health-check channel)))))

(test cli-channel-send
  (let ((channel (nilclaw/channel:make-cli-channel)))
    (nilclaw/channel:channel-start channel)
    ;; Sending to CLI just prints to stdout, so we test it doesn't error
    (is (nilclaw/channel:channel-send channel "user" "Hello, world!"))))

;;; Web channel tests

(test web-channel-creation
  (let ((channel (nilclaw/channel:make-web-channel
                  :path "/webhook"
                  :auth-token "secret123"
                  :allowed-origins '("https://example.com")
                  :transport :relay
                  :relay-url "wss://relay.example.com/ws"
                  :message-auth-mode :token)))
    (is (string= "web" (nilclaw/channel:channel-name channel)))
    (is (string= "/webhook" (nilclaw/channel:web-channel-path channel)))
    (is (string= "secret123" (nilclaw/channel:web-channel-auth-token channel)))
    (is (equal '("https://example.com")
               (nilclaw/channel:web-channel-allowed-origins channel)))
    (is (eq :relay (nilclaw/channel:web-channel-transport channel)))
    (is (string= "wss://relay.example.com/ws"
                 (nilclaw/channel:web-channel-relay-url channel)))
    (is (eq :token (nilclaw/channel:web-channel-message-auth-mode channel)))))

(test web-channel-lifecycle
  (let ((channel (nilclaw/channel:make-web-channel)))
    (is (not (nilclaw/channel:channel-health-check channel)))
    (nilclaw/channel:channel-start channel)
    (is (nilclaw/channel:channel-health-check channel))
    (nilclaw/channel:channel-stop channel)
    (is (not (nilclaw/channel:channel-health-check channel)))))

;;; Permission tests

(test dm-permission-allow
  (is (nilclaw/channel:check-dm-permission :allow "anyone" '())))

(test dm-permission-deny
  (is (not (nilclaw/channel:check-dm-permission :deny "anyone" '()))))

(test dm-permission-allowlist
  (let ((allowlist '("alice" "bob" "charlie")))
    (is (nilclaw/channel:check-dm-permission :allowlist "alice" allowlist))
    (is (not (nilclaw/channel:check-dm-permission :allowlist "eve" allowlist)))
    ;; Case-insensitive by default
    (is (nilclaw/channel:check-dm-permission :allowlist "ALICE" allowlist))
    ;; Case-sensitive when requested
    (is (not (nilclaw/channel:check-dm-permission :allowlist "ALICE" allowlist
                                                   :case-sensitive t)))))

(test group-permission-open
  (is (nilclaw/channel:check-group-permission :open "anyone" '() nil))
  (is (nilclaw/channel:check-group-permission :open "anyone" '() t)))

(test group-permission-mention-only
  (is (not (nilclaw/channel:check-group-permission :mention-only "anyone" '() nil)))
  (is (nilclaw/channel:check-group-permission :mention-only "anyone" '() t)))

(test group-permission-allowlist
  (let ((allowlist '("alice" "bob")))
    (is (nilclaw/channel:check-group-permission :allowlist "alice" allowlist nil))
    (is (not (nilclaw/channel:check-group-permission :allowlist "eve" allowlist nil)))))

(test check-permission-dispatch
  (let ((allowlist '("alice")))
    ;; DM tests
    (is (nilclaw/channel:check-permission :allow :open "anyone" allowlist nil nil))
    (is (not (nilclaw/channel:check-permission :deny :open "anyone" allowlist nil nil)))
    (is (nilclaw/channel:check-permission :allowlist :open "alice" allowlist nil nil))
    ;; Group tests
    (is (nilclaw/channel:check-permission :allow :open "anyone" allowlist t nil))
    (is (not (nilclaw/channel:check-permission :allow :mention-only "anyone" allowlist t nil)))
    (is (nilclaw/channel:check-permission :allow :mention-only "anyone" allowlist t t))))

;;; Channel message tests

(test channel-message-creation
  (let ((msg (nilclaw/channel:make-channel-message
              "msg-123" "alice" "Hello!" "cli")))
    (is (string= "msg-123" (nilclaw/channel:channel-message-id msg)))
    (is (string= "alice" (nilclaw/channel:channel-message-sender msg)))
    (is (string= "Hello!" (nilclaw/channel:channel-message-content msg)))
    (is (string= "cli" (nilclaw/channel:channel-message-channel msg)))
    (is (= 0 (nilclaw/channel:channel-message-timestamp msg)))
    (is (null (nilclaw/channel:channel-message-reply-target msg)))
    (is (null (nilclaw/channel:channel-message-is-group msg)))))

(test channel-message-with-optional-fields
  (let ((msg (nilclaw/channel:make-channel-message
              "msg-456" "bob" "Group message" "telegram"
              :timestamp 1234567890
              :reply-target "chat-789"
              :message-id 42
              :first-name "Bob"
              :is-group t
              :sender-uuid "uuid-1234"
              :group-id "group-5678")))
    (is (= 1234567890 (nilclaw/channel:channel-message-timestamp msg)))
    (is (string= "chat-789" (nilclaw/channel:channel-message-reply-target msg)))
    (is (= 42 (nilclaw/channel:channel-message-message-id msg)))
    (is (string= "Bob" (nilclaw/channel:channel-message-first-name msg)))
    (is (nilclaw/channel:channel-message-is-group msg))
    (is (string= "uuid-1234" (nilclaw/channel:channel-message-sender-uuid msg)))
    (is (string= "group-5678" (nilclaw/channel:channel-message-group-id msg)))))

;;; Multi-channel tests

(test multi-channel-start-stop
  (let ((manager (nilclaw/channel:make-channel-manager))
        (cli (nilclaw/channel:make-cli-channel))
        (web (nilclaw/channel:make-web-channel)))
    (nilclaw/channel:register-channel manager "cli" cli)
    (nilclaw/channel:register-channel manager "web" web)
    ;; Start all
    (nilclaw/channel:start-all-channels manager)
    (is (nilclaw/channel:channel-health-check cli))
    (is (nilclaw/channel:channel-health-check web))
    ;; Stop all
    (nilclaw/channel:stop-all-channels manager)
    (is (not (nilclaw/channel:channel-health-check cli)))
    (is (not (nilclaw/channel:channel-health-check web)))))

(test health-check-all
  (let ((manager (nilclaw/channel:make-channel-manager))
        (cli (nilclaw/channel:make-cli-channel))
        (web (nilclaw/channel:make-web-channel)))
    (nilclaw/channel:register-channel manager "cli" cli)
    (nilclaw/channel:register-channel manager "web" web)
    (nilclaw/channel:start-all-channels manager)
    (let ((results (nilclaw/channel:health-check-all manager)))
      (is (= 2 (length results)))
      (is (every #'cdr results)))))
