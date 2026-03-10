(in-package #:nilclaw/memory)
(declaim (optimize (safety 3) (debug 3)))

(defstruct memory-entry
  (id "" :type string)
  (key "" :type string)
  (content "" :type string)
  (category "core" :type string)
  (timestamp "" :type string)
  (session-id nil :type (or null string))
  (score nil :type (or null real)))

(defclass memory-backend () ())

(defgeneric memory-name (backend))
(defgeneric memory-health-check (backend))
(defgeneric memory-count (backend))
(defgeneric memory-get (backend key))
(defgeneric memory-recall (backend query limit &optional session-id))
(defgeneric memory-list (backend &optional category session-id))
(defgeneric memory-store (backend key content category &optional session-id))
(defgeneric memory-forget (backend key))

(defun %make-entry (key content category &optional session-id)
  (declare (type string key content category)
           (type (or null string) session-id))
  (make-memory-entry :id key :key key :content content :category category
                     :timestamp (write-to-string (get-universal-time))
                     :session-id session-id))
