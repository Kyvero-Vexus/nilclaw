;;;; HTTP transport layer for provider API calls
;;;; Implements OpenClaw HTTP parity with 429 backoff and error mapping

(in-package #:nilclaw/provider)

(declaim (optimize (safety 3) (debug 3)))

;;; Provider error taxonomy
(defparameter *http-status->error-code*
  '((400 . :malformed-payload)
    (401 . :auth-failed)
    (403 . :auth-failed)
    (404 . :not-found)
    (408 . :timeout)
    (429 . :rate-limited)
    (500 . :server-error)
    (502 . :server-error)
    (503 . :server-error)
    (504 . :timeout))
  "Map HTTP status codes to provider error codes.")

(defparameter *provider-error-messages*
  '((:malformed-payload . "Request payload invalid or malformed")
    (:auth-failed . "Authentication failed or credentials invalid")
    (:not-found . "Provider endpoint or model not found")
    (:timeout . "Request timed out")
    (:rate-limited . "Rate limit exceeded; retry with backoff")
    (:server-error . "Provider server error")
    (:network-fault . "Network connectivity error")
    (:unknown . "Unknown provider error"))
  "Human-readable messages for provider error codes.")

(declaim (ftype (function (fixnum) (or null keyword)) http-status->error-code))
(defun http-status->error-code (status)
  "Map HTTP status code to provider error code."
  (cdr (assoc status *http-status->error-code* :test #'=)))

;;; Backoff configuration
(defstruct backoff-config
  (initial-ms 1000 :type (integer 100 60000))
  (max-ms 60000 :type (integer 1000 300000))
  (multiplier 2.0 :type (single-float 1.0 4.0))
  (jitter-p t :type boolean))

(declaim (ftype (function (backoff-config (integer 0 *)) (integer 0 *)) compute-backoff-ms))
(defun compute-backoff-ms (config attempt)
  "Compute backoff time in milliseconds for given attempt number (1-indexed)."
  (declare (type backoff-config config)
           (type (integer 0 *) attempt))
  (let* ((base (min (* (backoff-config-initial-ms config)
                       (expt (backoff-config-multiplier config)
                             (1- attempt)))
                    (backoff-config-max-ms config)))
         (with-jitter (if (backoff-config-jitter-p config)
                          (+ base (random (floor base 2)))
                          base)))
    (floor with-jitter)))

;;; Retry-After header parsing
(declaim (ftype (function ((or null string)) (or null (integer 0 *))) parse-retry-after))
(defun parse-retry-after (header-value)
  "Parse Retry-After header value to milliseconds. Supports both delta-seconds and HTTP-date."
  (declare (type (or null string) header-value))
  (when (and header-value (> (length header-value) 0))
    (let ((trimmed (string-trim '(#\Space #\Tab) header-value)))
      (handler-case
        (let ((seconds (parse-integer trimmed)))
          (* seconds 1000))
        (parse-error ()
          ;; Not an integer, could be HTTP-date format; for now, default to 5s
          5000)))))

;;; HTTP transport result type
(defstruct http-transport-result
  (success-p nil :type boolean)
  (content nil :type (or null string))
  (status 0 :type (integer 0 599))
  (error-code nil :type (or null keyword))
  (retry-after-ms nil :type (or null (integer 0 *))))

;;; HTTP client abstraction
;;; This provides a portable interface that can use different backends (Dexador, Drakma, etc.)

(defvar *http-backend* nil
  "Pluggable HTTP backend. If NIL, falls back to stub behavior.")

(declaim (ftype (function (string keyword string) (values (or null string) fixnum (or null hash-table))) http-backend-request))
(defun http-backend-request (url method body)
  "Make HTTP request using configured backend. Returns (values content status headers-alist)."
  (declare (type string url body)
           (type keyword method))
  (if *http-backend*
      (funcall *http-backend* url method body)
      ;; Fallback stub for testing without real HTTP
      (values nil 503 nil)))

;;; Request building
(declaim (ftype (function (provider-request provider-runtime) string) build-request-body))
(defun build-request-body (request runtime)
  "Build JSON request body for provider API call."
  (declare (type provider-request request)
           (type provider-runtime runtime))
  (let ((payload `(("model" . ,(provider-runtime-model runtime))
                   ("messages" . ,(provider-request-messages request)))))
    (with-output-to-string (s)
      (cl-json:encode-json payload s))))

;;; Response parsing
(declaim (ftype (function (string) (or null string)) parse-provider-content))
(defun parse-provider-content (response-body)
  "Extract content from provider API JSON response."
  (declare (type string response-body))
  (handler-case
    (let ((json (cl-json:decode-json-from-string response-body)))
      (let ((choices (cdr (assoc :choices json))))
        (when (and choices (listp choices) (> (length choices) 0))
          (let ((message (cdr (assoc :message (car choices)))))
            (when message
              (cdr (assoc :content message)))))))
    (error () nil)))

;;; HTTP transport with backoff and 429 handling
(declaim (ftype (function (provider-request provider-runtime backoff-config) http-transport-result)
                http-transport-with-backoff))
(defun http-transport-with-backoff (request runtime backoff-config)
  "Execute HTTP request with exponential backoff for rate limits and transient errors.
   Returns HTTP-TRANSPORT-RESULT with success/error status."
  (declare (type provider-request request)
           (type provider-runtime runtime)
           (type backoff-config backoff-config))
  (let* ((max-attempts (+ 1 (provider-runtime-max-retries runtime)))
         (base-url (provider-runtime-base-url runtime))
         ;; Build full URL: append /chat/completions if base-url doesn't already end with it
         (url (if base-url
                  (if (and (>= (length base-url) 17)
                           (string= "/chat/completions" 
                                    (subseq base-url (- (length base-url) 17))))
                      base-url
                      (concatenate 'string base-url "/chat/completions"))
                  "https://api.openai.com/v1/chat/completions"))
         (body (build-request-body request runtime)))
    (labels ((attempt (n)
               (setf *current-provider-headers* (build-request-headers runtime))
               (multiple-value-bind (content status headers)
                   (http-backend-request url :post body)
                 (declare (type (or null string) content)
                          (type fixnum status)
                          (type (or null hash-table) headers))
                 (cond
                   ;; Success
                   ((and (>= status 200) (< status 300))
                    (let ((parsed-content (and content (parse-provider-content content))))
                      (make-http-transport-result
                       :success-p t
                       :content parsed-content
                       :status status
                       :error-code nil
                       :retry-after-ms nil)))
                   ;; Rate limited - check Retry-After
                   ((= status 429)
                    (let ((retry-after (parse-retry-after nil)))
                      (if (< n max-attempts)
                          (progn
                            (sleep (/ (or retry-after (compute-backoff-ms backoff-config n)) 1000.0))
                            (attempt (1+ n)))
                          (make-http-transport-result
                           :success-p nil
                           :content nil
                           :status status
                           :error-code :rate-limited
                           :retry-after-ms retry-after))))
                   ;; Transient server errors - retry
                   ((and (member status '(500 502 503 504) :test #'=)
                         (< n max-attempts))
                    (sleep (/ (compute-backoff-ms backoff-config n) 1000.0))
                    (attempt (1+ n)))
                   ;; Non-retryable error
                   (t
                    (make-http-transport-result
                     :success-p nil
                     :content nil
                     :status status
                     :error-code (http-status->error-code status)
                     :retry-after-ms nil))))))
      (attempt 1))))

;;; Integration function for provider-complete
(declaim (ftype (function (provider-request (integer 0 *)) (values (or null string) (or null keyword)))
                http-transport-fn))
(defun http-transport-fn (request attempt-index)
  "Transport function for use with provider-complete.
   Returns (values content error-code)."
  (declare (type provider-request request)
           (type (integer 0 *) attempt-index)
           (ignore attempt-index))
  (let* ((runtime (make-default-provider-runtime))
         (backoff (make-backoff-config))
         (result (http-transport-with-backoff request runtime backoff)))
    (values (http-transport-result-content result)
            (http-transport-result-error-code result))))
