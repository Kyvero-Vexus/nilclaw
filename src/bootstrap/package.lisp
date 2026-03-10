(defpackage #:nilclaw/bootstrap
  (:use #:cl)
  (:export #:bootstrap-runtime
           #:bootstrap-runtime-entrypoint
           #:bootstrap-runtime-workspace
           #:make-bootstrap-runtime
           #:make-default-bootstrap-runtime
           #:bootstrap-entrypoint-available-p))
