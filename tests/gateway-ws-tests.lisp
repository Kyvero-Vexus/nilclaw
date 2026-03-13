;;;; gateway-ws-tests.lisp — WebSocket transport integration tests
;;;; Tests wire-format serialization and real WebSocket handshake/protocol flow.

(in-package #:nilclaw/tests)
(in-suite gateway-ws-suite)

;;; --- Wire-format unit tests ---

(test response-to-wire-json-ok
  "response-to-wire-json encodes success responses correctly."
  (let* ((resp (nilclaw/gateway:make-gateway-response
                :id "req-1"
                :ok-p t
                :result '(:pong t)))
         (json (nilclaw/gateway:response-to-wire-json resp)))
    (is (stringp json))
    (is (search "\"type\":\"res\"" json))
    (is (search "\"id\":\"req-1\"" json))
    (is (search "\"ok\":true" json))
    (is (search "\"pong\":true" json))))

(test response-to-wire-json-error
  "response-to-wire-json encodes error responses correctly."
  (let* ((resp (nilclaw/gateway:make-gateway-response
                :id "req-2"
                :ok-p nil
                :error-message "something broke"))
         (json (nilclaw/gateway:response-to-wire-json resp)))
    (is (search "\"ok\":false" json))
    ;; Should not have payload
    (is (not (search "\"payload\"" json)))
    ;; Should have error.message
    (is (search "\"message\":\"something broke\"" json))))

(test event-to-wire-json-basic
  "event-to-wire-json encodes events in the OpenClaw wire format."
  (let ((json (nilclaw/gateway:event-to-wire-json "connect.challenge"
                                                    '(:nonce "abc123")
                                                    nil)))
    (is (search "\"type\":\"event\"" json))
    (is (search "\"event\":\"connect.challenge\"" json))
    (is (search "\"nonce\":\"abc123\"" json))
    ;; No seq when nil
    (is (not (search "\"seq\"" json)))))

(test event-to-wire-json-with-seq
  "event-to-wire-json includes seq when provided."
  (let ((json (nilclaw/gateway:event-to-wire-json "tick" nil 42)))
    (is (search "\"seq\":42" json))))

(test wire-json-to-request-valid
  "wire-json-to-request parses valid request frames."
  (let ((req (nilclaw/gateway:wire-json-to-request
              "{\"type\":\"req\",\"id\":\"r1\",\"method\":\"ping\",\"params\":{}}")))
    (is (not (null req)))
    (is (string= "r1" (nilclaw/gateway:gateway-request-id req)))
    (is (string= "ping" (nilclaw/gateway:gateway-request-method req)))))

(test wire-json-to-request-with-params
  "wire-json-to-request handles nested params."
  (let ((req (nilclaw/gateway:wire-json-to-request
              "{\"type\":\"req\",\"id\":\"r2\",\"method\":\"connect\",\"params\":{\"minProtocol\":3,\"maxProtocol\":3,\"client\":{\"id\":\"test\"}}}")))
    (is (not (null req)))
    (is (string= "connect" (nilclaw/gateway:gateway-request-method req)))
    (let ((params (nilclaw/gateway:gateway-request-params req)))
      (is (listp params)))))

(test wire-json-to-request-invalid
  "wire-json-to-request returns NIL for invalid frames."
  (is (null (nilclaw/gateway:wire-json-to-request "not json")))
  (is (null (nilclaw/gateway:wire-json-to-request "{\"type\":\"event\"}")))
  (is (null (nilclaw/gateway:wire-json-to-request "{\"type\":\"req\"}"))))

(test alist-to-plist-deep-basic
  "alist-to-plist-deep recursively converts CL-JSON alists."
  (let ((result (nilclaw/gateway:alist-to-plist-deep
                 '((:a . 1) (:b . ((:c . 2)))))))
    (is (= 1 (getf result :a)))
    (let ((inner (getf result :b)))
      (is (= 2 (getf inner :c))))))

;;; --- WebSocket integration tests (real socket) ---

(defun ws-handshake-test-port ()
  "Return a random high port for WS integration tests."
  (+ 19500 (random 500)))

(defun with-ws-test-server (thunk &optional (port (ws-handshake-test-port)))
  "Start a gateway server with WebSocket support, run THUNK with PORT, then stop."
  (let ((runtime (nilclaw/gateway:make-gateway-runtime :port port)))
    (nilclaw/gateway:start-http-server :port port :runtime runtime)
    (sleep 0.3) ; let server bind
    (unwind-protect
        (funcall thunk port)
      (nilclaw/gateway:stop-http-server))))

(test ws-http-health-still-works
  "HTTP /health endpoint still works when using websocket-acceptor."
  (with-ws-test-server
    (lambda (port)
      (multiple-value-bind (body status)
          (drakma:http-request (format nil "http://127.0.0.1:~D/health" port))
        (is (= 200 status))
        (is (string= "OK" (if (stringp body) body
                               (babel:octets-to-string body))))))))

(test ws-upgrade-handshake
  "WebSocket upgrade handshake succeeds (HTTP 101) on the gateway port."
  (with-ws-test-server
    (lambda (port)
      ;; Send a WebSocket upgrade request using raw drakma
      (let* ((ws-key (babel:octets-to-string
                      (ironclad:make-random-salt 16)
                      :encoding :latin-1))
             (ws-key-b64 (with-output-to-string (s)
                           ;; Simple base64 of 16 random bytes for Sec-WebSocket-Key
                           (write-string
                            (cl-base64:usb8-array-to-base64-string
                             (ironclad:make-random-salt 16))
                            s))))
        (multiple-value-bind (body status headers)
            (drakma:http-request (format nil "http://127.0.0.1:~D/" port)
                                 :additional-headers
                                 `(("Upgrade" . "websocket")
                                   ("Connection" . "Upgrade")
                                   ("Sec-WebSocket-Key" . ,ws-key-b64)
                                   ("Sec-WebSocket-Version" . "13"))
                                 :close t)
          (declare (ignore body))
          (is (= 101 status)
              (format nil "Expected 101 Switching Protocols, got ~D" status)))))))

(defun write-ws-test-script (port path)
  "Write a node.js WebSocket test script to PATH for the gateway on PORT."
  (declare (type (integer 1 65535) port)
           (type string path))
  (with-open-file (f path :direction :output :if-exists :supersede)
    (format f "const WebSocket = require('ws');~%")
    (format f "const ws = new WebSocket('ws://127.0.0.1:~D');~%" port)
    (format f "let step = 0;~%")
    (format f "const timeout = setTimeout(() => { console.log('TIMEOUT'); process.exit(1); }, 5000);~%")
    (format f "ws.on('message', (data) => {~%")
    (format f "  const msg = JSON.parse(data.toString());~%")
    (format f "  if (msg.type === 'event' && msg.event === 'connect.challenge' && step === 0) {~%")
    (format f "    step = 1;~%")
    (format f "    console.log('CHALLENGE_OK nonce=' + msg.payload.nonce);~%")
    (format f "    ws.send(JSON.stringify({type:'req',id:'c1',method:'connect',params:{minProtocol:3,maxProtocol:3,client:{id:'test-node',displayName:'Test'}}}));~%")
    (format f "  } else if (msg.type === 'res' && msg.id === 'c1' && step === 1) {~%")
    (format f "    if (msg.ok) { step = 2; console.log('CONNECT_OK'); ws.send(JSON.stringify({type:'req',id:'p1',method:'ping',params:{}})); }~%")
    (format f "    else { console.log('CONNECT_FAIL ' + JSON.stringify(msg.error)); clearTimeout(timeout); process.exit(1); }~%")
    (format f "  } else if (msg.type === 'res' && msg.id === 'p1' && step === 2) {~%")
    (format f "    if (msg.ok) { console.log('PING_OK'); clearTimeout(timeout); ws.close(); process.exit(0); }~%")
    (format f "  }~%")
    (format f "});~%")
    (format f "ws.on('error', (e) => { console.log('ERROR ' + e.message); clearTimeout(timeout); process.exit(1); });~%")))

(test ws-full-connect-flow-via-node
  "Full WebSocket connect flow: challenge → connect → ping, using node subprocess."
  (with-ws-test-server
    (lambda (port)
      (let ((script-path "/tmp/nilclaw-ws-test.js"))
        (write-ws-test-script port script-path)
        (let ((result (uiop:run-program
                       (list "node" script-path)
                       :output :string
                       :error-output :string
                       :ignore-error-status t)))
          (is (search "CHALLENGE_OK" result)
              (format nil "Expected CHALLENGE_OK in output: ~A" result))
          (is (search "CONNECT_OK" result)
              (format nil "Expected CONNECT_OK in output: ~A" result))
          (is (search "PING_OK" result)
              (format nil "Expected PING_OK in output: ~A" result)))))))
