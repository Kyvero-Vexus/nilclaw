(defpackage #:nilclaw/skills
  (:use #:cl)
  (:export #:skills-runtime
           #:skills-runtime-entrypoint
           #:skills-runtime-enabled
           #:make-skills-runtime
           #:make-default-skills-runtime
           #:skills-loader-entrypoint-available-p))
