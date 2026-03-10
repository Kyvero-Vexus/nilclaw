(in-package #:nilclaw/tests)
(in-suite bootstrap-suite)

(test bootstrap-entrypoint-available
  (is (nilclaw/bootstrap:bootstrap-entrypoint-available-p))
  (is (not (nilclaw/bootstrap:bootstrap-entrypoint-available-p
            (nilclaw/bootstrap:make-bootstrap-runtime :entrypoint "" :workspace ".")))))
