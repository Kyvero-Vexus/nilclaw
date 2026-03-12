;;;; agent-chat-tests.lisp — Tests for agent loop (provider ↔ channel wiring)

(in-package #:nilclaw/tests)
(in-suite agent-chat-suite)

;;; Mock response JSON in OpenAI format
(defparameter *mock-response-json*
  "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"Hello from mock!\"}}]}")

(defparameter *mock-ok-json*
  "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"ok\"}}]}")

(defparameter *mock-got-it-json*
  "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"got it\"}}]}")

;;; Test agent-chat with mock transport

(test agent-chat-success-with-mock-transport
  "agent-chat returns provider response on success."
  (let* ((runtime (nilclaw/provider:make-provider-runtime
                   :name "test"
                   :model "test/mock"
                   :api-key "sk-test"
                   :base-url "http://localhost:9999/v1/chat/completions"
                   :max-retries 0))
         (nilclaw/provider:*http-backend*
           (lambda (url method body)
             (declare (ignore url method body))
             (values *mock-response-json* 200 nil))))
    (multiple-value-bind (response success-p)
        (nilclaw/agent:agent-chat "hi" runtime)
      (is (string= "Hello from mock!" response))
      (is (eq t success-p)))))

(test agent-chat-with-system-prompt
  "agent-chat passes system prompt to provider."
  (let* ((runtime (nilclaw/provider:make-provider-runtime
                   :name "test"
                   :model "test/mock"
                   :api-key "sk-test"
                   :base-url "http://localhost:9999/v1/chat/completions"
                   :max-retries 0))
         (captured-body nil)
         (nilclaw/provider:*http-backend*
           (lambda (url method body)
             (declare (ignore url method))
             (setf captured-body body)
             (values *mock-ok-json* 200 nil))))
    (nilclaw/agent:agent-chat "test message" runtime
                              :system-prompt "You are a test bot.")
    (is (not (null captured-body)))
    (is (search "system" captured-body))
    (is (search "You are a test bot." captured-body))
    (is (search "test message" captured-body))))

(test agent-chat-failure-returns-error
  "agent-chat returns error message on provider failure."
  (let* ((runtime (nilclaw/provider:make-provider-runtime
                   :name "test"
                   :model "test/mock"
                   :api-key "sk-test"
                   :base-url "http://localhost:9999/v1/chat/completions"
                   :max-retries 0))
         (nilclaw/provider:*http-backend*
           (lambda (url method body)
             (declare (ignore url method body))
             (values nil 401 nil))))
    (multiple-value-bind (response success-p)
        (nilclaw/agent:agent-chat "hi" runtime)
      (is (not success-p))
      (is (search "error" response)))))

(test agent-chat-with-history
  "agent-chat includes conversation history."
  (let* ((runtime (nilclaw/provider:make-provider-runtime
                   :name "test"
                   :model "test/mock"
                   :api-key "sk-test"
                   :base-url "http://localhost:9999/v1/chat/completions"
                   :max-retries 0))
         (captured-body nil)
         (nilclaw/provider:*http-backend*
           (lambda (url method body)
             (declare (ignore url method))
             (setf captured-body body)
             (values *mock-got-it-json* 200 nil)))
         (history (list
                   '((:role . "user") (:content . "previous message"))
                   '((:role . "assistant") (:content . "previous reply")))))
    (nilclaw/agent:agent-chat "new message" runtime :history history)
    (is (not (null captured-body)))
    (is (search "previous message" captured-body))
    (is (search "previous reply" captured-body))
    (is (search "new message" captured-body))))

(test make-chat-transport-fn-creates-callable
  "make-chat-transport-fn returns a function."
  (let ((runtime (nilclaw/provider:make-provider-runtime
                  :name "test"
                  :model "test/mock")))
    (is (functionp (nilclaw/agent:make-chat-transport-fn runtime)))))
