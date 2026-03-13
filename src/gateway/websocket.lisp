;;;; websocket.lisp — Hunchensocket WebSocket transport for NilClaw gateway
;;;; Implements the OpenClaw gateway wire protocol over WebSocket:
;;;;   Event frame:    {"type":"event","event":"...","payload":{...},"seq":N}
;;;;   Request frame:  {"type":"req","id":"...","method":"...","params":{...}}
;;;;   Response frame: {"type":"res","id":"...","ok":true/false,"payload":{...},"error":{"message":"..."}}

(in-package #:nilclaw/gateway)

(declaim (optimize (safety 3) (debug 3)))

;;; --- Wire-format JSON helpers ---

(declaim (ftype (function (gateway-response) string) response-to-wire-json))
(defun response-to-wire-json (response)
  "Serialize a GATEWAY-RESPONSE into the OpenClaw wire JSON format."
  (declare (type gateway-response response))
  ;; Use :false sentinel to avoid nil→null in plist-to-json
  (let ((parts (list :type "res"
                      :id (gateway-response-id response)
                      :ok (if (gateway-response-ok-p response) t :false))))
    (if (gateway-response-ok-p response)
        (let ((result (gateway-response-result response)))
          (setf (getf parts :payload) result))
        (let ((err-msg (or (gateway-response-error-message response) "unknown error")))
          (setf (getf parts :error) (list :message err-msg))))
    (plist-to-json parts)))

(declaim (ftype (function (string list &optional (or null (integer 0 *))) string) event-to-wire-json))
(defun event-to-wire-json (event-name payload &optional seq)
  "Serialize an event into the OpenClaw wire JSON format."
  (declare (type string event-name)
           (type list payload))
  (let ((parts (list :type "event"
                      :event event-name)))
    (when payload
      (setf (getf parts :payload) payload))
    (when seq
      (setf (getf parts :seq) seq))
    (plist-to-json parts)))

(declaim (ftype (function (string) (or null gateway-request)) wire-json-to-request))
(defun wire-json-to-request (json-string)
  "Parse a wire JSON string into a GATEWAY-REQUEST, or NIL on failure."
  (declare (type string json-string))
  (handler-case
      (let* ((decoded (json:decode-json-from-string json-string))
             (frame-type (cdr (assoc :type decoded :test #'eq)))
             (id (cdr (assoc :id decoded :test #'eq)))
             (method (cdr (assoc :method decoded :test #'eq)))
             (params-raw (cdr (assoc :params decoded :test #'eq))))
        (when (and (string= frame-type "req")
                   (stringp id)
                   (stringp method))
          (make-gateway-request
           :id id
           :method method
           :params (if (and params-raw (listp params-raw))
                       (alist-to-plist-deep params-raw)
                       nil))))
    (error () nil)))

(declaim (ftype (function (t) t) alist-to-plist-deep))
(defun alist-to-plist-deep (value)
  "Recursively convert alists (as CL-JSON produces) to plists.
Non-alist values pass through unchanged."
  (cond
    ((null value) nil)
    ((and (listp value)
          (consp (first value))
          (symbolp (car (first value))))
     ;; Looks like an alist
     (loop for (k . v) in value
           collect k
           collect (alist-to-plist-deep v)))
    ((listp value)
     (mapcar #'alist-to-plist-deep value))
    (t value)))

;;; --- Combined acceptor: easy-handler + websocket ---

(defclass gateway-ws-acceptor (hunchensocket:websocket-acceptor hunchentoot:easy-acceptor)
  ()
  (:documentation "An acceptor that handles both HTTP easy-handlers and WebSocket upgrades."))

;;; --- WebSocket resource & client ---

(defclass gateway-ws-resource (hunchensocket:websocket-resource)
  ((ws-runtime :initarg :runtime
               :accessor ws-resource-runtime
               :type gateway-runtime)
   (seq-counter :initform 1
                :accessor ws-resource-seq-counter
                :type (integer 0 *)))
  (:default-initargs :client-class 'gateway-ws-client))

(defclass gateway-ws-client (hunchensocket:websocket-client)
  ((connection :initform nil
               :accessor ws-client-connection
               :type (or null gateway-connection))))

(defvar *ws-resource* nil
  "The current WebSocket resource instance, set during server start.")

;;; --- WebSocket dispatch ---

(defun find-gateway-ws-resource (request)
  "Dispatch function for hunchensocket. Returns the WS resource for any path."
  (declare (ignore request))
  *ws-resource*)

;;; --- Protocol event helpers ---

(declaim (ftype (function (gateway-ws-client) null) ws-send-challenge))
(defun ws-send-challenge (client)
  "Send a connect.challenge event to CLIENT, creating a new connection state."
  (declare (type gateway-ws-client client))
  (let* ((rt (ws-resource-runtime *ws-resource*))
         (nonce (generate-nonce))
         (conn (make-gateway-connection :nonce nonce)))
    (setf (ws-client-connection client) conn)
    (let ((json (event-to-wire-json "connect.challenge"
                                     (list :nonce nonce))))
      (hunchensocket:send-text-message client json)))
  nil)

(declaim (ftype (function (gateway-ws-client string) null) ws-handle-request))
(defun ws-handle-request (client raw-message)
  "Parse and dispatch a request frame from CLIENT, send response."
  (declare (type gateway-ws-client client)
           (type string raw-message))
  (let ((request (wire-json-to-request raw-message)))
    (if (null request)
        ;; Malformed request — send error response
        (let ((err-json (response-to-wire-json
                         (malformed-request-response "unknown" (list "could not parse request frame")))))
          (hunchensocket:send-text-message client err-json))
        ;; Valid request — dispatch through gateway handler
        (let* ((rt (ws-resource-runtime *ws-resource*))
               (conn (ws-client-connection client))
               (response (gateway-handle-request request rt conn)))
          ;; Send response
          (hunchensocket:send-text-message client (response-to-wire-json response))
          ;; After connect, send a tick event (to confirm connection is alive)
          (when (and (string= (gateway-request-method request) "connect")
                     (gateway-response-ok-p response))
            ;; Flush any pending events from event-log to this client
            (ws-flush-events client)))))
  nil)

(declaim (ftype (function (gateway-ws-client) null) ws-flush-events))
(defun ws-flush-events (client)
  "Send any pending events from the runtime event-log to CLIENT.
This is called after connect and after chat operations."
  (declare (type gateway-ws-client client))
  (let* ((rt (ws-resource-runtime *ws-resource*))
         (events (reverse (gateway-runtime-event-log rt))))
    ;; Clear the log after flushing
    (setf (gateway-runtime-event-log rt) nil)
    (dolist (evt events)
      (let ((seq (ws-resource-seq-counter *ws-resource*)))
        (incf (ws-resource-seq-counter *ws-resource*))
        (cond
          ((gateway-event-p evt)
           (hunchensocket:send-text-message
            client
            (event-to-wire-json (gateway-event-event evt)
                                 (gateway-event-payload evt)
                                 seq)))
          ;; Method events stored as (:method-event . event)
          ((and (consp evt) (eq :method-event (car evt)))
           (let ((me (cdr evt)))
             (hunchensocket:send-text-message
              client
              (event-to-wire-json (gateway-method-event-method me)
                                   (gateway-method-event-params me)
                                   seq))))))))
  nil)

;;; --- Hunchensocket protocol methods ---

(defmethod hunchensocket:client-connected ((resource gateway-ws-resource) client)
  "Called when a new WebSocket client connects. Sends connect.challenge."
  (declare (type gateway-ws-resource resource)
           (type gateway-ws-client client)
           (ignorable resource))
  (ws-send-challenge client))

(defmethod hunchensocket:client-disconnected ((resource gateway-ws-resource) client)
  "Called when a WebSocket client disconnects."
  (declare (type gateway-ws-resource resource)
           (type gateway-ws-client client)
           (ignorable resource client))
  nil)

(defmethod hunchensocket:text-message-received ((resource gateway-ws-resource) client message)
  "Called when a text message is received from a WebSocket client."
  (declare (type gateway-ws-resource resource)
           (type gateway-ws-client client)
           (type string message)
           (ignorable resource))
  (ws-handle-request client message)
  ;; After handling, flush any new events
  (ws-flush-events client))
