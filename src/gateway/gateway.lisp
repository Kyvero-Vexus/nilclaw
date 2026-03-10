(in-package #:nilclaw/gateway)

(declaim (optimize (safety 3) (debug 3)))

(defstruct gateway-runtime
  (name "nilclaw-gateway" :type string)
  (enabled t :type boolean)
  (port 3000 :type (integer 1 65535)))

(defstruct gateway-request
  (id "" :type string)
  (method "" :type string)
  (params nil :type list))

(defstruct gateway-response
  (id "" :type string)
  (ok-p nil :type boolean)
  (result nil :type t)
  (error-code nil :type (or null keyword))
  (error-message nil :type (or null string)))

(declaim (ftype (function () gateway-runtime) make-default-gateway-runtime))
(defun make-default-gateway-runtime ()
  (make-gateway-runtime))

(declaim (ftype (function (&optional gateway-runtime) boolean) gateway-runtime-ready-p))
(defun gateway-runtime-ready-p (&optional (runtime (make-default-gateway-runtime)))
  (declare (type gateway-runtime runtime))
  (and (gateway-runtime-enabled runtime)
       (> (length (gateway-runtime-name runtime)) 0)
       (<= 1 (gateway-runtime-port runtime) 65535)))

(declaim (ftype (function (string list) gateway-response) malformed-request-response))
(defun malformed-request-response (request-id message)
  (declare (type string request-id)
           (type list message))
  (make-gateway-response
   :id request-id
   :ok-p nil
   :error-code :malformed-request
   :error-message (format nil "Malformed request:~{ ~a~}" message)))

(declaim (ftype (function (gateway-request) gateway-response) gateway-handle-request))
(defun gateway-handle-request (request)
  (declare (type gateway-request request))
  (let ((request-id (gateway-request-id request))
        (method (gateway-request-method request))
        (params (gateway-request-params request)))
    (cond
      ((zerop (length request-id))
       (malformed-request-response "" (list "missing id")))
      ((zerop (length method))
       (malformed-request-response request-id (list "missing method")))
      ((not (listp params))
       (malformed-request-response request-id (list "params must be list")))
      ((string= method "ping")
       (make-gateway-response :id request-id :ok-p t :result '(:pong t)))
      ((string= method "sessions.list")
       (make-gateway-response :id request-id :ok-p t :result '(:sessions ())))
      (t
       (make-gateway-response
        :id request-id
        :ok-p nil
        :error-code :unknown-method
        :error-message (format nil "Unknown method: ~a" method))))))