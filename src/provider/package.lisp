(defpackage #:nilclaw/provider
  (:use #:cl)
  (:export #:provider-runtime
           #:provider-runtime-name
           #:provider-runtime-integration-entrypoint
           #:provider-runtime-enabled
           #:provider-runtime-model
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
           #:provider-complete))