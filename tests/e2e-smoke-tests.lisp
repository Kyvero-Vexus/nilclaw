(in-package #:nilclaw/tests)
(in-suite e2e-suite)

(test e2e-configuration
  (let* ((cfg (nilclaw/config:parse-config-from-string "{\"agents\":{\"defaults\":{\"model\":{\"primary\":\"openai/gpt-4o-mini\"}}}}"))
         (errs (nilclaw/config:validate-config cfg)))
    (is (typep cfg 'nilclaw/config:config))
    (is (null errs))))

(test e2e-memory-system
  (let ((mem (nilclaw/memory:make-inmemory-lru)))
    (nilclaw/memory:memory-store mem "k" "v" "test" "s")
    (let ((entry (nilclaw/memory:memory-get mem "k")))
      (is (string= (nilclaw/memory:memory-entry-key entry) "k"))
      (is (= 1 (nilclaw/memory:memory-count mem)))
      (is (not (null entry))))))

(test e2e-security-sandboxing
  (let ((policy (nilclaw/security:make-default-policy)))
    (multiple-value-bind (risk err) (nilclaw/security:validate-command-execution policy "ls -la")
      (is (eq risk :low))
      (is (null err)))
    (multiple-value-bind (risk err) (nilclaw/security:validate-command-execution policy "rm -rf /")
      (is (null risk))
      (is (eq err :high-risk-blocked)))))

(test e2e-tool-system
  (let ((calls (nilclaw/dispatcher:parse-tool-calls "<tool_call>{\"name\":\"read\",\"arguments\":{\"path\":\"README.md\"}}</tool_call>")))
    (is (= 1 (length calls)))
    (is (string= "read" (nilclaw/dispatcher:tool-call-name (first calls))))))

(test e2e-agent-core
  (let* ((runtime (nilclaw/agent:make-default-agent-runtime))
         (response (nilclaw/agent:agent-handle-request
                    runtime
                    (nilclaw/agent:make-agent-request :command "chat.send" :payload '((:message . "hello"))))))
    (is (nilclaw/agent:cli-entrypoint-available-p runtime))
    (is (nilclaw/agent:agent-response-ok-p response))))

(test e2e-channel-system
  (let* ((cfg (nilclaw/config:make-default-config)))
    ;; Behavioral validation: web account invariants should raise concrete
    ;; config errors (path/auth-token/origin/relay-url contract checks).
    (setf (nilclaw/config:config-channels cfg)
          '((:web . ((:accounts . ((:acct . ((:path . "bad")
                                              (:auth--token . "bad token")
                                              (:allowed--origins . ("example.com"))
                                              (:transport . "relay")
                                              (:message--auth--mode . "token")))))))))
    (let* ((errs (nilclaw/config:validate-config cfg))
           (kinds (mapcar #'nilclaw/config:validation-error-kind errs)))
      (is (member :invalid-web-path kinds))
      (is (member :invalid-web-auth-token kinds))
      (is (member :invalid-web-origin kinds))
      (is (member :missing-web-relay-url kinds))
      (is (member :invalid-web-message-auth-transport kinds))))
  ;; Valid web relay config should pass with no web-specific violations.
  (let* ((cfg (nilclaw/config:make-default-config)))
    (setf (nilclaw/config:config-channels cfg)
          '((:web . ((:accounts . ((:acct . ((:path . "/ok")
                                              (:auth--token . "token123")
                                              (:allowed--origins . ("https://example.com"))
                                              (:transport . "relay")
                                              (:relay--url . "wss://relay.example/ws")
                                              (:message--auth--mode . "none")))))))))
    (let* ((errs (nilclaw/config:validate-config cfg))
           (kinds (mapcar #'nilclaw/config:validation-error-kind errs)))
      (is (not (member :invalid-web-path kinds)))
      (is (not (member :invalid-web-auth-token kinds)))
      (is (not (member :invalid-web-origin kinds)))
      (is (not (member :missing-web-relay-url kinds)))
      (is (not (member :invalid-web-relay-url kinds))))))

(test e2e-cron-heartbeat
  (let* ((runtime (nilclaw/cron:make-cron-runtime :max-retries 1))
         (tasks (list (nilclaw/cron:make-cron-task :id "heartbeat" :due-at 0 :payload :heartbeat)))
         (executed (nilclaw/cron:cron-run-due-tasks
                    runtime
                    tasks
                    0
                    (lambda (task)
                      (declare (ignore task))
                      (values t nil)))))
    (is (eq :completed (nilclaw/cron:cron-task-status (first executed))))))

(test e2e-gateway-control-plane
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (session-key "e2e-session"))
    ;; Exercise a real control-plane flow: connect + session mutation + history replay.
    (nilclaw/gateway:gateway-ensure-session runtime session-key "E2E Session" "agent-e2e")
    (let* ((connect (nilclaw/gateway:gateway-handle-request
                     (nilclaw/gateway:make-gateway-request
                      :id "gw-1"
                      :method "connect"
                      :params (list :min-protocol 3
                                    :max-protocol 3
                                    :client (list :id "e2e-client"
                                                  :display-name "E2E Client")))
                     runtime
                     (nilclaw/gateway:make-gateway-connection :nonce "e2e-nonce")))
           (chat-send (nilclaw/gateway:gateway-handle-request
                       (nilclaw/gateway:make-gateway-request
                        :id "gw-2"
                        :method "chat.send"
                        :params (list :session-key session-key
                                      :message "hello from e2e"
                                      :idempotency-key "e2e-idem-1"))
                       runtime))
           (history (nilclaw/gateway:gateway-handle-request
                     (nilclaw/gateway:make-gateway-request
                      :id "gw-3"
                      :method "chat.history"
                      :params (list :session-key session-key
                                    :limit 10))
                     runtime)))
      (is (nilclaw/gateway:gateway-response-ok-p connect))
      (is (= 3 (getf (nilclaw/gateway:gateway-response-result connect) :protocol)))
      (is (nilclaw/gateway:gateway-response-ok-p chat-send))
      (is (getf (nilclaw/gateway:gateway-response-result chat-send) :queued))
      (is (nilclaw/gateway:gateway-response-ok-p history))
      (let* ((messages (getf (nilclaw/gateway:gateway-response-result history) :messages))
             (first-message (first messages)))
        (is (>= (length messages) 2))
        (is (integerp (getf first-message :timestamp)))
        (is (equal (getf first-message :content-parts)
                   (getf first-message :|contentParts|)))))))

