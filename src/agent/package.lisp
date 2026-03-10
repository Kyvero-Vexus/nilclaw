(defpackage #:nilclaw/agent
  (:use #:cl)
  (:export #:agent-runtime
           #:agent-runtime-cli-entrypoint
           #:agent-runtime-subagent-entrypoint
           #:agent-runtime-streaming-entrypoint
           #:agent-runtime-enabled
           #:make-agent-runtime
           #:make-default-agent-runtime
           #:cli-entrypoint-available-p
           #:subagent-runtime-available-p
           #:streaming-runtime-available-p))
