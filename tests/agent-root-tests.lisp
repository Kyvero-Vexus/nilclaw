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
