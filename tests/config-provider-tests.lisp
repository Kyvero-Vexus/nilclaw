;;;; Tests for config-provider integration
;;;; Validates provider runtime construction from config

(in-package #:nilclaw/tests)

(in-suite config-suite)

;;; Provider config lookup tests

(test get-provider-config-finds-configured-provider
  "get-provider-config should find a provider by name."
  (let ((cfg (nilclaw/config:make-config
              :providers (list (list :name "openai" :api-key "sk-test")))))
    (let ((p (nilclaw/config:get-provider-config cfg "openai")))
      (is-true p)
      (is (string= "sk-test" (getf p :api-key))))))

(test get-provider-config-returns-nil-for-unknown
  "get-provider-config should return nil for unknown provider."
  (let ((cfg (nilclaw/config:make-config
              :providers (list (list :name "openai" :api-key "sk-test")))))
    (is-false (nilclaw/config:get-provider-config cfg "unknown"))))

(test list-configured-providers-returns-names
  "list-configured-providers should return provider names."
  (let ((cfg (nilclaw/config:make-config
              :providers (list (list :name "openai" :api-key "sk-1")
                               (list :name "anthropic" :api-key "sk-2")))))
    (let ((names (nilclaw/config:list-configured-providers cfg)))
      (is (= 2 (length names)))
      (is (member "openai" names :test #'string=))
      (is (member "anthropic" names :test #'string=)))))

(test provider-configured-p-returns-bool
  "provider-configured-p should return true for configured provider."
  (let ((cfg (nilclaw/config:make-config
              :providers (list (list :name "openai" :api-key "sk-test")))))
    (is-true (nilclaw/config:provider-configured-p cfg "openai"))
    (is-false (nilclaw/config:provider-configured-p cfg "unknown"))))

;;; Default provider resolution tests

(test resolve-default-provider-uses-config
  "resolve-default-provider should use config default-provider."
  (let ((cfg (nilclaw/config:make-config
              :default-provider "anthropic"
              :providers (list (list :name "anthropic" :api-key "sk-test")))))
    (multiple-value-bind (provider model)
        (nilclaw/config:resolve-default-provider cfg)
      (is (string= "anthropic" provider))
      (is-false model))))

(test resolve-default-provider-parses-model-string
  "resolve-default-provider should parse provider/model from default-model."
  (let ((cfg (nilclaw/config:make-config
              :default-provider "openai"
              :default-model "anthropic/claude-3"
              :providers (list (list :name "anthropic" :api-key "sk-test")))))
    (multiple-value-bind (provider model)
        (nilclaw/config:resolve-default-provider cfg)
      (is (string= "anthropic" provider))
      (is (string= "claude-3" model)))))

;;; Provider runtime construction tests

(test make-provider-runtime-from-config-uses-api-key
  "make-provider-runtime-from-config should pass api-key from config."
  (let* ((cfg (nilclaw/config:make-config
               :providers (list (list :name "openai"
                                      :api-key "sk-test-123"
                                      :base-url "https://custom.api.com"))))
         (runtime (nilclaw/config:make-provider-runtime-from-config cfg "openai")))
    (is (stringp (nilclaw/provider:provider-runtime-api-key runtime)))
    (is (string= "sk-test-123" (nilclaw/provider:provider-runtime-api-key runtime)))))

(test make-provider-runtime-from-config-uses-base-url
  "make-provider-runtime-from-config should pass base-url from config."
  (let* ((cfg (nilclaw/config:make-config
               :providers (list (list :name "openai"
                                      :api-key "sk-test"
                                      :base-url "https://custom.api.com"))))
         (runtime (nilclaw/config:make-provider-runtime-from-config cfg "openai")))
    (is (string= "https://custom.api.com"
                     (nilclaw/provider:provider-runtime-base-url runtime)))))

(test make-provider-runtime-from-config-uses-retries
  "make-provider-runtime-from-config should use provider-retries from reliability config."
  (let* ((cfg (nilclaw/config:make-config
               :reliability (list :provider-retries 5)
               :providers (list (list :name "openai" :api-key "sk-test"))))
         (runtime (nilclaw/config:make-provider-runtime-from-config cfg "openai")))
    (is (= 5 (nilclaw/provider:provider-runtime-max-retries runtime)))))

(test make-provider-runtime-from-config-returns-found-flag
  "make-provider-runtime-from-config should return found-p flag."
  (let ((cfg (nilclaw/config:make-config
              :providers (list (list :name "openai" :api-key "sk-test")))))
    (multiple-value-bind (runtime found-p)
        (nilclaw/config:make-provider-runtime-from-config cfg "openai")
      (declare (ignore runtime))
      (is-true found-p))
    (multiple-value-bind (runtime found-p)
        (nilclaw/config:make-provider-runtime-from-config cfg "unknown")
      (declare (ignore runtime))
      (is-false found-p))))
