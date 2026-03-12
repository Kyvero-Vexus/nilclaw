;;;; Auto-reply system for web channels
;;;; Implements intelligent auto-reply behavior with rules engine

(in-package #:nilclaw/channel)

(declaim (optimize (safety 3) (debug 3)))

;;; Auto-reply configuration

(defstruct auto-reply-rule
  "A single auto-reply rule."
  (name "" :type string)
  (trigger-type :keyword :type (member :keyword :regex :exact))
  (trigger-pattern "" :type string)
  (response "" :type string)
  (enabled t :type boolean)
  (priority 0 :type (integer 0 1000)))

(defstruct auto-reply-config
  "Configuration for auto-reply system."
  (enabled t :type boolean)
  (max-replies-per-hour 10 :type (integer 0 100))
  (rules '() :type list)
  (fallback-response nil :type (or null string)))

;;; Auto-reply runtime

(defstruct auto-reply-runtime
  "Runtime state for auto-reply system."
  (config (make-auto-reply-config) :type auto-reply-config)
  (reply-counters (make-hash-table :test 'equal) :type hash-table)
  (mutex (sb-thread:make-mutex) :type sb-thread:mutex))

(declaim (ftype (function () auto-reply-runtime) make-default-auto-reply-runtime))
(defun make-default-auto-reply-runtime ()
  "Create auto-reply runtime with default configuration."
  (make-auto-reply-runtime))

;;; Rule matching

(declaim (ftype (function (auto-reply-rule string) boolean) rule-matches-p))
(defun rule-matches-p (rule message)
  "Check if a rule matches the given message."
  (declare (type auto-reply-rule rule)
           (type string message))
  (unless (auto-reply-rule-enabled rule)
    (return-from rule-matches-p nil))
  (case (auto-reply-rule-trigger-type rule)
    (:keyword
     (not (null (search (auto-reply-rule-trigger-pattern rule) message :test #'char-equal))))
    (:exact
     (string= (auto-reply-rule-trigger-pattern rule) message))
    (:regex
     (handler-case
       (not (null (cl-ppcre:scan (auto-reply-rule-trigger-pattern rule) message)))
       (error () nil)))
    (t nil)))

;;; Rate limiting

(declaim (ftype (function (auto-reply-runtime string) boolean) can-reply-p))
(defun can-reply-p (runtime session-key)
  "Check if we can send an auto-reply to this session (rate limiting)."
  (declare (type auto-reply-runtime runtime)
           (type string session-key))
  (let ((max-per-hour (auto-reply-config-max-replies-per-hour
                       (auto-reply-runtime-config runtime))))
    (when (= max-per-hour 0)
      (return-from can-reply-p t))
    (sb-thread:with-mutex ((auto-reply-runtime-mutex runtime))
      (let* ((now (get-universal-time))
             (counter (gethash session-key (auto-reply-runtime-reply-counters runtime)))
             (window-start (car counter))
             (count (cdr counter)))
        ;; Reset if outside hour window
        (when (or (null counter)
                  (> (- now window-start) 3600))
          (setf (gethash session-key (auto-reply-runtime-reply-counters runtime))
                (cons now 0))
          (return-from can-reply-p t))
        ;; Check limit
        (< count max-per-hour)))))

(declaim (ftype (function (auto-reply-runtime string) (values null null)) record-reply))
(defun record-reply (runtime session-key)
  "Record that we sent an auto-reply to this session."
  (declare (type auto-reply-runtime runtime)
           (type string session-key))
  (sb-thread:with-mutex ((auto-reply-runtime-mutex runtime))
    (let* ((now (get-universal-time))
           (counter (gethash session-key (auto-reply-runtime-reply-counters runtime))))
      (if (and counter (< (- now (car counter)) 3600))
          (incf (cdr counter))
          (setf (gethash session-key (auto-reply-runtime-reply-counters runtime))
                (cons now 1)))))
  (values nil nil))

;;; Main auto-reply handler

(declaim (ftype (function (auto-reply-runtime string string) (or null string))
                compute-auto-reply))
(defun compute-auto-reply (runtime message session-key)
  "Compute auto-reply for a message. Returns nil if no reply should be sent."
  (declare (type auto-reply-runtime runtime)
           (type string message session-key))
  (let ((config (auto-reply-runtime-config runtime)))
    ;; Check if auto-reply is enabled
    (unless (auto-reply-config-enabled config)
      (return-from compute-auto-reply nil))
    
    ;; Check rate limiting
    (unless (can-reply-p runtime session-key)
      (return-from compute-auto-reply nil))
    
    ;; Sort rules by priority (highest first)
    (let ((sorted-rules (sort (copy-list (auto-reply-config-rules config))
                              #'>
                              :key #'auto-reply-rule-priority)))
      ;; Find first matching rule
      (dolist (rule sorted-rules)
        (when (rule-matches-p rule message)
          (record-reply runtime session-key)
          (return-from compute-auto-reply
            (auto-reply-rule-response rule)))))
    
    ;; No rule matched - use fallback if configured
    (let ((fallback (auto-reply-config-fallback-response config)))
      (when (and fallback (> (length fallback) 0))
        (record-reply runtime session-key)
        fallback))))

;;; Web channel auto-reply integration

(defmethod channel-receive-with-auto-reply ((channel web-channel) runtime message session-key)
  "Handle incoming message on web channel with auto-reply support.
   Returns (values auto-reply-response should-reply-p)."
  (declare (type web-channel channel)
           (type auto-reply-runtime runtime)
           (type string message session-key))
  (let ((response (compute-auto-reply runtime message session-key)))
    (values response (not (null response)))))
