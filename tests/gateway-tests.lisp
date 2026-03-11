(in-package #:nilclaw/tests)
(in-suite gateway-suite)

;;; --- Backward-compatible tests (existing) ---

(test gateway-runtime-ready
  (is (nilclaw/gateway:gateway-runtime-ready-p))
  (is (not (nilclaw/gateway:gateway-runtime-ready-p
            (nilclaw/gateway:make-gateway-runtime :name "" :enabled t :port 3000))))
  (is (not (nilclaw/gateway:gateway-runtime-ready-p
            (nilclaw/gateway:make-gateway-runtime :name "gw" :enabled nil :port 3000)))))

(test gateway-handle-request-success-and-errors
  (let* ((ok (nilclaw/gateway:gateway-handle-request
              (nilclaw/gateway:make-gateway-request :id "1" :method "ping" :params '())))
         (unknown (nilclaw/gateway:gateway-handle-request
                   (nilclaw/gateway:make-gateway-request :id "2" :method "whoami" :params '())))
         (malformed (nilclaw/gateway:gateway-handle-request
                     (nilclaw/gateway:make-gateway-request :id "" :method "ping" :params '()))))
    (is (nilclaw/gateway:gateway-response-ok-p ok))
    (is (equal '(:pong t) (nilclaw/gateway:gateway-response-result ok)))
    (is (not (nilclaw/gateway:gateway-response-ok-p unknown)))
    (is (eq :unknown-method (nilclaw/gateway:gateway-response-error-code unknown)))
    (is (not (nilclaw/gateway:gateway-response-ok-p malformed)))
    (is (eq :malformed-request (nilclaw/gateway:gateway-response-error-code malformed)))))

;;; --- Connect challenge flow ---

(test gateway-connect-challenge-produces-nonce
  "connect.challenge event must contain a non-empty nonce."
  (let ((runtime (nilclaw/gateway:make-gateway-runtime)))
    (multiple-value-bind (event conn)
        (nilclaw/gateway:gateway-make-challenge runtime)
      (is (string= "connect.challenge" (nilclaw/gateway:gateway-event-event event)))
      (let ((nonce (getf (nilclaw/gateway:gateway-event-payload event) :nonce)))
        (is (stringp nonce))
        (is (> (length nonce) 0)))
      (is (stringp (nilclaw/gateway:gateway-connection-nonce conn)))
      (is (not (nilclaw/gateway:gateway-connection-authenticated conn))))))

(test gateway-connect-method-authenticates
  "connect method with valid protocol should authenticate and return policy."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (conn (nilclaw/gateway:make-gateway-connection :nonce "test-nonce"))
         (params (list :min-protocol 3 :max-protocol 3
                       :client (list :id "test-client" :display-name "Test")))
         (resp (nilclaw/gateway:handle-connect runtime "req-1" params conn)))
    (is (nilclaw/gateway:gateway-response-ok-p resp))
    (is (string= "req-1" (nilclaw/gateway:gateway-response-id resp)))
    ;; Connection should be authenticated
    (is (nilclaw/gateway:gateway-connection-authenticated conn))
    (is (string= "test-client" (nilclaw/gateway:gateway-connection-client-id conn)))
    ;; Result should contain policy with tickIntervalMs
    (let* ((result (nilclaw/gateway:gateway-response-result resp))
           (proto (getf result :protocol))
           (policy (getf result :policy))
           (tick-ms (getf policy :tick-interval-ms)))
      (is (= 3 proto))
      (is (numberp tick-ms))
      (is (> tick-ms 0)))))

(test gateway-connect-protocol-mismatch
  "connect with incompatible protocol version should fail."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (conn (nilclaw/gateway:make-gateway-connection :nonce "test-nonce"))
         (params (list :min-protocol 4 :max-protocol 5))
         (resp (nilclaw/gateway:handle-connect runtime "req-2" params conn)))
    (is (not (nilclaw/gateway:gateway-response-ok-p resp)))
    (is (eq :protocol-mismatch (nilclaw/gateway:gateway-response-error-code resp)))))

(test gateway-connect-without-connection-state
  "connect method without connection state should fail gracefully."
  (let ((resp (nilclaw/gateway:gateway-handle-request
               (nilclaw/gateway:make-gateway-request :id "r1" :method "connect" :params '()))))
    (is (not (nilclaw/gateway:gateway-response-ok-p resp)))
    (is (eq :no-connection (nilclaw/gateway:gateway-response-error-code resp)))))

;;; --- Full handshake flow ---

(test gateway-full-handshake-flow
  "Complete challenge -> connect flow should produce authenticated connection."
  (let ((runtime (nilclaw/gateway:make-gateway-runtime)))
    ;; Step 1: Gateway emits challenge
    (multiple-value-bind (challenge-event conn)
        (nilclaw/gateway:gateway-make-challenge runtime)
      (declare (ignorable challenge-event))
      ;; Step 2: Client sends connect with nonce
      (let* ((params (list :min-protocol 3 :max-protocol 3
                           :client (list :id "openclaw.el"
                                         :display-name "openclaw.el")))
             (resp (nilclaw/gateway:gateway-handle-request
                    (nilclaw/gateway:make-gateway-request
                     :id "handshake-1" :method "connect" :params params)
                    runtime conn)))
        (is (nilclaw/gateway:gateway-response-ok-p resp))
        (is (nilclaw/gateway:gateway-connection-authenticated conn))))))

;;; --- Ping ---

(test gateway-ping-returns-pong
  "ping method always returns (:pong t)."
  (let ((resp (nilclaw/gateway:gateway-handle-request
               (nilclaw/gateway:make-gateway-request :id "p1" :method "ping" :params '()))))
    (is (nilclaw/gateway:gateway-response-ok-p resp))
    (is (equal '(:pong t) (nilclaw/gateway:gateway-response-result resp)))))

;;; --- sessions.list ---

(test gateway-sessions-list-empty
  "sessions.list on fresh runtime returns empty sessions list."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (resp (nilclaw/gateway:gateway-handle-request
                (nilclaw/gateway:make-gateway-request :id "s1" :method "sessions.list" :params '())
                runtime)))
    (is (nilclaw/gateway:gateway-response-ok-p resp))
    (is (equal nil (getf (nilclaw/gateway:gateway-response-result resp) :sessions)))))

(test gateway-sessions-list-with-data
  "sessions.list returns sessions that were registered."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime)))
    ;; Add sessions
    (nilclaw/gateway:gateway-ensure-session runtime "sess-1" "Session One" "agent-a")
    (nilclaw/gateway:gateway-ensure-session runtime "sess-2" "Session Two" "agent-b")
    (let ((resp (nilclaw/gateway:gateway-handle-request
                 (nilclaw/gateway:make-gateway-request :id "s2" :method "sessions.list" :params '())
                 runtime)))
      (is (nilclaw/gateway:gateway-response-ok-p resp))
      (let ((sessions (getf (nilclaw/gateway:gateway-response-result resp) :sessions)))
        (is (= 2 (length sessions)))))))

(test gateway-sessions-list-respects-limit
  "sessions.list with :limit param should cap the returned count."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime)))
    (dotimes (i 5)
      (nilclaw/gateway:gateway-ensure-session
       runtime (format nil "s-~A" i) (format nil "Session ~A" i) "agent"))
    (let ((resp (nilclaw/gateway:gateway-handle-request
                 (nilclaw/gateway:make-gateway-request
                  :id "s3" :method "sessions.list" :params (list :limit 3))
                 runtime)))
      (is (nilclaw/gateway:gateway-response-ok-p resp))
      (is (<= (length (getf (nilclaw/gateway:gateway-response-result resp) :sessions)) 3)))))

;;; --- agents.list ---

(test gateway-agents-list-empty
  "agents.list on fresh runtime returns empty."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (resp (nilclaw/gateway:gateway-handle-request
                (nilclaw/gateway:make-gateway-request :id "a1" :method "agents.list" :params '())
                runtime)))
    (is (nilclaw/gateway:gateway-response-ok-p resp))
    (is (equal nil (getf (nilclaw/gateway:gateway-response-result resp) :agents)))))

(test gateway-agents-list-with-data
  "agents.list returns registered agents."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime
                   :agents (list (nilclaw/gateway:make-gateway-agent
                                  :id "agent-1" :display-name "Alpha")
                                 (nilclaw/gateway:make-gateway-agent
                                  :id "agent-2" :display-name "Beta"))))
         (resp (nilclaw/gateway:gateway-handle-request
                (nilclaw/gateway:make-gateway-request :id "a2" :method "agents.list" :params '())
                runtime)))
    (is (nilclaw/gateway:gateway-response-ok-p resp))
    (let ((agents (getf (nilclaw/gateway:gateway-response-result resp) :agents)))
      (is (= 2 (length agents)))
      ;; Check first agent has expected structure
      (let ((first-agent (first agents)))
        (is (stringp (getf first-agent :id)))
        (is (stringp (getf first-agent :display-name)))))))

;;; --- chat.send ---

(test gateway-chat-send-success
  "chat.send with valid sessionKey and message returns queued ack."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime)))
    (nilclaw/gateway:gateway-ensure-session runtime "chat-sess" "Chat Session" "agent-1")
    (let ((resp (nilclaw/gateway:gateway-handle-request
                 (nilclaw/gateway:make-gateway-request
                  :id "c1" :method "chat.send"
                  :params (list :session-key "chat-sess"
                                :message "Hello, world!"
                                :idempotency-key "idem-1"))
                 runtime)))
      (is (nilclaw/gateway:gateway-response-ok-p resp))
      (is (getf (nilclaw/gateway:gateway-response-result resp) :queued)))))

(test gateway-chat-send-stores-messages
  "chat.send should store both user and assistant messages in session."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime)))
    (nilclaw/gateway:gateway-ensure-session runtime "chat-sess" "Chat Session" "agent-1")
    (nilclaw/gateway:gateway-handle-request
     (nilclaw/gateway:make-gateway-request
      :id "c2" :method "chat.send"
      :params (list :session-key "chat-sess" :message "Hello!"))
     runtime)
    ;; Check messages stored
    (let* ((session (find "chat-sess" (nilclaw/gateway:gateway-runtime-sessions runtime)
                          :key #'nilclaw/gateway:gateway-session-key :test #'string=))
           (msgs (nilclaw/gateway:gateway-session-messages session)))
      (is (= 2 (length msgs)))
      (is (string= "user" (nilclaw/gateway:gateway-message-role (first msgs))))
      (is (string= "Hello!" (nilclaw/gateway:gateway-message-content (first msgs))))
      (is (string= "assistant" (nilclaw/gateway:gateway-message-role (second msgs)))))))

(test gateway-chat-send-emits-events
  "chat.send should emit chat.message and sessions.update events."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime)))
    (nilclaw/gateway:gateway-ensure-session runtime "chat-sess" "Chat Session" "agent-1")
    (nilclaw/gateway:gateway-handle-request
     (nilclaw/gateway:make-gateway-request
      :id "c3" :method "chat.send"
      :params (list :session-key "chat-sess" :message "Hi"))
     runtime)
    ;; Check event log (reversed because push)
    (let* ((events (reverse (nilclaw/gateway:gateway-runtime-event-log runtime)))
           (first-event (cdr (first events)))
           (second-event (cdr (second events))))
      (is (= 2 (length events)))
      (is (string= "chat.message"
                    (nilclaw/gateway:gateway-method-event-method first-event)))
      (is (string= "sessions.update"
                    (nilclaw/gateway:gateway-method-event-method second-event))))))

