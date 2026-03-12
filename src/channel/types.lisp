;;;; types.lisp - Channel system type definitions
;;;; NilClaw - Statically typed Common Lisp agent harness

(in-package #:nilclaw/channel)

(declaim (optimize (speed 3) (safety 3) (debug 1)))

;;; Outbound stage enumeration

(deftype outbound-stage ()
  '(member :chunk :final))

;;; Permission policies

(deftype dm-policy ()
  '(member :allow :deny :allowlist))

(deftype group-policy ()
  '(member :open :mention-only :allowlist))

;;; Channel message structure

(defstruct (channel-message
            (:constructor make-channel-message
                          (id sender content channel
                           &key timestamp reply-target message-id
                            first-name is-group sender-uuid group-id)))
  "Represents a message from a messaging channel."
  (id "" :type string :read-only t)
  (sender "" :type string :read-only t)
  (content "" :type string :read-only t)
  (channel "" :type string :read-only t)
  (timestamp 0 :type (unsigned-byte 64) :read-only t)
  (reply-target nil :type (or null string) :read-only t)
  (message-id nil :type (or null (signed-byte 64)) :read-only t)
  (first-name nil :type (or null string) :read-only t)
  (is-group nil :type boolean :read-only t)
  (sender-uuid nil :type (or null string) :read-only t)
  (group-id nil :type (or null string) :read-only t))

;;; Channel protocol (CLOS generic functions)

(defgeneric channel-start (channel)
  (:documentation "Start the channel - connect and begin listening."))

(defgeneric channel-stop (channel)
  (:documentation "Stop the channel - disconnect and clean up."))

(defgeneric channel-send (channel target message &optional media)
  (:documentation "Send a message to target through the channel."))

(defgeneric channel-name (channel)
  (:documentation "Return the channel name identifier."))

(defgeneric channel-health-check (channel)
  (:documentation "Check if the channel is operational. Returns T if healthy."))

(defgeneric channel-send-event (channel target message media stage)
  (:documentation "Send staged outbound delivery (chunk/final). Optional method."))

(defgeneric channel-start-typing (channel recipient)
  (:documentation "Show typing indicator. Optional method."))

(defgeneric channel-stop-typing (channel recipient)
  (:documentation "Hide typing indicator. Optional method."))

;;; Channel manager for multi-channel support

(defstruct (channel-manager
            (:constructor %make-channel-manager))
  "Manages multiple channel instances."
  (channels (make-hash-table :test 'equal) :type hash-table)
  (lock (sb-thread:make-mutex :name "channel-manager") :type sb-thread:mutex))

(defun make-channel-manager ()
  "Create a new channel manager."
  (%make-channel-manager))

(defun register-channel (manager name channel)
  "Register a channel with the manager."
  (declare (type channel-manager manager)
           (type string name))
  (sb-thread:with-mutex ((channel-manager-lock manager))
    (setf (gethash name (channel-manager-channels manager)) channel)))

(defun unregister-channel (manager name)
  "Remove a channel from the manager."
  (declare (type channel-manager manager)
           (type string name))
  (sb-thread:with-mutex ((channel-manager-lock manager))
    (remhash name (channel-manager-channels manager))))

(defun find-channel (manager name)
  "Find a channel by name."
  (declare (type channel-manager manager)
           (type string name))
  (sb-thread:with-mutex ((channel-manager-lock manager))
    (gethash name (channel-manager-channels manager))))

(defun start-all-channels (manager)
  "Start all registered channels."
  (declare (type channel-manager manager))
  (sb-thread:with-mutex ((channel-manager-lock manager))
    (maphash (lambda (name channel)
               (declare (ignore name))
               (channel-start channel))
             (channel-manager-channels manager))))

(defun stop-all-channels (manager)
  "Stop all registered channels."
  (declare (type channel-manager manager))
  (sb-thread:with-mutex ((channel-manager-lock manager))
    (maphash (lambda (name channel)
               (declare (ignore name))
               (channel-stop channel))
             (channel-manager-channels manager))))

(defun health-check-all (manager)
  "Check health of all channels. Returns list of (name . healthy-p) pairs."
  (declare (type channel-manager manager))
  (let ((results '()))
    (sb-thread:with-mutex ((channel-manager-lock manager))
      (maphash (lambda (name channel)
                 (push (cons name (channel-health-check channel))
                       results))
               (channel-manager-channels manager)))
    results))
