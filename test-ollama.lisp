;;;; Test ollama provider (local)

(require :asdf)
(push (truename ".") asdf:*central-registry*)
(asdf:load-system "nilclaw")

(format t "~%=== Enable Dexador Backend ===~%")
(nilclaw/provider:enable-dexador-backend)
(format t "Backend enabled: ~A~%" (nilclaw/provider:http-backend-enabled-p))

(format t "~%=== Test Ollama Provider ===~%")
(multiple-value-bind (cfg path) (nilclaw/config:load-config)
  (declare (ignore path))
  (multiple-value-bind (runtime found-p) 
      (nilclaw/config:make-provider-runtime-from-config cfg "ollama")
    (format t "Runtime created: ~A, found: ~A~%" (not (null runtime)) found-p)
    (when runtime
      (format t "  base-url: ~A~%" (nilclaw/provider:provider-runtime-base-url runtime))
      ;; Create request
      (let ((request (nilclaw/provider:make-provider-request
                      :model "qwen2:0.5b"
                      :messages '(("role" . "user") ("content" . "Say hello")))))
        (format t "Request created~%")
        ;; Test transport
        (let* ((backoff (nilclaw/provider:make-backoff-config))
               (http-result (nilclaw/provider:http-transport-with-backoff request runtime backoff)))
          (format t "HTTP transport result:~%")
          (format t "  Status: ~A~%" (nilclaw/provider:http-transport-result-status http-result))
          (format t "  Error: ~A~%" (nilclaw/provider:http-transport-result-error-code http-result))
          (let ((content (nilclaw/provider:http-transport-result-content http-result)))
            (when (and content (> (length content) 0))
              (format t "  Content: ~A...~%" 
                      (subseq content 0 (min 300 (length content)))))))))))

(finish-output)
(sb-ext:quit :unix-status 0)
