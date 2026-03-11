;;;; Tests for provider HTTP layer
;;;; Validates backoff, error mapping, and 429 handling

(in-package #:nilclaw/tests)

(5am:def-suite providers-http-suite
  :description "Provider HTTP transport tests"
  :in providers-suite)

(5am:in-suite providers-http-suite)

;;; Backoff configuration tests

(5am:test backoff-computes-exponential-growth
  "Backoff should grow exponentially up to max."
  (let ((config (nilclaw/provider:make-backoff-config
                 :initial-ms 1000
                 :max-ms 10000
                 :multiplier 2.0
                 :jitter-p nil)))
    (5am:is (= 1000 (nilclaw/provider:compute-backoff-ms config 1)))
    (5am:is (= 2000 (nilclaw/provider:compute-backoff-ms config 2)))
    (5am:is (= 4000 (nilclaw/provider:compute-backoff-ms config 3)))
    (5am:is (= 8000 (nilclaw/provider:compute-backoff-ms config 4)))
    ;; Caps at max
    (5am:is (= 10000 (nilclaw/provider:compute-backoff-ms config 5)))
    (5am:is (= 10000 (nilclaw/provider:compute-backoff-ms config 100)))))

(5am:test backoff-jitter-adds-randomness
  "Backoff with jitter should vary on repeated calls."
  (let ((config (nilclaw/provider:make-backoff-config
                 :initial-ms 1000
                 :max-ms 10000
                 :multiplier 2.0
                 :jitter-p t))
        (results nil))
    (dotimes (_ 20)
      (push (nilclaw/provider:compute-backoff-ms config 1) results))
    ;; Results should vary (not all equal)
    (5am:is (> (length (remove-duplicates results)) 1))
    ;; All should be >= base (1000) and <= base + base/2 (1500)
    (dolist (r results)
      (5am:is (>= r 1000))
      (5am:is (<= r 1500)))))

;;; HTTP status -> error code mapping

(5am:test http-status-maps-to-error-codes
  "HTTP status codes should map to provider error codes."
  (5am:is (eq :malformed-payload (nilclaw/provider:http-status->error-code 400)))
  (5am:is (eq :auth-failed (nilclaw/provider:http-status->error-code 401)))
  (5am:is (eq :auth-failed (nilclaw/provider:http-status->error-code 403)))
  (5am:is (eq :not-found (nilclaw/provider:http-status->error-code 404)))
  (5am:is (eq :timeout (nilclaw/provider:http-status->error-code 408)))
  (5am:is (eq :rate-limited (nilclaw/provider:http-status->error-code 429)))
  (5am:is (eq :server-error (nilclaw/provider:http-status->error-code 500)))
  (5am:is (eq :server-error (nilclaw/provider:http-status->error-code 502)))
  (5am:is (eq :server-error (nilclaw/provider:http-status->error-code 503)))
  (5am:is (eq :timeout (nilclaw/provider:http-status->error-code 504))))

(5am:test unknown-status-maps-to-nil
  "Unknown HTTP status codes should map to NIL."
  (5am:is (null (nilclaw/provider:http-status->error-code 200)))
  (5am:is (null (nilclaw/provider:http-status->error-code 299)))
  (5am:is (null (nilclaw/provider:http-status->error-code 418))))

;;; Retry-After header parsing

(5am:test retry-after-parses-seconds
  "Retry-After header with seconds value should parse correctly."
  (5am:is (= 30000 (nilclaw/provider:parse-retry-after "30")))
  (5am:is (= 0 (nilclaw/provider:parse-retry-after "0")))
  (5am:is (= 60000 (nilclaw/provider:parse-retry-after "60"))))

(5am:test retry-after-handles-nil
  "Retry-After parsing should handle NIL input gracefully."
  (5am:is (null (nilclaw/provider:parse-retry-after nil)))
  (5am:is (null (nilclaw/provider:parse-retry-after ""))))

(5am:test retry-after-handles-invalid
  "Retry-After parsing should handle invalid input gracefully."
  ;; Non-integer values return default 5000ms
  (5am:is (= 5000 (nilclaw/provider:parse-retry-after "not-a-number"))))

;;; HTTP transport result structure

(5am:test http-transport-result-structure
  "HTTP transport result should have correct slots."
  (let ((result (nilclaw/provider:make-http-transport-result
                 :success-p t
                 :content "Hello"
                 :status 200
                 :error-code nil
                 :retry-after-ms nil)))
    (5am:is-true (nilclaw/provider:http-transport-result-success-p result))
    (5am:is (string= "Hello" (nilclaw/provider:http-transport-result-content result)))
    (5am:is (= 200 (nilclaw/provider:http-transport-result-status result)))
    (5am:is-false (nilclaw/provider:http-transport-result-error-code result))
    (5am:is-false (nilclaw/provider:http-transport-result-retry-after-ms result))))

;;; Provider runtime with base-url

(5am:test provider-runtime-has-base-url
  "Provider runtime should support custom base URL."
  (let ((runtime (nilclaw/provider:make-provider-runtime
                  :name "test"
                  :base-url "https://custom.api.com/v1")))
    (5am:is (string= "https://custom.api.com/v1"
                     (nilclaw/provider:provider-runtime-base-url runtime)))))

(5am:test provider-runtime-has-api-key
  "Provider runtime should support API key."
  (let ((runtime (nilclaw/provider:make-provider-runtime
                  :name "test"
                  :api-key "secret-key-123")))
    (5am:is (string= "secret-key-123"
                     (nilclaw/provider:provider-runtime-api-key runtime)))))

;;; Request building

(5am:test build-request-body-creates-json
  "Request body should be valid JSON with model and messages."
  (let* ((runtime (nilclaw/provider:make-provider-runtime :model "gpt-4"))
         (request (nilclaw/provider:make-provider-request
                   :model "gpt-4"
                   :messages '(("role" . "user") ("content" . "Hello"))))
         (body (nilclaw/provider:build-request-body request runtime)))
    (5am:is (stringp body))
    (5am:is (cl-ppcre:scan "\"model\"" body))
    (5am:is (cl-ppcre:scan "\"messages\"" body))))

;;; HTTP backend stub test

(5am:test http-backend-stub-returns-nil-without-backend
  "HTTP backend should return NIL content when no backend is configured."
  (let ((nilclaw/provider:*http-backend* nil))
    (multiple-value-bind (content status headers)
        (nilclaw/provider:http-backend-request "http://test.com" :post "{}")
      (declare (ignore headers))
      (5am:is-false content)
      (5am:is (= 503 status)))))

(5am:test http-backend-uses-configured-function
  "HTTP backend should call configured function."
  (let* ((called-cell (list nil))
         (nilclaw/provider:*http-backend*
           (lambda (url method body)
             (setf (car called-cell) (list url method body))
             (values "{\"choices\":[{\"message\":{\"content\":\"test\"}}]}" 200 nil))))
    (multiple-value-bind (content status headers)
        (nilclaw/provider:http-backend-request "http://test.com" :post "{\"q\":1}")
      (declare (ignore headers))
      (5am:is (equal '("http://test.com" :post "{\"q\":1}") (car called-cell)))
      (5am:is (stringp content))
      (5am:is (= 200 status)))))

;;; Response parsing

(5am:test parse-provider-content-extracts-content
  "Response parser should extract content from OpenAI-format response."
  (let ((response "{\"choices\":[{\"message\":{\"content\":\"Hello world\"}}]}"))
    (5am:is (string= "Hello world"
                     (nilclaw/provider:parse-provider-content response)))))

(5am:test parse-provider-content-handles-invalid-json
  "Response parser should return NIL for invalid JSON."
  (5am:is-false (nilclaw/provider:parse-provider-content "not json"))
  (5am:is-false (nilclaw/provider:parse-provider-content "{}"))
  (5am:is-false (nilclaw/provider:parse-provider-content "{\"choices\":[]}")))
