(in-package #:nilclaw/tests)
(in-suite gateway-http-suite)

;;; --- JSON round-trip tests ---

(test plist-to-json-basic
  "plist-to-json encodes basic types correctly."
  (let ((json (nilclaw/gateway:plist-to-json '(:status "ok" :count 42 :ready t))))
    (is (stringp json))
    (is (search "\"status\":\"ok\"" json))
    (is (search "\"count\":42" json))
    (is (search "\"ready\":true" json))))

(test plist-to-json-null
  "plist-to-json encodes nil as null."
  (let ((json (nilclaw/gateway:plist-to-json '(:value nil))))
    (is (search "\"value\":null" json))))

(test plist-to-json-nested
  "plist-to-json encodes nested plists."
  (let ((json (nilclaw/gateway:plist-to-json '(:outer (:inner "deep")))))
    (is (search "\"outer\":{\"inner\":\"deep\"}" json))))

(test json-to-plist-basic
  "json-to-plist decodes basic JSON object."
  (let ((plist (nilclaw/gateway:json-to-plist "{\"message\":\"hello\",\"count\":5}")))
    (is (listp plist))
    (is (string= "hello" (getf plist :message)))
    (is (= 5 (getf plist :count)))))

;;; --- HTTP server lifecycle tests ---

(test http-server-start-stop
  "HTTP server can be started and stopped."
  (let ((port (+ 19000 (random 1000))))
    (unwind-protect
        (progn
          (nilclaw/gateway:start-http-server :port port)
          (is (nilclaw/gateway:http-server-running-p))
          (nilclaw/gateway:stop-http-server)
          (is (not (nilclaw/gateway:http-server-running-p))))
      ;; Ensure cleanup
      (nilclaw/gateway:stop-http-server))))

;;; --- Endpoint integration tests (require running server) ---

(defun with-test-server (thunk &optional (port (+ 19000 (random 1000))))
  "Run THUNK with a temporary HTTP server on PORT."
  (let ((runtime (nilclaw/gateway:make-gateway-runtime :port port)))
    (nilclaw/gateway:start-http-server :port port :runtime runtime)
    (sleep 0.2) ; let server bind
    (unwind-protect
        (funcall thunk port)
      (nilclaw/gateway:stop-http-server))))

(test http-health-endpoint
  "GET /health returns OK with 200."
  (with-test-server
    (lambda (port)
      (multiple-value-bind (body status)
          (drakma:http-request (format nil "http://127.0.0.1:~D/health" port))
        (is (= 200 status))
        (is (string= "OK" (if (stringp body) body
                               (babel:octets-to-string body))))))))

(test http-status-endpoint
  "GET /status returns JSON with running status."
  (with-test-server
    (lambda (port)
      (multiple-value-bind (body status)
          (drakma:http-request (format nil "http://127.0.0.1:~D/status" port))
        (is (= 200 status))
        (let* ((text (if (stringp body) body (babel:octets-to-string body)))
               (parsed (nilclaw/gateway:json-to-plist text)))
          (is (string= "running" (getf parsed :status))))))))

(test http-chat-endpoint
  "POST /chat with message returns success."
  (with-test-server
    (lambda (port)
      (multiple-value-bind (body status)
          (drakma:http-request (format nil "http://127.0.0.1:~D/chat" port)
                               :method :post
                               :content-type "application/json"
                               :content "{\"message\":\"hello\",\"sessionKey\":\"test-session\"}")
        (is (= 200 status))
        (let* ((text (if (stringp body) body (babel:octets-to-string body)))
               (parsed (nilclaw/gateway:json-to-plist text)))
          (is (eq t (getf parsed :ok))))))))

(test http-chat-endpoint-empty-body
  "POST /chat with empty body still returns a response (auto-creates session)."
  (with-test-server
    (lambda (port)
      (multiple-value-bind (body status)
          (drakma:http-request (format nil "http://127.0.0.1:~D/chat" port)
                               :method :post
                               :content-type "application/json"
                               :content "{\"message\":\"test\"}")
        ;; Should succeed with auto-created session
        (is (= 200 status))
        (let* ((text (if (stringp body) body (babel:octets-to-string body))))
          (is (> (length text) 0)))))))
