(in-package #:nilclaw/provider)

;;; Provider error code taxonomy
(deftype provider-error-code ()
  "Valid provider error codes for nilclaw."
  '(member :malformed-payload :auth-failed :not-found :timeout
           :rate-limited :server-error :network-fault :unknown))
