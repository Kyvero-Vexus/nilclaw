(in-package #:nilclaw/tests)
(in-suite agent-root-suite)

(test agent-runtime-entrypoints-available
  (is (nilclaw/agent:cli-entrypoint-available-p))
  (is (nilclaw/agent:subagent-runtime-available-p))
  (is (nilclaw/agent:streaming-runtime-available-p))
  (let ((runtime (nilclaw/agent:make-agent-runtime :cli-entrypoint "" :subagent-entrypoint "" :streaming-entrypoint "" :enabled t)))
    (is (not (nilclaw/agent:cli-entrypoint-available-p runtime)))
    (is (not (nilclaw/agent:subagent-runtime-available-p runtime)))
    (is (not (nilclaw/agent:streaming-runtime-available-p runtime)))))

(test agent-handle-request-behavior
  (let* ((runtime (nilclaw/agent:make-default-agent-runtime))
         (chat-ok (nilclaw/agent:agent-handle-request runtime (nilclaw/agent:make-agent-request :command "chat.send" :payload '((:message . "hi")))))
         (spawn-ok (nilclaw/agent:agent-handle-request runtime (nilclaw/agent:make-agent-request :command "subagent.spawn" :payload '((:task . "do x")))))
         (chat-bad (nilclaw/agent:agent-handle-request runtime (nilclaw/agent:make-agent-request :command "chat.send" :payload '())))
         (unknown (nilclaw/agent:agent-handle-request runtime (nilclaw/agent:make-agent-request :command "nope" :payload '()))))
    (is (nilclaw/agent:agent-response-ok-p chat-ok))
    (is (nilclaw/agent:agent-response-ok-p spawn-ok))
    (is (not (nilclaw/agent:agent-response-ok-p chat-bad)))
    (is (eq :malformed-request (nilclaw/agent:agent-response-code chat-bad)))
    (is (not (nilclaw/agent:agent-response-ok-p unknown)))
    (is (eq :unknown-command (nilclaw/agent:agent-response-code unknown)))))