(test gateway-chat-send-auto-creates-session
  "chat.send to unknown session should auto-create it."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (resp (nilclaw/gateway:gateway-handle-request
                (nilclaw/gateway:make-gateway-request
                 :id "c4" :method "chat.send"
                 :params (list :session-key "new-sess" :message "Hey"))
                runtime)))
    (is (nilclaw/gateway:gateway-response-ok-p resp))
    ;; Session should exist now
    (is (= 1 (length (nilclaw/gateway:gateway-runtime-sessions runtime))))))

(test gateway-chat-send-missing-session-key
  "chat.send without sessionKey should fail."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (resp (nilclaw/gateway:gateway-handle-request
                (nilclaw/gateway:make-gateway-request
                 :id "c5" :method "chat.send"
                 :params (list :message "Hello"))
                runtime)))
    (is (not (nilclaw/gateway:gateway-response-ok-p resp)))
    (is (eq :malformed-request (nilclaw/gateway:gateway-response-error-code resp)))))

(test gateway-chat-send-missing-message
  "chat.send without message should fail."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (resp (nilclaw/gateway:gateway-handle-request
                (nilclaw/gateway:make-gateway-request
                 :id "c6" :method "chat.send"
                 :params (list :session-key "s1"))
                runtime)))
    (is (not (nilclaw/gateway:gateway-response-ok-p resp)))
    (is (eq :malformed-request (nilclaw/gateway:gateway-response-error-code resp)))))

