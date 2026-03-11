(defpackage #:nilclaw/provider
  (:use #:cl)
  (:export #:provider-runtime
           #:provider-runtime-name
           #:provider-runtime-integration-entrypoint
           #:provider-runtime-enabled
           #:provider-runtime-model
           #:provider-runtime-base-url
           #:provider-runtime-api-key
           #:provider-runtime-max-retries
           #:make-provider-runtime
           #:make-default-provider-runtime
           #:provider-integration-ready-p
           #:provider-request
           #:provider-request-model
           #:provider-request-messages
           #:make-provider-request
           #:provider-result
           #:provider-result-success-p
           #:provider-result-content
           #:provider-result-attempts
           #:provider-result-error-code
           #:make-provider-result
           #:provider-complete
           ;; HTTP transport
           #:backoff-config
           #:backoff-config-initial-ms
           #:backoff-config-max-ms
           #:backoff-config-multiplier
           #:backoff-config-jitter-p
           #:make-backoff-config
           #:compute-backoff-ms
           #:http-status->error-code
           #:parse-retry-after
           #:http-transport-result
           #:http-transport-result-success-p
           #:http-transport-result-content
           #:http-transport-result-status
           #:http-transport-result-error-code
           #:http-transport-result-retry-after-ms
           #:make-http-transport-result
           #:http-backend-request
           #:*http-backend*
           #:build-request-body
           #:parse-provider-content
           #:http-transport-with-backoff
           #:http-transport-fn))