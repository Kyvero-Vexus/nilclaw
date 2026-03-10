(defpackage #:nilclaw/security
  (:use #:cl)
  (:export
   ;; autonomy
   #:+autonomy-read-only+
   #:+autonomy-supervised+
   #:+autonomy-full+
   #:+autonomy-yolo+
   #:autonomy-default
   #:autonomy-to-string
   #:autonomy-from-string
   #:can-act
   ;; policy
   #:security-policy
   #:make-default-policy
   #:resolve-allowed-commands
   #:policy-autonomy
   #:policy-allowed-commands
   #:policy-require-approval-for-medium-risk
   #:policy-block-high-risk-commands
   #:policy-allow-raw-url-chars
   ;; risk
   #:+risk-low+
   #:+risk-medium+
   #:+risk-high+
   #:classify-command-risk
   ;; allow/validate
   #:contains-single-ampersand
   #:has-percent-var
   #:is-command-allowed
   #:validate-command-execution
   ;; rate-limit
   #:rate-tracker
   #:make-rate-tracker
   #:record-action
   #:is-rate-limited))
