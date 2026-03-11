(in-package #:nilclaw/tests)
(in-suite gateway-suite)

(defun method-events-in-emission-order (runtime)
  "Return method events from RUNTIME event log in emission order."
  (declare (type nilclaw/gateway:gateway-runtime runtime))
  (loop for raw in (reverse (nilclaw/gateway:gateway-runtime-event-log runtime))
        when (and (consp raw) (eq (car raw) :method-event))
          collect (cdr raw)))

(defun chat-events-in-emission-order (runtime)
  "Return `event: chat` gateway events from RUNTIME in emission order."
  (declare (type nilclaw/gateway:gateway-runtime runtime))
  (loop for raw in (reverse (nilclaw/gateway:gateway-runtime-event-log runtime))
        when (and (typep raw 'nilclaw/gateway:gateway-event)
                  (string= "chat" (nilclaw/gateway:gateway-event-event raw)))
          collect raw))

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
           (tick-ms (getf policy :tick-interval-ms))
           (tick-ms-camel (getf policy :|tickIntervalMs|)))
      (is (= 3 proto))
      (is (integerp (getf result :timestamp)))
      (is (numberp tick-ms))
      (is (= tick-ms tick-ms-camel))
      (is (> tick-ms 0)))))

(test gateway-connect-method-authenticates-camelcase-params
  "connect method should also accept camelCase protocol/client fields."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (conn (nilclaw/gateway:make-gateway-connection :nonce "test-nonce"))
         (params (list :|minProtocol| 3 :|maxProtocol| 3
                       :client (list :|id| "camel-client" :|displayName| "Camel")))
         (resp (nilclaw/gateway:handle-connect runtime "req-1b" params conn)))
    (is (nilclaw/gateway:gateway-response-ok-p resp))
    (is (string= "req-1b" (nilclaw/gateway:gateway-response-id resp)))
    (is (nilclaw/gateway:gateway-connection-authenticated conn))
    (is (string= "camel-client" (nilclaw/gateway:gateway-connection-client-id conn)))
    (is (string= "Camel" (nilclaw/gateway:gateway-connection-client-display-name conn)))
    (let* ((result (nilclaw/gateway:gateway-response-result resp))
           (policy (getf result :policy)))
      (is (listp result))
      (is (= 3 (getf result :protocol)))
      (is (integerp (getf result :timestamp)))
      (is (numberp (getf policy :tick-interval-ms)))
      (is (= (getf policy :tick-interval-ms)
             (getf policy :|tickIntervalMs|))))))

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
    (let ((result (nilclaw/gateway:gateway-response-result resp)))
      (is (integerp (getf result :timestamp)))
      (is (listp result))
      (is (equal nil (getf result :sessions))))))

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
      (let* ((result (nilclaw/gateway:gateway-response-result resp))
             (sessions (getf result :sessions))
             (first-session (first sessions)))
        (is (integerp (getf result :timestamp)))
        (is (= 2 (length sessions)))
        (is (string= (getf first-session :session-key)
                     (getf first-session :|sessionKey|)))
        (is (string= (getf first-session :key)
                     (or (getf first-session :session-key)
                         (getf first-session :|sessionKey|))))
        (is (stringp (getf first-session :label)))
        (is (string= (getf first-session :agent-id)
                     (getf first-session :|agentId|)))
        (is (integerp (getf first-session :timestamp)))))))

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
      (let* ((result (nilclaw/gateway:gateway-response-result resp))
             (sessions (getf result :sessions)))
        (is (integerp (getf result :timestamp)))
        (is (<= (length sessions) 3))))))

;;; --- agents.list ---

