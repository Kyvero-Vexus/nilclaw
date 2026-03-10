(in-package #:nilclaw/tests)
(in-suite gateway-suite)

(test gateway-runtime-ready
  (is (nilclaw/gateway:gateway-runtime-ready-p))
  (is (not (nilclaw/gateway:gateway-runtime-ready-p
            (nilclaw/gateway:make-gateway-runtime :name "" :enabled t :port 3000))))
  (is (not (nilclaw/gateway:gateway-runtime-ready-p
            (nilclaw/gateway:make-gateway-runtime :name "gw" :enabled nil :port 3000)))))

(test gateway-handle-request-success-and-errors
  (let* ((ok (nilclaw/gateway:gateway-handle-request
              (nilclaw/gateway:make-gateway-request :id "1" :method "ping" :params '())))
         (unknown (nilclaw/gateway:gateway-handle-request
                   (nilclaw/gateway:make-gateway-request :id "2" :method "whoami" :params '())))
         (malformed (nilclaw/gateway:gateway-handle-request
                     (nilclaw/gateway:make-gateway-request :id "" :method "ping" :params '()))))
    (is (nilclaw/gateway:gateway-response-ok-p ok))
    (is (equal '(:pong t) (nilclaw/gateway:gateway-response-result ok)))
    (is (not (nilclaw/gateway:gateway-response-ok-p unknown)))
    (is (eq :unknown-method (nilclaw/gateway:gateway-response-error-code unknown)))
    (is (not (nilclaw/gateway:gateway-response-ok-p malformed)))
    (is (eq :malformed-request (nilclaw/gateway:gateway-response-error-code malformed)))))