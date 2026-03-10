(defpackage #:nilclaw/gateway
  (:use #:cl)
  (:export #:gateway-runtime
           #:gateway-runtime-name
           #:gateway-runtime-port
           #:gateway-runtime-enabled
           #:make-gateway-runtime
           #:make-default-gateway-runtime
           #:gateway-runtime-ready-p
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
           #:gateway-handle-request))