;;; --- chat.history ---

(test gateway-chat-history-empty-session
  "chat.history for session with no messages returns empty list."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime)))
    (nilclaw/gateway:gateway-ensure-session runtime "h-sess" "History" "agent-1")
    (let ((resp (nilclaw/gateway:gateway-handle-request
                 (nilclaw/gateway:make-gateway-request
                  :id "h1" :method "chat.history"
                  :params (list :session-key "h-sess"))
                 runtime)))
      (is (nilclaw/gateway:gateway-response-ok-p resp))
      (is (equal nil (getf (nilclaw/gateway:gateway-response-result resp) :messages))))))

(test gateway-chat-history-returns-messages
  "chat.history returns messages that were sent via chat.send."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime)))
    (nilclaw/gateway:gateway-ensure-session runtime "h-sess" "History" "agent-1")
    ;; Send two messages
    (nilclaw/gateway:gateway-handle-request
     (nilclaw/gateway:make-gateway-request
      :id "h2a" :method "chat.send"
      :params (list :session-key "h-sess" :message "First"))
     runtime)
    (nilclaw/gateway:gateway-handle-request
     (nilclaw/gateway:make-gateway-request
      :id "h2b" :method "chat.send"
      :params (list :session-key "h-sess" :message "Second"))
     runtime)
    ;; Fetch history
    (let ((resp (nilclaw/gateway:gateway-handle-request
                 (nilclaw/gateway:make-gateway-request
                  :id "h2c" :method "chat.history"
                  :params (list :session-key "h-sess"))
                 runtime)))
      (is (nilclaw/gateway:gateway-response-ok-p resp))
      (let ((messages (getf (nilclaw/gateway:gateway-response-result resp) :messages)))
        ;; 2 sends × 2 messages each (user + assistant echo) = 4
        (is (= 4 (length messages)))
        ;; First message should be user/First
        (is (string= "user" (getf (first messages) :role)))
        (is (string= "First" (getf (first messages) :content)))))))

