(in-package #:nilclaw/tests)

(def-suite lisp-config-suite :in nilclaw-suite)
(in-suite lisp-config-suite)

(test apply-config-plist-defaults
  "Empty plist produces default config."
  (let ((cfg (nilclaw/config:apply-config-plist '())))
    (is (string= "openrouter" (nilclaw/config:config-default-provider cfg)))
    (is (null (nilclaw/config:config-default-model cfg)))
    (is (= 0.7d0 (nilclaw/config:config-default-temperature cfg)))))

(test apply-config-plist-scalars
  "Scalar config options are applied."
  (let ((cfg (nilclaw/config:apply-config-plist
              '(:default-model "claude-3" :default-provider "anthropic"
                :default-temperature 0.5d0))))
    (is (string= "claude-3" (nilclaw/config:config-default-model cfg)))
    (is (string= "anthropic" (nilclaw/config:config-default-provider cfg)))
    (is (= 0.5d0 (nilclaw/config:config-default-temperature cfg)))))

(test apply-config-plist-sub-config
  "Sub-config plists are merged with defaults."
  (let ((cfg (nilclaw/config:apply-config-plist
              '(:gateway (:port 8080 :host "0.0.0.0")))))
    (is (= 8080 (getf (nilclaw/config:config-gateway cfg) :port)))
    (is (string= "0.0.0.0" (getf (nilclaw/config:config-gateway cfg) :host)))
    ;; Default values preserved
    (is (eq t (getf (nilclaw/config:config-gateway cfg) :require-pairing)))))

(test apply-config-plist-channels
  "Channel list configs are applied."
  (let ((cfg (nilclaw/config:apply-config-plist
              '(:channels ((:type :cli :enabled t)
                           (:type :web :enabled t :path "/chat"))))))
    (is (= 2 (length (nilclaw/config:config-channels cfg))))
    (is (eq :cli (getf (first (nilclaw/config:config-channels cfg)) :type)))))

(test merge-plist-overrides
  "merge-plist correctly overrides keys."
  (let ((result (nilclaw/config:merge-plist
                 '(:a 1 :b 2 :c 3)
                 '(:b 20 :d 4))))
    (is (= 1 (getf result :a)))
    (is (= 20 (getf result :b)))
    (is (= 3 (getf result :c)))
    (is (= 4 (getf result :d)))))

(test merge-plist-empty-overrides
  "merge-plist with empty overrides returns defaults."
  (let ((result (nilclaw/config:merge-plist '(:a 1 :b 2) '())))
    (is (= 1 (getf result :a)))
    (is (= 2 (getf result :b)))))

(test config-to-sexp-string-roundtrip
  "Config can be serialized to sexp and re-read."
  (let* ((cfg (nilclaw/config:apply-config-plist
               '(:default-model "gpt-4o" :default-provider "openai"
                 :default-temperature 0.9d0)))
         (sexp-str (nilclaw/config:config-to-sexp-string cfg))
         (form (read-from-string sexp-str))
         (cfg2 (nilclaw/config:apply-config-plist (cdr form))))
    (is (string= "gpt-4o" (nilclaw/config:config-default-model cfg2)))
    (is (string= "openai" (nilclaw/config:config-default-provider cfg2)))))

(test unknown-config-key-warns
  "Unknown config keys produce a warning."
  (handler-bind ((warning (lambda (w)
                            (is (search "Unknown config key" (princ-to-string w)))
                            (muffle-warning w))))
    (nilclaw/config:apply-config-plist '(:nonexistent-key "value"))))

(test find-config-file-nonexistent
  "find-config-file returns nil for nonexistent paths."
  (is (null (nilclaw/config:find-config-file "/nonexistent/path/config.lisp"))))

(test load-config-default-when-no-file
  "load-config returns default config when no file exists."
  (let ((cfg (nilclaw/config:load-config "/nonexistent/path/config.lisp")))
    (is (typep cfg 'nilclaw/config:config))
    (is (string= "openrouter" (nilclaw/config:config-default-provider cfg)))))
