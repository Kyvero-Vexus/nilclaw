(defpackage #:nilclaw/gateway
  (:use #:cl)
  (:export ;; Runtime
           #:gateway-runtime
           #:gateway-runtime-name
           #:gateway-runtime-port
           #:gateway-runtime-enabled
           #:gateway-runtime-sessions
           #:gateway-runtime-agents
           #:gateway-runtime-models
           #:gateway-runtime-connections
           #:gateway-runtime-event-log
           #:make-gateway-runtime
           #:make-default-gateway-runtime
           #:gateway-runtime-ready-p
           ;; Request/Response
           #:gateway-request
           #:gateway-request-id
           #:gateway-request-method
           #:gateway-request-params
           #:make-gateway-request
           #:gateway-response
           #:gateway-response-id
           #:gateway-response-ok-p
           #:gateway-response-result
           #:gateway-response-error-code
           #:gateway-response-error-message
           #:make-gateway-response
           #:gateway-handle-request
           ;; Malformed helper
           #:malformed-request-response
           ;; Events
           #:gateway-event
           #:gateway-event-event
           #:gateway-event-payload
           #:make-gateway-event
           #:gateway-method-event
           #:gateway-method-event-method
           #:gateway-method-event-params
           #:make-gateway-method-event
           #:gateway-emit-event
           #:gateway-emit-method-event
           ;; Connect challenge
           #:gateway-make-challenge
           #:generate-nonce
           ;; Connection
           #:gateway-connection
           #:gateway-connection-nonce
           #:gateway-connection-authenticated
           #:gateway-connection-client-id
           #:gateway-connection-client-display-name
           #:gateway-connection-protocol-version
           #:gateway-connection-tick-interval-ms
           #:make-gateway-connection
           ;; Connect handler
           #:handle-connect
           ;; Session store
           #:gateway-session
           #:gateway-session-key
           #:gateway-session-label
           #:gateway-session-agent-id
           #:gateway-session-created-at
           #:gateway-session-messages
           #:make-gateway-session
           #:gateway-ensure-session
           ;; Message
           #:gateway-message
           #:gateway-message-role
           #:gateway-message-content
           #:gateway-message-timestamp
           #:make-gateway-message
           ;; Agent/Model registries
           #:gateway-agent
           #:gateway-agent-id
           #:gateway-agent-display-name
           #:make-gateway-agent
           #:gateway-model
           #:gateway-model-id
           #:gateway-model-name
           #:gateway-model-provider
           #:make-gateway-model
           ;; Method handlers (exposed for direct testing)
           #:handle-sessions-list
           #:handle-agents-list
           #:handle-chat-send
           #:handle-chat-history
           #:handle-models-list))
