(in-package #:nilclaw/tests)
(in-suite providers-compatible-suite)

(test provider-integration-ready
  (is (nilclaw/provider:provider-integration-ready-p))
  (is (not (nilclaw/provider:provider-integration-ready-p
            (nilclaw/provider:make-provider-runtime :name "" :integration-entrypoint "x" :enabled t :model "m"))))
  (is (not (nilclaw/provider:provider-integration-ready-p
            (nilclaw/provider:make-provider-runtime :name "openai" :integration-entrypoint "" :enabled t :model "m")))))
