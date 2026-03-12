;;;; Dexador HTTP backend for provider transport (optional)

(in-package #:nilclaw/provider)

(declaim (optimize (safety 3) (debug 3)))

;;; Dexador backend implementation
;;; This provides real HTTP transport for production use when Dexador is available.

(defvar *dexador-available-p* nil
  "Whether Dexador is available for use.")

(defvar *dexador-error-backend-p* nil
  "Track if we tried to load dexador and it failed.")

(eval-when (:load-toplevel :execute)
  (handler-case
    (progn
      (require :dexador)
      (setf *dexador-available-p* t))
    (error ()
      (setf *dexador-available-p* nil)
      (setf *dexador-error-backend-p* t))))

(declaim (ftype (function (string) string) build-auth-header))
(defun build-auth-header (api-key)
  "Build Authorization header value for Bearer token auth."
  (declare (type string api-key))
  (format nil "Bearer ~A" api-key))

(declaim (ftype (function (provider-runtime) list) build-request-headers))
(defun build-request-headers (runtime)
  "Build HTTP headers for provider request."
  (declare (type provider-runtime runtime))
  (let ((api-key (provider-runtime-api-key runtime)))
    (if (and api-key (> (length api-key) 0))
        `(("Authorization" . ,(build-auth-header api-key))
          ("Content-Type" . "application/json"))
        '(("Content-Type" . "application/json")))))

;;; Stub implementation when Dexador is not available
(defun dexador-backend-stub (url method body)
  "Stub backend that returns 503 when Dexador is not installed."
  (declare (type string url body)
           (type keyword method)
           (ignore url method body))
  (values nil 503 nil))

(defun dexador-backend (url method body)
  "Dexador-based HTTP backend implementation.
   Returns (values content status headers-alist).
   Falls back to stub if Dexador is not available."
  (declare (type string url body)
           (type keyword method))
  (unless *dexador-available-p*
    (return-from dexador-backend
      (dexador-backend-stub url method body)))
  ;; Call dexador via late binding to avoid compile-time errors
  (let ((dex-request (find-symbol "REQUEST" :dexador)))
    (unless dex-request
      (return-from dexador-backend
        (dexador-backend-stub url method body)))
    (handler-case
        (multiple-value-bind (response-body status response-headers)
            (funcall (symbol-function dex-request)
                     url
                     :method method
                     :content body
                     :headers *current-provider-headers*
                     :want-stream nil
                     :force-string t)
          (declare (type fixnum status))
          (values (if (stringp response-body) response-body nil)
                  status
                  response-headers))
      (error (e)
        ;; Network error — return 0 status to signal network-fault
        (declare (ignore e))
        (values nil 0 nil)))))

(defun enable-dexador-backend ()
  "Enable Dexador as the HTTP backend for provider requests."
  (if *dexador-available-p*
      (setf *http-backend* #'dexador-backend)
      (error "Dexador is not available on this system")))

(defun disable-http-backend ()
  "Disable custom HTTP backend, reverting to stub behavior."
  (setf *http-backend* nil))

(defun http-backend-enabled-p ()
  "Check if a real HTTP backend is currently enabled."
  (and *http-backend* 
       (not (eq *http-backend* #'dexador-backend-stub))))