(test gateway-agents-list-empty
  "agents.list on fresh runtime returns empty."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (resp (nilclaw/gateway:gateway-handle-request
                (nilclaw/gateway:make-gateway-request :id "a1" :method "agents.list" :params '())
                runtime)))
    (is (nilclaw/gateway:gateway-response-ok-p resp))
    (let ((result (nilclaw/gateway:gateway-response-result resp)))
      (is (integerp (getf result :timestamp)))
      (is (listp result))
      (is (equal nil (getf result :agents))))))

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
    (let* ((result (nilclaw/gateway:gateway-response-result resp))
           (agents (getf result :agents)))
      (is (integerp (getf result :timestamp)))
      (is (= 2 (length agents)))
      ;; Check first agent has expected structure
      (let ((first-agent (first agents)))
        (is (stringp (getf first-agent :id)))
        (is (stringp (getf first-agent :display-name)))
        (is (string= (getf first-agent :display-name)
                     (getf first-agent :|displayName|)))
        (is (integerp (getf first-agent :timestamp)))))))

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
  "chat.send should emit chat.message and sessions.update method events."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime)))
    (nilclaw/gateway:gateway-ensure-session runtime "chat-sess" "Chat Session" "agent-1")
    (nilclaw/gateway:gateway-handle-request
     (nilclaw/gateway:make-gateway-request
      :id "c3" :method "chat.send"
      :params (list :session-key "chat-sess" :message "Hi"))
     runtime)
    (let* ((method-events (method-events-in-emission-order runtime))
           (first-event (first method-events))
           (second-event (second method-events)))
      (is (= 2 (length method-events)))
      (is (string= "chat.message"
                    (nilclaw/gateway:gateway-method-event-method first-event)))
      (let* ((chat-params (nilclaw/gateway:gateway-method-event-params first-event))
             (parts (getf chat-params :content-parts)))
        (is (string= "assistant" (getf chat-params :role)))
        (is (integerp (getf chat-params :timestamp)))
        (is (listp parts))
        (is (string= "text" (getf (first parts) :type)))
        (is (stringp (getf (first parts) :text))))
      (is (string= "sessions.update"
                    (nilclaw/gateway:gateway-method-event-method second-event)))
      (let ((session-params (nilclaw/gateway:gateway-method-event-params second-event)))
        (is (string= "chat-sess" (or (getf session-params :session-key)
                                       (getf session-params :|sessionKey|))))
        (is (string= "Chat Session" (getf session-params :label)))
        (is (integerp (getf session-params :timestamp)))))))

(test gateway-chat-send-emits-chat-streaming-events
  "chat.send should emit event=chat frames with state=delta and state=final."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime)))
    (nilclaw/gateway:gateway-ensure-session runtime "chat-sess" "Chat Session" "agent-1")
    (nilclaw/gateway:gateway-handle-request
     (nilclaw/gateway:make-gateway-request
      :id "c3-stream" :method "chat.send"
      :params (list :session-key "chat-sess" :message "Hi"))
     runtime)
    (let* ((chat-events (chat-events-in-emission-order runtime))
           (delta (first chat-events))
           (final (second chat-events))
           (delta-payload (nilclaw/gateway:gateway-event-payload delta))
           (final-payload (nilclaw/gateway:gateway-event-payload final))
           (delta-message (getf delta-payload :message))
           (final-message (getf final-payload :message)))
      (is (= 2 (length chat-events)))
      (is (string= "delta" (getf delta-payload :state)))
      (is (string= "final" (getf final-payload :state)))
      (is (integerp (getf delta-payload :timestamp)))
      (is (integerp (getf final-payload :timestamp)))
      (is (integerp (getf delta-message :timestamp)))
      (is (integerp (getf final-message :timestamp)))
      (is (string= "chat-sess" (or (getf delta-payload :session-key)
                                    (getf delta-payload :|sessionKey|))))
      (is (string= "chat-sess" (or (getf final-payload :session-key)
                                    (getf final-payload :|sessionKey|))))
      (is (listp (getf delta-message :content)))
      (is (string= "text" (getf (first (getf delta-message :content)) :type)))
      (is (stringp (getf (first (getf final-message :content)) :text))))))

