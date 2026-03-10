(in-package #:nilclaw/tests)
(in-suite providers-compatible-suite)

(test provider-integration-ready
  (is (nilclaw/provider:provider-integration-ready-p))
  (is (not (nilclaw/provider:provider-integration-ready-p
            (nilclaw/provider:make-provider-runtime :name "" :integration-entrypoint "x" :enabled t :model "m"))))
  (is (not (nilclaw/provider:provider-integration-ready-p
            (nilclaw/provider:make-provider-runtime :name "openai" :integration-entrypoint "" :enabled t :model "m")))))

(test provider-complete-retries-transient-errors
  (let* ((runtime (nilclaw/provider:make-provider-runtime :max-retries 2))
         (request (nilclaw/provider:make-provider-request :model "openai/gpt-4o-mini" :messages '((:role "user" :content "hi"))))
         (result (nilclaw/provider:provider-complete
                  runtime
                  request
                  (lambda (req attempt)
                    (declare (ignore req))
                    (if (< attempt 3)
                        (values nil :timeout)
                      (values "ok" nil))))))
    (is (nilclaw/provider:provider-result-success-p result))
    (is (string= "ok" (nilclaw/provider:provider-result-content result)))
    (is (= 3 (nilclaw/provider:provider-result-attempts result)))))

(test provider-complete-stops-on-malformed-payload
  (let* ((runtime (nilclaw/provider:make-provider-runtime :max-retries 3))
         (request (nilclaw/provider:make-provider-request :model "openai/gpt-4o-mini" :messages '((:role "user" :content "hi"))))
         (result (nilclaw/provider:provider-complete
                  runtime
                  request
                  (lambda (req attempt)
                    (declare (ignore req attempt))
                    (values nil :malformed-payload)))))
    (is (not (nilclaw/provider:provider-result-success-p result)))
    (is (= 1 (nilclaw/provider:provider-result-attempts result)))
    (is (eq :malformed-payload (nilclaw/provider:provider-result-error-code result)))))