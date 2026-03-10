(defpackage #:nilclaw/gateway
  (:use #:cl)
  (:export #:gateway-runtime
           #:gateway-runtime-name
           #:gateway-runtime-port
           #:gateway-runtime-enabled
           #:make-gateway-runtime
           #:make-default-gateway-runtime
           #:gateway-runtime-ready-p))
