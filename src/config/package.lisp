(defpackage #:nilclaw/config
  (:use #:cl)
  (:export
   ;; Config struct and constructors
   #:config
   #:make-config
   #:make-default-config
   #:copy-config
   ;; Parsing
   #:parse-config-from-json
   #:parse-config-from-string
   ;; Validation
   #:validate-config
   #:validation-error
   #:validation-error-kind
   #:validation-error-message
   ;; Validation error kinds
   #:+no-default-model+
   #:+legacy-default-provider-field+
   #:+legacy-default-model-field+
   #:+invalid-default-model-primary+
   #:+temperature-out-of-range+
   #:+invalid-port+
   #:+invalid-gateway-url+
   #:+invalid-gateway-token+
   #:+invalid-keepalive-interval-ms+
   #:+invalid-reconnect-initial-backoff-ms+
   #:+invalid-reconnect-max-backoff-ms+
   #:+invalid-retry-count+
   #:+invalid-backoff-ms+
   #:+invalid-http-proxy-url+
   #:+invalid-api-error-max-chars+
   #:+invalid-http-search-base-url+
   #:+invalid-http-search-provider+
   #:+invalid-http-search-fallback-provider+
   #:+invalid-web-transport+
   #:+invalid-web-path+
   #:+invalid-web-auth-token+
   #:+invalid-web-message-auth-mode+
   #:+invalid-web-message-auth-transport+
   #:+invalid-web-origin+
   #:+missing-web-relay-url+
   #:+invalid-web-relay-url+
   #:+invalid-web-relay-agent-id+
   #:+invalid-web-relay-pairing-code-ttl+
   #:+invalid-web-relay-ui-token-ttl+
   #:+invalid-web-relay-token-ttl+
   ;; Serialization
   #:serialize-config-to-json
   ;; Accessors
   #:config-default-provider
   #:config-default-model
   #:config-default-temperature
   #:config-workspace-dir
   #:config-workspace-dir-override
   #:config-reasoning-effort
   #:config-gateway
   #:config-memory
   #:config-heartbeat
   #:config-autonomy
   #:config-diagnostics
   #:config-reliability
   #:config-scheduler
   #:config-agent
   #:config-secrets
   #:config-identity
   #:config-hardware
   #:config-security
   #:config-browser
   #:config-http-request
   #:config-channels
   #:config-providers
   #:config-auth-profiles
   #:get-oauth-access-token
   #:config-agents-list
   #:config-bindings
   #:config-mcp-servers
   #:config-model-routes
   #:config-session
   #:config-runtime
   #:config-cost
   #:config-composio
   #:config-tunnel
   #:config-audio-media
   #:config-legacy-default-provider-detected
   #:config-legacy-default-model-detected
   #:config-token-limit-explicit
   ;; Sub-config accessors
   #:gateway-config-port
   #:gateway-config-host
   #:gateway-config-require-pairing
   #:gateway-config-allow-public-bind
   #:gateway-config-paired-tokens
   ;; Flat field sync
   #:sync-flat-fields
   ;; Environment override
   #:apply-env-overrides
   ;; Model parsing
   #:parse-model-string
   ;; Duration parsing
   #:parse-duration-string
   ;; Provider config helpers
   #:get-provider-config
   #:make-provider-runtime-from-config
   #:list-configured-providers
   #:provider-configured-p
   #:resolve-default-provider
   #:get-provider-transport
   ;; Native Lisp config
   #:find-config-file
   #:apply-config-plist
   #:merge-plist
   #:load-lisp-config
   #:load-config
   #:config-to-sexp-string))
