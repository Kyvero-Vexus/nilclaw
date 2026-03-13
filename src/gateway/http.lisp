;;;; http.lisp — Hunchentoot-based HTTP server for NilClaw gateway
;;;; Provides REST endpoints: GET /health, POST /chat, GET /status

(in-package #:nilclaw/gateway)

(declaim (optimize (safety 3) (debug 3)))

;;; --- HTTP Server State ---

(defvar *http-server* nil
  "The running Hunchentoot acceptor, or NIL when stopped.")

(defvar *http-runtime* nil
  "The gateway-runtime backing the HTTP server.")

(defparameter *default-http-port* 18789
  "Default port for the gateway HTTP server.")

;;; --- JSON Helpers ---

(declaim (ftype (function (list) string) plist-to-json))
(defun plist-to-json (plist)
  "Encode a plist as a JSON object string.
Handles nested plists and lists of plists."
  (declare (type list plist))
  (with-output-to-string (s)
    (labels ((write-value (v)
               (cond
                 ((null v) (write-string "null" s))
                 ((eq v :false) (write-string "false" s))
                 ((eq v t) (write-string "true" s))
                 ((integerp v) (format s "~D" v))
                 ((floatp v) (format s "~F" v))
                 ((stringp v)
                  (write-char #\" s)
                  (loop for ch across v do
                    (case ch
                      (#\" (write-string "\\\"" s))
                      (#\\ (write-string "\\\\" s))
                      (#\Newline (write-string "\\n" s))
                      (#\Return (write-string "\\r" s))
                      (#\Tab (write-string "\\t" s))
                      (otherwise (write-char ch s))))
                  (write-char #\" s))
                 ((and (listp v) (keywordp (first v)))
                  ;; plist
                  (write-plist v))
                 ((listp v)
                  ;; array
                  (write-char #\[ s)
                  (loop for (item . rest) on v do
                    (write-value item)
                    (when rest (write-char #\, s)))
                  (write-char #\] s))
                 (t (format s "~S" v))))
             (write-plist (pl)
               (write-char #\{ s)
               (loop for (k v . rest) on pl by #'cddr
                     for first-p = t then nil
                     do (unless first-p (write-char #\, s))
                        (let ((key-str (string-downcase (symbol-name k))))
                          (write-char #\" s)
                          (write-string key-str s)
                          (write-char #\" s))
                        (write-char #\: s)
                        (write-value v))
               (write-char #\} s)))
      (if (and (listp plist) (keywordp (first plist)))
          (write-plist plist)
          (write-value plist)))))

(declaim (ftype (function (string) list) json-to-plist))
(defun json-to-plist (json-string)
  "Decode a JSON string into a plist using CL-JSON."
  (declare (type string json-string))
  (let ((decoded (json:decode-json-from-string json-string)))
    (alist-to-plist decoded)))

(declaim (ftype (function (list) list) alist-to-plist))
(defun alist-to-plist (alist)
  "Convert an alist (as returned by CL-JSON) to a plist."
  (declare (type list alist))
  (loop for (k . v) in alist
        collect k
        collect (cond
                  ((and (listp v) (consp (first v)) (symbolp (car (first v))))
                   (alist-to-plist v))
                  (t v))))

;;; --- Hunchentoot Easy Handlers ---

(hunchentoot:define-easy-handler (health-handler :uri "/health") ()
  "GET /health — health check, returns OK."
  (setf (hunchentoot:content-type*) "text/plain")
  "OK")

(hunchentoot:define-easy-handler (status-handler :uri "/status") ()
  "GET /status — returns session status as JSON."
  (setf (hunchentoot:content-type*) "application/json")
  (let* ((rt (or *http-runtime* (make-default-gateway-runtime)))
         (sessions (gateway-runtime-sessions rt))
         (agents (gateway-runtime-agents rt))
         (connections (gateway-runtime-connections rt)))
    (plist-to-json
     (list :status "running"
           :name (gateway-runtime-name rt)
           :port (gateway-runtime-port rt)
           :enabled (if (gateway-runtime-enabled rt) t nil)
           :sessions (length sessions)
           :agents (length agents)
           :connections (length connections)
           :ready (if (gateway-runtime-ready-p rt) t nil)))))

(hunchentoot:define-easy-handler (chat-handler :uri "/chat") ()
  "POST /chat — send message to agent."
  (setf (hunchentoot:content-type*) "application/json")
  (let ((body (hunchentoot:raw-post-data :force-text t)))
    (handler-case
        (let* ((params (if (and body (stringp body) (> (length body) 0))
                           (json-to-plist body)
                           nil))
               (session-key (or (getf params :session-key)
                                (getf params :session--key)
                                "default"))
               (message (or (getf params :message) ""))
               (rt (or *http-runtime* (make-default-gateway-runtime)))
               (request (make-gateway-request
                         :id (format nil "http-~A" (get-universal-time))
                         :method "chat.send"
                         :params (list :session-key session-key
                                       :message message)))
               (response (gateway-handle-request request rt)))
          (if (gateway-response-ok-p response)
              (plist-to-json
               (list :ok t
                     :result (gateway-response-result response)))
              (progn
                (setf (hunchentoot:return-code*) 400)
                (plist-to-json
                 (list :ok nil
                       :error (or (gateway-response-error-message response)
                                  "Unknown error"))))))
      (error (e)
        (setf (hunchentoot:return-code*) 500)
        (plist-to-json
         (list :ok nil
               :error (princ-to-string e)))))))

;;; --- Standalone handler functions for testing ---

(defun handle-health ()
  "Health check handler (for direct testing)."
  "OK")

(defun handle-status ()
  "Status handler (for direct testing)."
  (let* ((rt (or *http-runtime* (make-default-gateway-runtime))))
    (plist-to-json
     (list :status "running"
           :name (gateway-runtime-name rt)
           :port (gateway-runtime-port rt)))))

(defun handle-chat-post ()
  "Chat handler (for direct testing)."
  "use POST /chat endpoint")

;;; --- Server Lifecycle ---

(declaim (ftype (function (&key (:port (integer 1 65535))
                                (:runtime (or null gateway-runtime)))
                          t)
                start-http-server))
(defun start-http-server (&key (port *default-http-port*) runtime)
  "Start the Hunchentoot HTTP server on PORT.
Returns the acceptor."
  (declare (type (integer 1 65535) port))
  (when *http-server*
    (format *error-output* "[nilclaw-http] Server already running, stopping first...~%")
    (stop-http-server))
  (setf *http-runtime* (or runtime (make-default-gateway-runtime)))
  ;; Use websocket-acceptor to support both HTTP and WS on the same port.
  ;; The websocket-acceptor inherits from easy-acceptor, so easy-handlers work.
  (setf *ws-resource* (make-instance 'gateway-ws-resource
                                      :runtime (or runtime (make-default-gateway-runtime))))
  (setf hunchensocket:*websocket-dispatch-table*
        (list (lambda (request) (declare (ignore request)) *ws-resource*)))
  (let ((acceptor (make-instance 'gateway-ws-acceptor
                                 :port port
                                 :address "127.0.0.1")))
    ;; Suppress Hunchentoot's default logging to keep output clean
    (setf (hunchentoot:acceptor-message-log-destination acceptor) nil)
    (setf (hunchentoot:acceptor-access-log-destination acceptor) nil)
    (hunchentoot:start acceptor)
    (setf *http-server* acceptor)
    (format t "[nilclaw-http] HTTP server started on port ~D~%" port)
    acceptor))

(declaim (ftype (function () null) stop-http-server))
(defun stop-http-server ()
  "Stop the running HTTP server."
  (when *http-server*
    (hunchentoot:stop *http-server*)
    (format t "[nilclaw-http] HTTP server stopped~%")
    (setf *http-server* nil)
    (setf *http-runtime* nil)
    (setf *ws-resource* nil))
  nil)

(declaim (ftype (function () boolean) http-server-running-p))
(defun http-server-running-p ()
  "Return T if the HTTP server is currently running."
  (and *http-server*
       (hunchentoot:started-p *http-server*)
       t))