(test gateway-chat-history-respects-limit
  "chat.history with limit returns only the last N messages."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime)))
    (nilclaw/gateway:gateway-ensure-session runtime "h-sess" "History" "agent-1")
    (dotimes (i 5)
      (nilclaw/gateway:gateway-handle-request
       (nilclaw/gateway:make-gateway-request
        :id (format nil "h3-~A" i) :method "chat.send"
        :params (list :session-key "h-sess"
                      :message (format nil "Msg ~A" i)))
       runtime))
    ;; 5 sends × 2 = 10 messages; limit to 4
    (let ((resp (nilclaw/gateway:gateway-handle-request
                 (nilclaw/gateway:make-gateway-request
                  :id "h3-fetch" :method "chat.history"
                  :params (list :session-key "h-sess" :limit 4))
                 runtime)))
      (is (nilclaw/gateway:gateway-response-ok-p resp))
      (is (= 4 (length (getf (nilclaw/gateway:gateway-response-result resp) :messages)))))))

(test gateway-chat-history-nonexistent-session
  "chat.history for unknown session returns empty messages."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (resp (nilclaw/gateway:gateway-handle-request
                (nilclaw/gateway:make-gateway-request
                 :id "h4" :method "chat.history"
                 :params (list :session-key "no-such-session"))
                runtime)))
    (is (nilclaw/gateway:gateway-response-ok-p resp))
    (is (equal nil (getf (nilclaw/gateway:gateway-response-result resp) :messages)))))

(test gateway-chat-history-missing-session-key
  "chat.history without sessionKey should fail."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (resp (nilclaw/gateway:gateway-handle-request
                (nilclaw/gateway:make-gateway-request
                 :id "h5" :method "chat.history"
                 :params '())
                runtime)))
    (is (not (nilclaw/gateway:gateway-response-ok-p resp)))
    (is (eq :malformed-request (nilclaw/gateway:gateway-response-error-code resp)))))

;;; --- models.list ---

(test gateway-models-list-empty
  "models.list on fresh runtime returns empty."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (resp (nilclaw/gateway:gateway-handle-request
                (nilclaw/gateway:make-gateway-request :id "m1" :method "models.list" :params '())
                runtime)))
    (is (nilclaw/gateway:gateway-response-ok-p resp))
    (is (equal nil (getf (nilclaw/gateway:gateway-response-result resp) :models)))))