(test e2e-identity-workspace
  (is (nilclaw/bootstrap:bootstrap-entrypoint-available-p)))

(test e2e-mcp-client
  ;; Behavioral contract: parse real MCP server config and validate
  ;; normalized structure.
  (let* ((cfg (nilclaw/config:parse-config-from-string
               "{\"mcp_servers\":{\"filesystem\":{\"command\":\"npx\",\"args\":[\"-y\",\"@modelcontextprotocol/server-filesystem\",\"/tmp\"],\"env\":{\"NODE_ENV\":\"test\"}}}}"))
         (mcp (nilclaw/config:config-mcp-servers cfg))
         (srv (first mcp)))
    (is (= 1 (length mcp)))
    (is (string= "filesystem" (getf srv :name)))
    (is (string= "npx" (getf srv :command)))
    (is (equal '("-y" "@modelcontextprotocol/server-filesystem" "/tmp")
               (getf srv :args)))
    (let ((env (getf srv :env)))
      (is (= 1 (length env)))
      (is (string= "test" (cdar env))))))

(test e2e-provider-abstraction
  (let* ((runtime (nilclaw/provider:make-provider-runtime :max-retries 1))
         (request (nilclaw/provider:make-provider-request :model "openai/gpt-4o-mini" :messages '((:role "user" :content "hello"))))
         (attempts 0)
         (result (nilclaw/provider:provider-complete
                  runtime
                  request
                  (lambda (req attempt)
                    (declare (ignore req))
                    (setf attempts attempt)
                    (if (= attempt 1)
                        (values nil :timeout)
                      (values "hello back" nil))))))
    (is (nilclaw/provider:provider-result-success-p result))
    (is (= 2 attempts))
    (is (= 2 (nilclaw/provider:provider-result-attempts result)))
    (is (string= "hello back" (nilclaw/provider:provider-result-content result)))))

(test e2e-skills-system
  (is (nilclaw/skills:skills-loader-entrypoint-available-p)))

(test e2e-streaming-voice
  (is (nilclaw/agent:streaming-runtime-available-p)))

(test e2e-subagent-system
  ;; Behavioral contract: subagent.spawn success and failure paths.
  (let* ((runtime (nilclaw/agent:make-default-agent-runtime))
         (ok (nilclaw/agent:agent-handle-request
              runtime
              (nilclaw/agent:make-agent-request
               :command "subagent.spawn"
               :payload '((:task . "run-check")))))
         (missing-task (nilclaw/agent:agent-handle-request
                        runtime
                        (nilclaw/agent:make-agent-request
                         :command "subagent.spawn"
                         :payload '((:foo . "bar")))))
         (disabled-runtime (nilclaw/agent:make-agent-runtime
                            :enabled nil
                            :subagent-entrypoint "nilclaw/agent:spawn-subagent"
                            :streaming-entrypoint "nilclaw/agent:stream-event"
                            :cli-entrypoint "nilclaw/agent:main"
                            :max-subagents 8))
         (disabled (nilclaw/agent:agent-handle-request
                    disabled-runtime
                    (nilclaw/agent:make-agent-request
                     :command "subagent.spawn"
                     :payload '((:task . "run-check"))))))
    (is (nilclaw/agent:agent-response-ok-p ok))
    (is (equal '(:spawned t) (nilclaw/agent:agent-response-data ok)))
    (is (not (nilclaw/agent:agent-response-ok-p missing-task)))
    (is (eq :capacity-or-payload-error (nilclaw/agent:agent-response-code missing-task)))
    (is (not (nilclaw/agent:agent-response-ok-p disabled)))
    (is (eq :disabled (nilclaw/agent:agent-response-code disabled)))))