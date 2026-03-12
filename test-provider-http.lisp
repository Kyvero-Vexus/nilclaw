;;;; Test nilclaw provider HTTP

(require :asdf)
(push (truename ".") asdf:*central-registry*)
(require :dexador)
(asdf:load-system "nilclaw")

(format t "~%=== Enable Dexador Backend ===~%")
(handler-case
    (progn
      (nilclaw/provider:enable-dexador-backend)
      (format t "Backend enabled: ~A~%" (nilclaw/provider:http-backend-enabled-p)))
  (error (e)
    (format t "ERROR: ~A~%" e)))

(format t "~%=== Test HTTP Backend Request ===~%")
(let* ((url "https://openrouter.ai/api/v1/chat/completions")
       (api-key "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")
       (body "{\"model\":\"openai/gpt-4o-mini\",\"messages\":[{\"role\":\"user\",\"content\":\"Say hello\"}]}"))
  ;; Set headers
  (setf nilclaw/provider:*current-provider-headers*
        `(("Authorization" . ,(format nil "Bearer ~A" api-key))
          ("Content-Type" . "application/json")))
  (format t "Headers set: ~S~%" nilclaw/provider:*current-provider-headers*)
  (multiple-value-bind (content status headers)
      (nilclaw/provider:http-backend-request url :post body)
    (format t "HTTP backend request result:~%")
    (format t "  Status: ~A~%" status)
    (format t "  Content: ~A chars~%" (if content (length content) "NIL"))
    (when content
      (format t "  Preview: ~A...~%" (subseq content 0 (min 200 (length content)))))))

(format t "~%=== Test Full Provider Flow ===~%")
(multiple-value-bind (cfg path) (nilclaw/config:load-config)
  (declare (ignore path))
  (multiple-value-bind (runtime found-p) 
      (nilclaw/config:make-provider-runtime-from-config cfg "openrouter")
    (format t "Runtime created: ~A, found: ~A~%" (not (null runtime)) found-p)
    (when runtime
      (format t "  base-url: ~A~%" (nilclaw/provider:provider-runtime-base-url runtime))
      (format t "  api-key: ~A~%" (if (nilclaw/provider:provider-runtime-api-key runtime)
                                     (format nil "~A***" (subseq (nilclaw/provider:provider-runtime-api-key runtime) 0 8))
                                     "NIL"))
      ;; Create request
      (let ((request (nilclaw/provider:make-provider-request
                      :model "openai/gpt-4o-mini"
                      :messages '(("role" . "user") ("content" . "Say hello")))))
        (format t "Request created~%")
        ;; Test transport
        (let* ((backoff (nilclaw/provider:make-backoff-config))
               (http-result (nilclaw/provider:http-transport-with-backoff request runtime backoff)))
          (format t "HTTP transport result:~%")
          (format t "  Status: ~A~%" (nilclaw/provider:http-transport-result-status http-result))
          (format t "  Error: ~A~%" (nilclaw/provider:http-transport-result-error-code http-result))
          (format t "  Content: ~A~%" (if (nilclaw/provider:http-transport-result-content http-result)
                                        (subseq (nilclaw/provider:http-transport-result-content http-result) 0 (min 100 (length (nilclaw/provider:http-transport-result-content http-result))))
                                        "NIL")))))))

(finish-output)
(sb-ext:quit :unix-status 0)