(test gateway-chat-send-emits-chat-error-event
  "chat.send internal failures should emit event=chat with state=error envelope."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (resp nil))
    (nilclaw/gateway:gateway-ensure-session runtime "chat-sess" "Chat Session" "agent-1")
    (setf resp
          (nilclaw/gateway:gateway-handle-request
           (nilclaw/gateway:make-gateway-request
            :id "c3-stream-error" :method "chat.send"
            :params (list :session-key "chat-sess" :message "__force_chat_error__"))
           runtime))
    (let* ((chat-events (chat-events-in-emission-order runtime))
           (err (first chat-events))
           (payload (nilclaw/gateway:gateway-event-payload err)))
      (is (not (nilclaw/gateway:gateway-response-ok-p resp)))
      (is (eq :internal-error (nilclaw/gateway:gateway-response-error-code resp)))
      (is (= 1 (length chat-events)))
      (is (string= "error" (getf payload :state)))
      (is (integerp (getf payload :timestamp)))
      (is (string= "chat-sess" (or (getf payload :session-key)
                                    (getf payload :|sessionKey|))))
      (is (stringp (getf (getf payload :error) :message))))))

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
      (let ((result (nilclaw/gateway:gateway-response-result resp)))
        (is (string= "h-sess" (or (getf result :session-key)
                                   (getf result :|sessionKey|))))
        (is (integerp (getf result :timestamp)))
        (is (equal nil (getf result :messages)))))))

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
      (let* ((result (nilclaw/gateway:gateway-response-result resp))
             (messages (getf result :messages))
             (first-message (first messages))
             (parts (or (getf first-message :content-parts)
                        (getf first-message :|contentParts|))))
        (is (string= "h-sess" (or (getf result :session-key)
                                   (getf result :|sessionKey|))))
        (is (integerp (getf result :timestamp)))
        ;; 2 sends × 2 messages each (user + assistant echo) = 4
        (is (= 4 (length messages)))
        ;; First message should be user/First
        (is (string= "user" (getf first-message :role)))
        (is (string= "First" (getf first-message :content)))
        (is (integerp (getf first-message :timestamp)))
        (is (listp parts))
        (is (string= "text" (getf (first parts) :type)))
        (is (string= "First" (getf (first parts) :text)))))))

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
      (let ((result (nilclaw/gateway:gateway-response-result resp)))
        (is (string= "h-sess" (or (getf result :session-key)
                                   (getf result :|sessionKey|))))
        (is (integerp (getf result :timestamp)))
        (is (= 4 (length (getf result :messages))))))))

(test gateway-chat-history-nonexistent-session
  "chat.history for unknown session returns empty messages."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (resp (nilclaw/gateway:gateway-handle-request
                (nilclaw/gateway:make-gateway-request
                 :id "h4" :method "chat.history"
                 :params (list :session-key "no-such-session"))
                runtime)))
    (is (nilclaw/gateway:gateway-response-ok-p resp))
    (let ((result (nilclaw/gateway:gateway-response-result resp)))
      (is (string= "no-such-session" (or (getf result :session-key)
                                           (getf result :|sessionKey|))))
      (is (integerp (getf result :timestamp)))
      (is (equal nil (getf result :messages))))))

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
    (let ((result (nilclaw/gateway:gateway-response-result resp)))
      (is (integerp (getf result :timestamp)))
      (is (listp result))
      (is (equal nil (getf result :models))))))

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
    (let* ((result (nilclaw/gateway:gateway-response-result resp))
           (models (getf result :models)))
      (is (integerp (getf result :timestamp)))
      (is (= 2 (length models)))
      (let ((first-model (first models)))
        (is (string= "claude-3" (getf first-model :id)))
        (is (string= "Claude 3" (getf first-model :name)))
        (is (string= "anthropic" (getf first-model :provider)))
        (is (integerp (getf first-model :timestamp)))
        (is (<= (getf result :timestamp)
                (getf first-model :timestamp)))))))

