(in-package #:nilclaw/tests)

(def-suite auto-reply-suite :in nilclaw-suite)
(in-suite auto-reply-suite)

(test auto-reply-config-defaults
  "Auto-reply config has sensible defaults."
  (let ((config (nilclaw/channel:make-auto-reply-config)))
    (is (nilclaw/channel:auto-reply-config-enabled config))
    (is (= 10 (nilclaw/channel:auto-reply-config-max-replies-per-hour config)))
    (is (null (nilclaw/channel:auto-reply-config-rules config)))
    (is (null (nilclaw/channel:auto-reply-config-fallback-response config)))))

(test auto-reply-runtime-creation
  "Can create auto-reply runtime."
  (let ((runtime (nilclaw/channel:make-default-auto-reply-runtime)))
    (is (typep runtime 'nilclaw/channel:auto-reply-runtime))
    (is (hash-table-p (nilclaw/channel:auto-reply-runtime-reply-counters runtime)))))

(test rule-matches-keyword
  "Keyword matching works case-insensitively."
  (let ((rule (nilclaw/channel:make-auto-reply-rule
               :trigger-type :keyword
               :trigger-pattern "help"
               :response "How can I assist?")))
    (is (nilclaw/channel:rule-matches-p rule "I need help"))
    (is (nilclaw/channel:rule-matches-p rule "HELP"))
    (is (nilclaw/channel:rule-matches-p rule "Please Help me"))
    (is (not (nilclaw/channel:rule-matches-p rule "hello")))))

(test rule-matches-exact
  "Exact matching requires full string match."
  (let ((rule (nilclaw/channel:make-auto-reply-rule
               :trigger-type :exact
               :trigger-pattern "ping"
               :response "pong")))
    (is (nilclaw/channel:rule-matches-p rule "ping"))
    (is (not (nilclaw/channel:rule-matches-p rule "ping me")))
    (is (not (nilclaw/channel:rule-matches-p rule "PING")))))

(test rule-matches-regex
  "Regex matching uses CL-PPCRE."
  (let ((rule (nilclaw/channel:make-auto-reply-rule
               :trigger-type :regex
               :trigger-pattern "issue-\\d+"
               :response "I see you mentioned an issue.")))
    (is (nilclaw/channel:rule-matches-p rule "issue-123"))
    (is (nilclaw/channel:rule-matches-p rule "Check issue-999"))
    (is (not (nilclaw/channel:rule-matches-p rule "issue-")))))

(test rule-disabled-no-match
  "Disabled rules never match."
  (let ((rule (nilclaw/channel:make-auto-reply-rule
               :trigger-type :keyword
               :trigger-pattern "help"
               :response "Response"
               :enabled nil)))
    (is (not (nilclaw/channel:rule-matches-p rule "help me")))))

(test compute-auto-reply-no-rules
  "No reply when no rules match."
  (let ((runtime (nilclaw/channel:make-default-auto-reply-runtime)))
    (is (null (nilclaw/channel:compute-auto-reply runtime "hello" "session-1")))))

(test compute-auto-reply-single-rule
  "Single rule matches and returns response."
  (let* ((rule (nilclaw/channel:make-auto-reply-rule
                :trigger-type :keyword
                :trigger-pattern "hello"
                :response "Hi there!"))
         (config (nilclaw/channel:make-auto-reply-config
                  :rules (list rule)))
         (runtime (nilclaw/channel:make-auto-reply-runtime :config config)))
    (is (string= "Hi there!"
                 (nilclaw/channel:compute-auto-reply runtime "hello world" "s1")))))

(test compute-auto-reply-priority-ordering
  "Rules are evaluated in priority order (highest first)."
  (let* ((rule1 (nilclaw/channel:make-auto-reply-rule
                 :trigger-type :keyword
                 :trigger-pattern "help"
                 :response "Low priority"
                 :priority 1))
         (rule2 (nilclaw/channel:make-auto-reply-rule
                 :trigger-type :keyword
                 :trigger-pattern "help"
                 :response "High priority"
                 :priority 10))
         (config (nilclaw/channel:make-auto-reply-config
                  :rules (list rule1 rule2)))
         (runtime (nilclaw/channel:make-auto-reply-runtime :config config)))
    (is (string= "High priority"
                 (nilclaw/channel:compute-auto-reply runtime "help me" "s1")))))

(test compute-auto-reply-fallback
  "Fallback response is used when no rules match."
  (let* ((config (nilclaw/channel:make-auto-reply-config
                  :fallback-response "I'm here to help!"))
         (runtime (nilclaw/channel:make-auto-reply-runtime :config config)))
    (is (string= "I'm here to help!"
                 (nilclaw/channel:compute-auto-reply runtime "random message" "s1")))))

(test rate-limiting-enforced
  "Rate limiting prevents excessive replies."
  (let* ((config (nilclaw/channel:make-auto-reply-config
                  :max-replies-per-hour 2
                  :rules (list (nilclaw/channel:make-auto-reply-rule
                               :trigger-type :keyword
                               :trigger-pattern "test"
                               :response "ok"))))
         (runtime (nilclaw/channel:make-auto-reply-runtime :config config)))
    ;; First two should work
    (is (string= "ok" (nilclaw/channel:compute-auto-reply runtime "test" "s1")))
    (is (string= "ok" (nilclaw/channel:compute-auto-reply runtime "test" "s1")))
    ;; Third should be rate limited
    (is (null (nilclaw/channel:compute-auto-reply runtime "test" "s1")))))

(test rate-limit-per-session
  "Rate limits are per-session."
  (let* ((config (nilclaw/channel:make-auto-reply-config
                  :max-replies-per-hour 1
                  :rules (list (nilclaw/channel:make-auto-reply-rule
                               :trigger-type :keyword
                               :trigger-pattern "test"
                               :response "ok"))))
         (runtime (nilclaw/channel:make-auto-reply-runtime :config config)))
    ;; Session 1 gets one reply
    (is (string= "ok" (nilclaw/channel:compute-auto-reply runtime "test" "s1")))
    (is (null (nilclaw/channel:compute-auto-reply runtime "test" "s1")))
    ;; Session 2 still gets a reply
    (is (string= "ok" (nilclaw/channel:compute-auto-reply runtime "test" "s2")))))

(test auto-reply-disabled-no-response
  "When auto-reply is disabled, no responses are generated."
  (let* ((config (nilclaw/channel:make-auto-reply-config
                  :enabled nil
                  :rules (list (nilclaw/channel:make-auto-reply-rule
                               :trigger-type :keyword
                               :trigger-pattern "test"
                               :response "ok"))))
         (runtime (nilclaw/channel:make-auto-reply-runtime :config config)))
    (is (null (nilclaw/channel:compute-auto-reply runtime "test" "s1")))))

(test web-channel-auto-reply-integration
  "Web channel can use auto-reply."
  (let* ((web (nilclaw/channel:make-web-channel))
         (rule (nilclaw/channel:make-auto-reply-rule
                :trigger-type :keyword
                :trigger-pattern "help"
                :response "Support is here"))
         (config (nilclaw/channel:make-auto-reply-config
                  :rules (list rule)))
         (runtime (nilclaw/channel:make-auto-reply-runtime :config config)))
    (multiple-value-bind (response should-reply)
        (nilclaw/channel:channel-receive-with-auto-reply web runtime "I need help" "session-abc")
      (is (not (null should-reply)))
      (is (string= "Support is here" response)))))