(test gateway-models-list-with-data
  "models.list returns registered models with correct structure."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime
                   :models (list (nilclaw/gateway:make-gateway-model
                                  :id "claude-3" :name "Claude 3" :provider "anthropic")
                                 (nilclaw/gateway:make-gateway-model
                                  :id "gpt-4" :name "GPT-4" :provider "openai"))))
         (resp (nilclaw/gateway:gateway-handle-request
                (nilclaw/gateway:make-gateway-request :id "m2" :method "models.list" :params '())
                runtime)))
    (is (nilclaw/gateway:gateway-response-ok-p resp))
    (let ((models (getf (nilclaw/gateway:gateway-response-result resp) :models)))
      (is (= 2 (length models)))
      (let ((first-model (first models)))
        (is (string= "claude-3" (getf first-model :id)))
        (is (string= "Claude 3" (getf first-model :name)))
        (is (string= "anthropic" (getf first-model :provider)))))))

;;; --- Event ordering ---

(test gateway-event-ordering-on-chat
  "Events emitted by chat.send should be in deterministic order: chat.message then sessions.update."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime)))
    (nilclaw/gateway:gateway-ensure-session runtime "ord-sess" "Order Test" "agent-1")
    (nilclaw/gateway:gateway-handle-request
     (nilclaw/gateway:make-gateway-request
      :id "ord-1" :method "chat.send"
      :params (list :session-key "ord-sess" :message "Order test"))
     runtime)
    ;; Events pushed in reverse order; reverse to get emission order
    (let* ((events (reverse (nilclaw/gateway:gateway-runtime-event-log runtime))))
      (is (>= (length events) 2))
      (is (string= "chat.message"
                    (nilclaw/gateway:gateway-method-event-method (cdr (first events)))))
      (is (string= "sessions.update"
                    (nilclaw/gateway:gateway-method-event-method (cdr (second events))))))))

(test gateway-multiple-sends-preserve-event-order
  "Multiple chat.send calls should accumulate events in order."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime)))
    (nilclaw/gateway:gateway-ensure-session runtime "multi-sess" "Multi" "agent-1")
    (dotimes (i 3)
      (nilclaw/gateway:gateway-handle-request
       (nilclaw/gateway:make-gateway-request
        :id (format nil "multi-~A" i) :method "chat.send"
        :params (list :session-key "multi-sess"
                      :message (format nil "Msg ~A" i)))
       runtime))
    ;; 3 sends × 2 events each = 6
    (is (= 6 (length (nilclaw/gateway:gateway-runtime-event-log runtime))))
    ;; Check alternating pattern (reversed log)
    (let ((events (reverse (nilclaw/gateway:gateway-runtime-event-log runtime))))
      (loop for i from 0 below 6 by 2
            do (is (string= "chat.message"
                            (nilclaw/gateway:gateway-method-event-method
                             (cdr (nth i events)))))
               (is (string= "sessions.update"
                            (nilclaw/gateway:gateway-method-event-method
                             (cdr (nth (1+ i) events)))))))))

;;; --- Malformed request edge cases ---

(test gateway-missing-method-rejected
  "Request with empty method should be rejected."
  (let ((resp (nilclaw/gateway:gateway-handle-request
               (nilclaw/gateway:make-gateway-request :id "e1" :method "" :params '()))))
    (is (not (nilclaw/gateway:gateway-response-ok-p resp)))
    (is (eq :malformed-request (nilclaw/gateway:gateway-response-error-code resp)))))

(test gateway-missing-id-rejected
  "Request with empty id should be rejected."
  (let ((resp (nilclaw/gateway:gateway-handle-request
               (nilclaw/gateway:make-gateway-request :id "" :method "ping" :params '()))))
    (is (not (nilclaw/gateway:gateway-response-ok-p resp)))
    (is (eq :malformed-request (nilclaw/gateway:gateway-response-error-code resp)))))

;;; --- Nonce uniqueness ---

(test gateway-nonce-uniqueness
  "Multiple challenge calls should produce different nonces."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (nonces (loop repeat 10
                       collect (multiple-value-bind (_event conn)
                                   (nilclaw/gateway:gateway-make-challenge runtime)
                                 (declare (ignorable _event))
                                 (nilclaw/gateway:gateway-connection-nonce conn)))))
    ;; All nonces should be unique (high probability with random component)
    (is (= 10 (length (remove-duplicates nonces :test #'string=))))))
