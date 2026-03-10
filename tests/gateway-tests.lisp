(in-package #:nilclaw/tests)
(in-suite gateway-suite)

(test gateway-runtime-ready
  (is (nilclaw/gateway:gateway-runtime-ready-p))
  (is (not (nilclaw/gateway:gateway-runtime-ready-p
            (nilclaw/gateway:make-gateway-runtime :name "" :enabled t :port 3000))))
  (is (not (nilclaw/gateway:gateway-runtime-ready-p
            (nilclaw/gateway:make-gateway-runtime :name "gw" :enabled nil :port 3000)))))
