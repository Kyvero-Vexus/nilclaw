(in-package #:nilclaw/tests)
(in-suite config-suite)

;;; --- JSON Parsing Tests ---

(test config-empty-object-uses-defaults
  "Empty JSON object uses default values."
  (let ((cfg (nilclaw/config:parse-config-from-string "{}")))
    (is (string= "openrouter" (nilclaw/config:config-default-provider cfg)))
    (is (= 0.7d0 (nilclaw/config:config-default-temperature cfg)))
    (is (eq t (getf (nilclaw/config:config-secrets cfg) :encrypt)))))

(test config-integer-temperature-coerced
  "Integer temperature coerced to float."
  (let ((cfg (nilclaw/config:parse-config-from-string
              "{\"default_temperature\": 1}")))
    (is (= 1.0d0 (nilclaw/config:config-default-temperature cfg)))))

(test config-unknown-fields-ignored
  "Unknown foreign fields silently ignored."
  (let ((cfg (nilclaw/config:parse-config-from-string
              "{\"tts\": {}, \"ui\": true, \"skills\": [], \"bedrock_discovery\": false}")))
    (is (string= "openrouter" (nilclaw/config:config-default-provider cfg)))
    (is (= 0.7d0 (nilclaw/config:config-default-temperature cfg)))))

;;; --- Model Configuration ---

(test config-model-primary-parsing
  "Parse provider/model from primary string."
  (multiple-value-bind (provider model)
      (nilclaw/config:parse-model-string "anthropic/claude-opus-4")
    (is (string= "anthropic" provider))
    (is (string= "claude-opus-4" model))))

(test config-custom-provider-versioned-path
  "Custom provider with versioned path."
  (multiple-value-bind (provider model)
      (nilclaw/config:parse-model-string
       "custom:https://api.example.com/openai/v2/minimaxai/minimax-m2.1")
    (is (string= "custom:https://api.example.com/openai/v2" provider))
    (is (string= "minimaxai/minimax-m2.1" model))))

(test config-legacy-default-provider-with-model-only
  "Legacy default_provider with model-only primary."
  (let ((cfg (nilclaw/config:parse-config-from-string
              "{\"default_provider\": \"openai\", \"agents\": {\"defaults\": {\"model\": {\"primary\": \"gpt-5.2\"}}}}")))
    (is (string= "openai" (nilclaw/config:config-default-provider cfg)))
    (is (string= "gpt-5.2" (nilclaw/config:config-default-model cfg)))
    (is (eq t (nilclaw/config:config-legacy-default-provider-detected cfg)))))

(test config-legacy-default-model-rejected
  "Top-level default_model rejected on validation."
  (let ((cfg (nilclaw/config:parse-config-from-string
              "{\"default_model\": \"meta-llama/llama-3.3-70b-instruct:free\"}")))
    (is (eq t (nilclaw/config:config-legacy-default-model-detected cfg)))
    (let ((errors (nilclaw/config:validate-config cfg)))
      (is (member nilclaw/config:+legacy-default-model-field+
                  (mapcar #'nilclaw/config:validation-error-kind errors))))))

(test config-workspace-override-backslashes
  "Workspace override with backslashes preserved."
  (let ((cfg (nilclaw/config:parse-config-from-string
              "{\"workspace\": \"C:\\\\Users\\\\menger\\\\Desktop\\\\myspace\", \"agents\": {\"defaults\": {\"model\": {\"primary\": \"anthropic/claude-opus-4\"}}}}")))
    (is (string= "C:\\Users\\menger\\Desktop\\myspace"
                  (nilclaw/config:config-workspace-dir-override cfg)))))

;;; --- Validation ---

(test config-validation-passes-valid
  "Validation passes for valid config."
  (let ((cfg (nilclaw/config:parse-config-from-string
              "{\"agents\": {\"defaults\": {\"model\": {\"primary\": \"test/model\"}}}}")))
    (is (null (nilclaw/config:validate-config cfg)))))

(test config-validation-rejects-null-model
  "Rejects null default_model."
  (let* ((cfg (nilclaw/config:make-default-config))
         (errors (nilclaw/config:validate-config cfg)))
    (is (member nilclaw/config:+no-default-model+
                (mapcar #'nilclaw/config:validation-error-kind errors)))))

(test config-validation-rejects-model-without-slash
  "Rejects model primary without provider prefix."
  (let* ((cfg (nilclaw/config:parse-config-from-string
               "{\"agents\": {\"defaults\": {\"model\": {\"primary\": \"claude-opus-4\"}}}}"))
         (errors (nilclaw/config:validate-config cfg)))
    (is (member nilclaw/config:+invalid-default-model-primary+
                (mapcar #'nilclaw/config:validation-error-kind errors)))))

(test config-validation-temperature-range
  "Temperature validation [0.0, 2.0]."
  ;; Too high
  (let* ((cfg (nilclaw/config:parse-config-from-string
               "{\"default_temperature\": 5.0, \"agents\": {\"defaults\": {\"model\": {\"primary\": \"a/b\"}}}}"))
         (errors (nilclaw/config:validate-config cfg)))
    (is (member nilclaw/config:+temperature-out-of-range+
                (mapcar #'nilclaw/config:validation-error-kind errors))))
  ;; Too low
  (let* ((cfg (nilclaw/config:parse-config-from-string
               "{\"default_temperature\": -1.0, \"agents\": {\"defaults\": {\"model\": {\"primary\": \"a/b\"}}}}"))
         (errors (nilclaw/config:validate-config cfg)))
    (is (member nilclaw/config:+temperature-out-of-range+
                (mapcar #'nilclaw/config:validation-error-kind errors))))
  ;; Boundary: 0.0 OK
  (let* ((cfg (nilclaw/config:parse-config-from-string
               "{\"default_temperature\": 0.0, \"agents\": {\"defaults\": {\"model\": {\"primary\": \"a/b\"}}}}"))
         (errors (nilclaw/config:validate-config cfg)))
    (is (not (member nilclaw/config:+temperature-out-of-range+
                     (mapcar #'nilclaw/config:validation-error-kind errors)))))
  ;; Boundary: 2.0 OK
  (let* ((cfg (nilclaw/config:parse-config-from-string
               "{\"default_temperature\": 2.0, \"agents\": {\"defaults\": {\"model\": {\"primary\": \"a/b\"}}}}"))
         (errors (nilclaw/config:validate-config cfg)))
    (is (not (member nilclaw/config:+temperature-out-of-range+
                     (mapcar #'nilclaw/config:validation-error-kind errors))))))

(test config-validation-zero-port
  "Rejects zero port."
  (let* ((cfg (nilclaw/config:parse-config-from-string
               "{\"gateway\": {\"port\": 0}, \"agents\": {\"defaults\": {\"model\": {\"primary\": \"a/b\"}}}}"))
         (errors (nilclaw/config:validate-config cfg)))
    (is (member nilclaw/config:+invalid-port+
                (mapcar #'nilclaw/config:validation-error-kind errors)))))

(test config-validation-retry-limits
  "Retry limit validation."
  ;; Too many retries
  (let* ((cfg (nilclaw/config:parse-config-from-string
               "{\"reliability\": {\"provider_retries\": 101}, \"agents\": {\"defaults\": {\"model\": {\"primary\": \"a/b\"}}}}"))
         (errors (nilclaw/config:validate-config cfg)))
    (is (member nilclaw/config:+invalid-retry-count+
                (mapcar #'nilclaw/config:validation-error-kind errors))))
  ;; Backoff too high
  (let* ((cfg (nilclaw/config:parse-config-from-string
               "{\"reliability\": {\"provider_backoff_ms\": 700000}, \"agents\": {\"defaults\": {\"model\": {\"primary\": \"a/b\"}}}}"))
         (errors (nilclaw/config:validate-config cfg)))
    (is (member nilclaw/config:+invalid-backoff-ms+
                (mapcar #'nilclaw/config:validation-error-kind errors)))))

;;; --- Security-Critical Defaults ---

(test config-security-defaults
  "Security-critical defaults."
  (let ((cfg (nilclaw/config:make-default-config)))
    ;; Gateway requires pairing by default
    (is (eq t (getf (nilclaw/config:config-gateway cfg) :require-pairing)))
    ;; Gateway blocks public bind by default
    (is (eq nil (getf (nilclaw/config:config-gateway cfg) :allow-public-bind)))
    ;; Secrets encrypt by default
    (is (eq t (getf (nilclaw/config:config-secrets cfg) :encrypt)))))

;;; --- Heartbeat Configuration ---

(test config-heartbeat-minutes
  "Heartbeat every string with minutes."
  (multiple-value-bind (enabled minutes)
      (nilclaw/config:parse-duration-string "30m")
    (is (eq t enabled))
    (is (= 30 minutes))))

(test config-heartbeat-hours
  "Heartbeat every string with hours."
  (multiple-value-bind (enabled minutes)
      (nilclaw/config:parse-duration-string "2h")
    (is (eq t enabled))
    (is (= 120 minutes))))

;;; --- Reasoning Effort ---

(test config-reasoning-effort-valid
  "Valid reasoning effort values parsed."
  (dolist (val '("high" "medium" "low" "minimal" "xhigh"))
    (let ((cfg (nilclaw/config:parse-config-from-string
                (format nil "{\"reasoning_effort\": \"~A\", \"agents\": {\"defaults\": {\"model\": {\"primary\": \"a/b\"}}}}" val))))
      (is (string= val (nilclaw/config:config-reasoning-effort cfg))))))

(test config-reasoning-effort-invalid
  "Invalid reasoning effort ignored."
  (let ((cfg (nilclaw/config:parse-config-from-string
              "{\"reasoning_effort\": \"invalid\", \"agents\": {\"defaults\": {\"model\": {\"primary\": \"a/b\"}}}}")))
    (is (null (nilclaw/config:config-reasoning-effort cfg)))))

;;; --- Gateway Defaults ---

(test config-gateway-defaults
  "Gateway default values."
  (let ((cfg (nilclaw/config:make-default-config)))
    (is (= 3000 (getf (nilclaw/config:config-gateway cfg) :port)))
    (is (string= "127.0.0.1" (getf (nilclaw/config:config-gateway cfg) :host)))))

;;; --- Environment Variable Override ---

(test config-env-override-no-crash
  "applyEnvOverrides does not crash on default config."
  (let ((cfg (nilclaw/config:make-default-config)))
    ;; Should not signal any condition
    (finishes (nilclaw/config:apply-env-overrides cfg))))