;;; --- Event ordering ---

(test gateway-event-ordering-on-chat
  "Method events emitted by chat.send should be in deterministic order: chat.message then sessions.update."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime)))
    (nilclaw/gateway:gateway-ensure-session runtime "ord-sess" "Order Test" "agent-1")
    (nilclaw/gateway:gateway-handle-request
     (nilclaw/gateway:make-gateway-request
      :id "ord-1" :method "chat.send"
      :params (list :session-key "ord-sess" :message "Order test"))
     runtime)
    (let* ((method-events (method-events-in-emission-order runtime)))
      (is (= 2 (length method-events)))
      (is (string= "chat.message"
                    (nilclaw/gateway:gateway-method-event-method (first method-events))))
      (is (string= "sessions.update"
                    (nilclaw/gateway:gateway-method-event-method (second method-events)))))))

(test gateway-multiple-sends-preserve-event-order
  "Multiple chat.send calls should accumulate method events in order."
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime)))
    (nilclaw/gateway:gateway-ensure-session runtime "multi-sess" "Multi" "agent-1")
    (dotimes (i 3)
      (nilclaw/gateway:gateway-handle-request
       (nilclaw/gateway:make-gateway-request
        :id (format nil "multi-~A" i) :method "chat.send"
        :params (list :session-key "multi-sess"
                      :message (format nil "Msg ~A" i)))
       runtime))
    ;; 3 sends × 2 method-events each = 6
    (let ((method-events (method-events-in-emission-order runtime)))
      (is (= 6 (length method-events)))
      (loop for i from 0 below 6 by 2
            do (is (string= "chat.message"
                            (nilclaw/gateway:gateway-method-event-method
                             (nth i method-events))))
               (is (string= "sessions.update"
                            (nilclaw/gateway:gateway-method-event-method
                             (nth (1+ i) method-events))))))))

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

;;; ====================================================================
;;; Event Stream Semantics Tests
;;; ====================================================================

