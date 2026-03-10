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
  (is (nilclaw/agent:cli-entrypoint-available-p)))

(test e2e-channel-system
  (let* ((cfg (nilclaw/config:make-default-config))
         (channels (nilclaw/config:config-channels cfg)))
    (is (listp channels))))

(test e2e-cron-heartbeat
  (is (nilclaw/cron:cron-runtime-ready-p)))

(test e2e-gateway-control-plane
  (is (nilclaw/gateway:gateway-runtime-ready-p)))

(test e2e-identity-workspace
  (is (nilclaw/bootstrap:bootstrap-entrypoint-available-p)))

(test e2e-mcp-client
  (let* ((cfg (nilclaw/config:make-default-config))
         (mcp (nilclaw/config:config-mcp-servers cfg)))
    (is (listp mcp))))

(test e2e-provider-abstraction
  (is (nilclaw/provider:provider-integration-ready-p)))

(test e2e-skills-system
  (is (nilclaw/skills:skills-loader-entrypoint-available-p)))

(test e2e-streaming-voice
  (is (nilclaw/agent:streaming-runtime-available-p)))

(test e2e-subagent-system
  (is (nilclaw/agent:subagent-runtime-available-p)))
