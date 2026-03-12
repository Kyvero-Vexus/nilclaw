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
           #:streaming-runtime-available-p
           #:agent-request
           #:agent-request-command
           #:agent-request-payload
           #:make-agent-request
           #:agent-response
           #:agent-response-ok-p
           #:agent-response-code
           #:agent-response-data
           #:make-agent-response
           #:agent-handle-request
           ;; Agent loop
           #:agent-chat
           #:make-chat-transport-fn))