(test stream-emit-assigns-monotonic-seq
  "Emitted events must have strictly increasing sequence numbers."
  (let ((stream (nilclaw/gateway:make-default-event-stream)))
    (multiple-value-bind (e1 s1) (nilclaw/gateway:stream-emit stream "chat.message" '(:data "a"))
      (declare (ignorable s1))
      (multiple-value-bind (e2 s2) (nilclaw/gateway:stream-emit stream "chat.message" '(:data "b"))
        (declare (ignorable s2))
        (multiple-value-bind (e3 _s3) (nilclaw/gateway:stream-emit stream "sessions.update" '(:key "x"))
          (declare (ignorable _s3))
          (is (= 1 (nilclaw/gateway:gateway-method-event-seq e1)))
          (is (= 2 (nilclaw/gateway:gateway-method-event-seq e2)))
          (is (= 3 (nilclaw/gateway:gateway-method-event-seq e3)))
          ;; Strict monotonic ordering
          (is (< (nilclaw/gateway:gateway-method-event-seq e1)
                 (nilclaw/gateway:gateway-method-event-seq e2)
                 (nilclaw/gateway:gateway-method-event-seq e3))))))))

(test stream-events-since-returns-ordered-subset
  "stream-events-since returns only events after given seq, in order."
  (let ((stream (nilclaw/gateway:make-default-event-stream)))
    (nilclaw/gateway:stream-emit stream "a" '())
    (nilclaw/gateway:stream-emit stream "b" '())
    (nilclaw/gateway:stream-emit stream "c" '())
    (nilclaw/gateway:stream-emit stream "d" '())
    ;; Get events since seq 2
    (let ((events (nilclaw/gateway:stream-events-since stream 2)))
      (is (= 2 (length events)))
      (is (= 3 (nilclaw/gateway:gateway-method-event-seq (first events))))
      (is (= 4 (nilclaw/gateway:gateway-method-event-seq (second events))))
      (is (string= "c" (nilclaw/gateway:gateway-method-event-method (first events))))
      (is (string= "d" (nilclaw/gateway:gateway-method-event-method (second events)))))))

(test stream-events-since-zero-returns-all
  "stream-events-since 0 returns all events."
  (let ((stream (nilclaw/gateway:make-default-event-stream)))
    (dotimes (i 5)
      (nilclaw/gateway:stream-emit stream (format nil "e~A" i) '()))
    (is (= 5 (length (nilclaw/gateway:stream-events-since stream 0))))))

(test stream-dedupe-prevents-duplicate-emission
  "stream-emit-deduped should suppress duplicate idempotency keys."
  (let ((stream (nilclaw/gateway:make-default-event-stream)))
    ;; First emit succeeds
    (multiple-value-bind (e1 _s1)
        (nilclaw/gateway:stream-emit-deduped stream "chat.send" '(:msg "hi") "idem-1")
      (declare (ignorable _s1))
      (is (not (null e1)))
      (is (= 1 (nilclaw/gateway:gateway-method-event-seq e1))))
    ;; Duplicate with same key is suppressed
    (multiple-value-bind (e2 _s2)
        (nilclaw/gateway:stream-emit-deduped stream "chat.send" '(:msg "hi") "idem-1")
      (declare (ignorable _s2))
      (is (null e2)))
    ;; Different key succeeds
    (multiple-value-bind (e3 _s3)
        (nilclaw/gateway:stream-emit-deduped stream "chat.send" '(:msg "bye") "idem-2")
      (declare (ignorable _s3))
      (is (not (null e3)))
      (is (= 2 (nilclaw/gateway:gateway-method-event-seq e3))))))

(test stream-seen-p-tracks-keys
  "stream-seen-p correctly reports seen/unseen keys."
  (let ((stream (nilclaw/gateway:make-default-event-stream)))
    (is (not (nilclaw/gateway:stream-seen-p stream "key-1")))
    (nilclaw/gateway:stream-mark-seen stream "key-1")
    (is (nilclaw/gateway:stream-seen-p stream "key-1"))
    (is (not (nilclaw/gateway:stream-seen-p stream "key-2")))))

(test stream-ack-advances-last-ack
  "stream-ack updates last-ack-seq."
  (let ((stream (nilclaw/gateway:make-default-event-stream)))
    (is (= 0 (nilclaw/gateway:event-stream-last-ack-seq stream)))
    (nilclaw/gateway:stream-ack stream 5)
    (is (= 5 (nilclaw/gateway:event-stream-last-ack-seq stream)))
    (nilclaw/gateway:stream-ack stream 10)
    (is (= 10 (nilclaw/gateway:event-stream-last-ack-seq stream)))))

(test stream-disconnect-reconnect-cycle
  "Disconnect/reconnect cycle updates state correctly."
  (let ((stream (nilclaw/gateway:make-default-event-stream)))
    (is (nilclaw/gateway:event-stream-connected-p stream))
    (is (= 0 (nilclaw/gateway:event-stream-reconnect-count stream)))
    ;; Disconnect
    (nilclaw/gateway:stream-disconnect stream)
    (is (not (nilclaw/gateway:event-stream-connected-p stream)))
    ;; Reconnect
    (nilclaw/gateway:stream-reconnect stream)
    (is (nilclaw/gateway:event-stream-connected-p stream))
    (is (= 1 (nilclaw/gateway:event-stream-reconnect-count stream)))
    ;; Second cycle
    (nilclaw/gateway:stream-disconnect stream)
    (nilclaw/gateway:stream-reconnect stream)
    (is (= 2 (nilclaw/gateway:event-stream-reconnect-count stream)))))

(test stream-replay-after-reconnect-delivers-missed-events
  "After reconnect, replay should return events since last ack."
  (let ((stream (nilclaw/gateway:make-default-event-stream)))
    ;; Emit 5 events
    (dotimes (i 5)
      (nilclaw/gateway:stream-emit stream (format nil "event-~A" i) '()))
    ;; Client acks through seq 3
    (nilclaw/gateway:stream-ack stream 3)
    ;; Disconnect and reconnect
    (nilclaw/gateway:stream-disconnect stream)
    (nilclaw/gateway:stream-reconnect stream)
    ;; Replay should return events 4 and 5
    (let ((replay (nilclaw/gateway:stream-replay-after-reconnect stream)))
      (is (= 2 (length replay)))
      (is (= 4 (nilclaw/gateway:gateway-method-event-seq (first replay))))
      (is (= 5 (nilclaw/gateway:gateway-method-event-seq (second replay)))))))

(test stream-replay-no-missed-events
  "If all events were acked, replay returns empty."
  (let ((stream (nilclaw/gateway:make-default-event-stream)))
    (dotimes (i 3)
      (nilclaw/gateway:stream-emit stream (format nil "e~A" i) '()))
    (nilclaw/gateway:stream-ack stream 3)
    (nilclaw/gateway:stream-disconnect stream)
    (nilclaw/gateway:stream-reconnect stream)
    (is (= 0 (length (nilclaw/gateway:stream-replay-after-reconnect stream))))))

(test stream-replay-all-missed
  "If no events were acked, replay returns all events."
  (let ((stream (nilclaw/gateway:make-default-event-stream)))
    (dotimes (i 4)
      (nilclaw/gateway:stream-emit stream (format nil "e~A" i) '()))
    ;; No ack (last-ack-seq stays 0)
    (nilclaw/gateway:stream-disconnect stream)
    (nilclaw/gateway:stream-reconnect stream)
    (is (= 4 (length (nilclaw/gateway:stream-replay-after-reconnect stream))))))

(test stream-events-during-disconnect-replayed
  "Events emitted while disconnected should be included in replay."
  (let ((stream (nilclaw/gateway:make-default-event-stream)))
    ;; Emit 2 events while connected, ack both
    (nilclaw/gateway:stream-emit stream "before-1" '())
    (nilclaw/gateway:stream-emit stream "before-2" '())
    (nilclaw/gateway:stream-ack stream 2)
    ;; Disconnect
    (nilclaw/gateway:stream-disconnect stream)
    ;; Emit events while disconnected (server-side processing continues)
    (nilclaw/gateway:stream-emit stream "during-disconnect-1" '())
    (nilclaw/gateway:stream-emit stream "during-disconnect-2" '())
    ;; Reconnect
    (nilclaw/gateway:stream-reconnect stream)
    ;; Replay should include the events emitted during disconnect
    (let ((replay (nilclaw/gateway:stream-replay-after-reconnect stream)))
      (is (= 2 (length replay)))
      (is (string= "during-disconnect-1"
                    (nilclaw/gateway:gateway-method-event-method (first replay))))
      (is (string= "during-disconnect-2"
                    (nilclaw/gateway:gateway-method-event-method (second replay)))))))

(test stream-dedupe-survives-reconnect
  "Idempotency keys should persist across reconnect cycles."
  (let ((stream (nilclaw/gateway:make-default-event-stream)))
    ;; Emit with key
    (nilclaw/gateway:stream-emit-deduped stream "chat.send" '() "key-1")
    ;; Disconnect and reconnect
    (nilclaw/gateway:stream-disconnect stream)
    (nilclaw/gateway:stream-reconnect stream)
    ;; Same key should still be deduplicated
    (multiple-value-bind (event _s)
        (nilclaw/gateway:stream-emit-deduped stream "chat.send" '() "key-1")
      (declare (ignorable _s))
      (is (null event)))
    ;; New key should work
    (multiple-value-bind (event _s)
        (nilclaw/gateway:stream-emit-deduped stream "chat.send" '() "key-2")
      (declare (ignorable _s))
      (is (not (null event))))))
