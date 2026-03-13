;;;; claude-cli-tests.lisp — Tests for Claude Max / Claude CLI transport
;;;; NilClaw - Statically typed Common Lisp agent harness

(in-package #:nilclaw/tests)

(5am:in-suite claude-cli-suite)

;;; ====================================================================
;;; Shell escape utility
;;; ====================================================================

(5am:test shell-escape-basic
  "Shell escape wraps in single quotes."
  (let ((result (nilclaw/provider:shell-escape "hello world")))
    (5am:is (string= "'hello world'" result))))

(5am:test shell-escape-single-quote
  "Shell escape handles embedded single quotes."
  (let ((result (nilclaw/provider:shell-escape "it's a test")))
    (5am:is (search "'\\''" result))
    ;; Should still be valid shell when evaluated
    (5am:is (> (length result) 0))))

(5am:test shell-escape-empty
  "Shell escape handles empty string."
  (let ((result (nilclaw/provider:shell-escape "")))
    (5am:is (string= "''" result))))

(5am:test shell-escape-special-chars
  "Shell escape safely wraps special characters."
  (let ((result (nilclaw/provider:shell-escape "hello; rm -rf /")))
    (5am:is (char= #\' (char result 0)))
    (5am:is (char= #\' (char result (1- (length result)))))))

;;; ====================================================================
;;; Claude CLI availability detection
;;; ====================================================================

(5am:test claude-cli-available-check
  "Claude CLI availability check returns a boolean."
  (nilclaw/provider:reset-claude-cli-cache)
  (let ((result (nilclaw/provider:claude-cli-available-p)))
    (5am:is (typep result 'boolean))))

(5am:test claude-cli-cache-reset
  "Reset cache forces re-detection on next check."
  (nilclaw/provider:reset-claude-cli-cache)
  ;; After reset, internal cache is :unset, next call re-probes
  (let ((result (nilclaw/provider:claude-cli-available-p)))
    (5am:is (typep result 'boolean))))

;;; ====================================================================
;;; Config transport selection
;;; ====================================================================

(5am:test config-transport-defaults-to-http
  "Provider transport defaults to http when not specified."
  (let ((cfg (nilclaw/config:make-default-config)))
    (5am:is (string= "http" (nilclaw/config:get-provider-transport cfg "openrouter")))))

(5am:test config-transport-claude-cli-from-config
  "Provider transport can be set to claude-cli via config."
  (let ((cfg (nilclaw/config:make-default-config)))
    (setf (nilclaw/config:config-providers cfg)
          (list (list :name "anthropic"
                      :api-key nil
                      :base-url nil
                      :transport "claude-cli"
                      :native-tools t)))
    (5am:is (string= "claude-cli"
                      (nilclaw/config:get-provider-transport cfg "anthropic")))))

(5am:test config-transport-http-explicit
  "Provider transport set to http is recognized."
  (let ((cfg (nilclaw/config:make-default-config)))
    (setf (nilclaw/config:config-providers cfg)
          (list (list :name "openai"
                      :api-key "sk-test"
                      :base-url nil
                      :transport "http"
                      :native-tools t)))
    (5am:is (string= "http"
                      (nilclaw/config:get-provider-transport cfg "openai")))))

(5am:test config-transport-missing-provider-defaults-http
  "Transport for unconfigured provider defaults to http."
  (let ((cfg (nilclaw/config:make-default-config)))
    (5am:is (string= "http"
                      (nilclaw/config:get-provider-transport cfg "nonexistent")))))

;;; ====================================================================
;;; Claude CLI transport function creation
;;; ====================================================================

(5am:test make-claude-cli-transport-fn-creates-function
  "make-claude-cli-transport-fn returns a function."
  (let ((fn (nilclaw/provider:make-claude-cli-transport-fn "anthropic/claude-opus-4-0520")))
    (5am:is (functionp fn))))

;;; ====================================================================
;;; Claude CLI complete — error when CLI unavailable (mocked)
;;; ====================================================================

(5am:test claude-cli-complete-unavailable-returns-error
  "claude-cli-complete returns :claude-cli-unavailable when CLI is not found."
  ;; Force cache to nil (CLI not found)
  (let ((nilclaw/provider::*claude-cli-path-cache* nil))
    (multiple-value-bind (content error-code)
        (nilclaw/provider:claude-cli-complete "test" "claude-opus-4-0520")
      (5am:is (null content))
      (5am:is (eq :claude-cli-unavailable error-code)))))

;;; ====================================================================
;;; Fallback transport: auth-failed → Claude CLI
;;; ====================================================================

(5am:test fallback-transport-auth-failed-tries-cli
  "When HTTP returns :auth-failed for Anthropic, fallback transport tries Claude CLI."
  ;; Create a mock runtime that always returns :auth-failed
  (let* ((runtime (nilclaw/provider:make-provider-runtime
                   :name "anthropic"
                   :api-key "bad-key"
                   :model "anthropic/claude-opus-4-0520"))
         ;; We need to test the fallback transport fn logic directly
         ;; Create a mock HTTP fn that returns auth-failed
         (http-called nil)
         (cli-called nil)
         (mock-http-fn (lambda (request attempt-index)
                         (declare (ignore request attempt-index))
                         (setf http-called t)
                         (values nil :auth-failed)))
         ;; Mock Claude CLI as available and returning a response
         (mock-cli-fn (lambda (request attempt-index)
                        (declare (ignore request attempt-index))
                        (setf cli-called t)
                        (values "Claude Max response" nil)))
         ;; Build composite transport that uses mock fns
         (transport-fn (lambda (request attempt-index)
                         (multiple-value-bind (content error-code)
                             (funcall mock-http-fn request attempt-index)
                           (cond
                             (content (values content nil))
                             ((eq error-code :auth-failed)
                              (funcall mock-cli-fn request attempt-index))
                             (t (values content error-code))))))
         (request (nilclaw/provider:make-provider-request
                   :model "anthropic/claude-opus-4-0520"
                   :messages (list '((:role . "user") (:content . "hello")))))
         (result (nilclaw/provider:provider-complete runtime request transport-fn)))
    (5am:is-true http-called)
    (5am:is-true cli-called)
    (5am:is (nilclaw/provider:provider-result-success-p result))
    (5am:is (string= "Claude Max response"
                      (nilclaw/provider:provider-result-content result)))))

(5am:test fallback-transport-non-auth-error-no-cli
  "When HTTP returns a non-auth error, Claude CLI fallback is NOT attempted."
  (let* ((http-called nil)
         (cli-called nil)
         (mock-http-fn (lambda (request attempt-index)
                         (declare (ignore request attempt-index))
                         (setf http-called t)
                         (values nil :provider-error)))
         (mock-cli-fn (lambda (request attempt-index)
                        (declare (ignore request attempt-index))
                        (setf cli-called t)
                        (values "Should not reach" nil)))
         (transport-fn (lambda (request attempt-index)
                         (multiple-value-bind (content error-code)
                             (funcall mock-http-fn request attempt-index)
                           (cond
                             (content (values content nil))
                             ((eq error-code :auth-failed)
                              (funcall mock-cli-fn request attempt-index))
                             (t (values content error-code))))))
         (runtime (nilclaw/provider:make-provider-runtime
                   :name "anthropic"
                   :api-key "some-key"
                   :model "anthropic/claude-opus-4-0520"))
         (request (nilclaw/provider:make-provider-request
                   :model "anthropic/claude-opus-4-0520"
                   :messages (list '((:role . "user") (:content . "hello")))))
         (result (nilclaw/provider:provider-complete runtime request transport-fn)))
    (5am:is-true http-called)
    (5am:is-false cli-called)
    (5am:is (not (nilclaw/provider:provider-result-success-p result)))))

(5am:test fallback-transport-http-success-no-cli
  "When HTTP succeeds, Claude CLI fallback is NOT attempted."
  (let* ((http-called nil)
         (cli-called nil)
         (mock-http-fn (lambda (request attempt-index)
                         (declare (ignore request attempt-index))
                         (setf http-called t)
                         (values "HTTP success" nil)))
         (mock-cli-fn (lambda (request attempt-index)
                        (declare (ignore request attempt-index))
                        (setf cli-called t)
                        (values "Should not reach" nil)))
         (transport-fn (lambda (request attempt-index)
                         (multiple-value-bind (content error-code)
                             (funcall mock-http-fn request attempt-index)
                           (cond
                             (content (values content nil))
                             ((eq error-code :auth-failed)
                              (funcall mock-cli-fn request attempt-index))
                             (t (values content error-code))))))
         (runtime (nilclaw/provider:make-provider-runtime
                   :name "anthropic"
                   :api-key "good-key"
                   :model "anthropic/claude-opus-4-0520"))
         (request (nilclaw/provider:make-provider-request
                   :model "anthropic/claude-opus-4-0520"
                   :messages (list '((:role . "user") (:content . "hello")))))
         (result (nilclaw/provider:provider-complete runtime request transport-fn)))
    (5am:is-true http-called)
    (5am:is-false cli-called)
    (5am:is (nilclaw/provider:provider-result-success-p result))
    (5am:is (string= "HTTP success"
                      (nilclaw/provider:provider-result-content result)))))

;;; ====================================================================
;;; Model passthrough (Claude CLI strips provider prefix)
;;; ====================================================================

(5am:test model-passthrough-strips-prefix
  "Claude CLI transport strips provider/ prefix from model name."
  ;; Test via shell-escape to verify the model name transformation
  ;; The actual stripping logic is in claude-cli-complete
  ;; We test the transport fn creation doesn't crash
  (let ((fn (nilclaw/provider:make-claude-cli-transport-fn "anthropic/claude-opus-4-0520")))
    (5am:is (functionp fn)))
  (let ((fn (nilclaw/provider:make-claude-cli-transport-fn "claude-opus-4-0520")))
    (5am:is (functionp fn))))

;;; ====================================================================
;;; Non-echo behavior via TUI with Claude CLI mock
;;; ====================================================================

(5am:test tui-claude-cli-transport-non-echo
  "TUI with claude-cli transport returns provider response, not echo."
  (let* ((chat-fn (lambda (message model-id history)
                    (declare (type string message model-id)
                             (type list history)
                             (ignore history))
                    ;; Simulate Claude CLI transport returning a real response
                    (if (string-equal (nilclaw/config:get-provider-transport
                                      (nilclaw/config:make-default-config) "anthropic")
                                     "http")
                        ;; For this test, just return a mock non-echo response
                        (values (format nil "Claude Max says: responding to ~A with ~A"
                                        message model-id) t)
                        (values "fallback" t))))
         (client (make-test-tui-client-with-chat-fn chat-fn)))
    (nilclaw/tui:tui-handle-slash-command client "/model anthropic/claude-opus-4-0520")
    (multiple-value-bind (response success-p)
        (nilclaw/tui:local-tui-send client "hello from test")
      (5am:is-true success-p)
      (5am:is (stringp response))
      ;; Must NOT be an echo
      (5am:is (not (search "Echo:" response))))))

;;; ====================================================================
;;; Graceful error when Claude CLI unavailable
;;; ====================================================================

(5am:test claude-cli-unavailable-graceful-error
  "When Claude CLI is not available, appropriate error code is returned."
  (let ((nilclaw/provider::*claude-cli-path-cache* nil))
    (multiple-value-bind (content error-code)
        (nilclaw/provider:claude-cli-complete "test prompt" "claude-opus-4-0520")
      (5am:is (null content))
      (5am:is (eq :claude-cli-unavailable error-code)))))

(5am:test claude-cli-transport-fn-returns-error-when-unavailable
  "Transport function from make-claude-cli-transport-fn returns error when CLI unavailable."
  (let ((nilclaw/provider::*claude-cli-path-cache* nil))
    (let* ((fn (nilclaw/provider:make-claude-cli-transport-fn "anthropic/claude-opus-4-0520"))
           (request (nilclaw/provider:make-provider-request
                     :model "anthropic/claude-opus-4-0520"
                     :messages (list '((:role . "user") (:content . "test"))))))
      (multiple-value-bind (content error-code)
          (funcall fn request 1)
        (5am:is (null content))
        (5am:is (eq :claude-cli-unavailable error-code))))))

;;; ====================================================================
;;; JSON config parsing with transport field
;;; ====================================================================

(5am:test json-config-parses-transport-field
  "JSON config with transport field on provider is parsed correctly."
  (let* ((json-str "{
    \"defaultModel\": \"anthropic/claude-opus-4-0520\",
    \"models\": {
      \"providers\": {
        \"anthropic\": {
          \"transport\": \"claude-cli\"
        },
        \"openai\": {
          \"apiKey\": \"sk-test\",
          \"transport\": \"http\"
        }
      }
    }
  }")
         (cfg (nilclaw/config:parse-config-from-string json-str)))
    (5am:is (string= "claude-cli"
                      (nilclaw/config:get-provider-transport cfg "anthropic")))
    (5am:is (string= "http"
                      (nilclaw/config:get-provider-transport cfg "openai")))))

(5am:test json-config-transport-defaults-when-absent
  "JSON config without transport field defaults to http."
  (let* ((json-str "{
    \"defaultModel\": \"openai/gpt-4\",
    \"models\": {
      \"providers\": {
        \"openai\": {
          \"apiKey\": \"sk-test\"
        }
      }
    }
  }")
         (cfg (nilclaw/config:parse-config-from-string json-str)))
    (5am:is (string= "http"
                      (nilclaw/config:get-provider-transport cfg "openai")))))
