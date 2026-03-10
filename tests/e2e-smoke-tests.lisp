(in-package #:nilclaw/tests)
(in-suite e2e-suite)

(defun %skip-if-missing (name)
  (unless (uiop:getenv name)
    (skip (format nil "~A missing" name))))

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
  (%skip-if-missing "NILCLAW_CLI_BIN"))

(test e2e-channel-system
  (unless (or (uiop:getenv "TELEGRAM_BOT_TOKEN")
              (uiop:getenv "SLACK_BOT_TOKEN")
              (uiop:getenv "DISCORD_TOKEN"))
    (skip "TELEGRAM_BOT_TOKEN and SLACK_BOT_TOKEN and DISCORD_TOKEN missing")))

(test e2e-cron-heartbeat
  (%skip-if-missing "NILCLAW_CRON_RUNTIME"))

(test e2e-gateway-control-plane
  (%skip-if-missing "NILCLAW_GATEWAY_BIN"))

(test e2e-identity-workspace
  (%skip-if-missing "NILCLAW_BOOTSTRAP_ENTRYPOINT"))

(test e2e-mcp-client
  (%skip-if-missing "MCP_SERVER_URL"))

(test e2e-provider-abstraction
  (unless (or (uiop:getenv "OPENAI_API_KEY")
              (uiop:getenv "ANTHROPIC_API_KEY")
              (uiop:getenv "GOOGLE_API_KEY"))
    (skip "OPENAI_API_KEY and ANTHROPIC_API_KEY and GOOGLE_API_KEY missing"))
  (%skip-if-missing "NILCLAW_PROVIDER_INTEGRATION"))

(test e2e-skills-system
  (%skip-if-missing "NILCLAW_SKILLS_LOADER_ENTRYPOINT"))

(test e2e-streaming-voice
  (unless (or (uiop:getenv "OPENAI_API_KEY") (uiop:getenv "ELEVENLABS_API_KEY"))
    (skip "OPENAI_API_KEY and ELEVENLABS_API_KEY missing"))
  (%skip-if-missing "NILCLAW_STREAMING_RUNTIME"))

(test e2e-subagent-system
  (%skip-if-missing "NILCLAW_SUBAGENT_RUNTIME"))
