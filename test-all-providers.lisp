;;;; Test all configured providers

(require :asdf)
(push (truename ".") asdf:*central-registry*)
(asdf:load-system "nilclaw")

(format t "~%=== Enable Dexador Backend ===~%")
(nilclaw/provider:enable-dexador-backend)
(format t "Backend enabled: ~A~%" (nilclaw/provider:http-backend-enabled-p))

(format t "~%=== Load Config ===~%")
(multiple-value-bind (cfg path) (nilclaw/config:load-config)
  (format t "Config loaded from: ~A~%" path)
  
  (dolist (provider-name '("openrouter" "anthropic" "zai" "lmstudio" "ollama"))
    (format t "~%=== Test Provider: ~A ===~%" (string-upcase provider-name))
    (multiple-value-bind (runtime found-p) 
        (nilclaw/config:make-provider-runtime-from-config cfg provider-name)
      (cond
        ((not found-p)
         (format t "  NOT FOUND in config~%"))
        ((not runtime)
         (format t "  RUNTIME is NIL (check API key)~%"))
        (t
         (format t "  base-url: ~A~%" (nilclaw/provider:provider-runtime-base-url runtime))
         (let ((api-key (nilclaw/provider:provider-runtime-api-key runtime)))
           (format t "  api-key: ~A~%" (if (and api-key (> (length api-key) 8))
                                          (format nil "~A***" (subseq api-key 0 8))
                                          "NIL")))
         ;; Create simple request
         (let ((request (nilclaw/provider:make-provider-request
                         :model (cond
                                  ((string= provider-name "anthropic") "claude-3-haiku-20240307")
                                  ((string= provider-name "zai") "zai/glm-5")
                                  ((string= provider-name "lmstudio") "openai/gpt-oss-20b")
                                  ((string= provider-name "ollama") "qwen2:0.5b")
                                  (t "openai/gpt-4o-mini"))
                         :messages '(("role" . "user") ("content" . "Say hello")))))
           (format t "  Testing HTTP transport...~%")
           (let* ((backoff (nilclaw/provider:make-backoff-config))
                  (http-result (nilclaw/provider:http-transport-with-backoff request runtime backoff)))
             (format t "  Result:~%")
             (format t "    Status: ~A~%" (nilclaw/provider:http-transport-result-status http-result))
             (format t "    Error: ~A~%" (or (nilclaw/provider:http-transport-result-error-code http-result) "none"))
             (let ((content (nilclaw/provider:http-transport-result-content http-result)))
               (when (and content (> (length content) 0))
                 (format t "    Content: ~A...~%" 
                         (subseq content 0 (min 150 (length content)))))))))))))

(finish-output)
(sb-ext:quit :unix-status 0)
