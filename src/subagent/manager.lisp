(in-package #:nilclaw/subagent)

(declaim (optimize (safety 3) (debug 3)))

;;; Task states
(defparameter *task-status-values* '(:running :completed :failed)
  "Valid task status values.")

(deftype task-status () '(member :running :completed :failed))

(defstruct task-state
  "State tracking for a subagent task."
  (id 0 :type (integer 0 *))
  (status :running :type task-status)
  (label "" :type string)
  (session-key nil :type (or null string))
  (result nil :type (or null string))
  (error-msg nil :type (or null string))
  (started-at 0 :type (integer 0 *))
  (completed-at nil :type (or null (integer 0 *))))

;;; Subagent configuration
(defstruct subagent-config
  "Configuration for subagent manager."
  (max-iterations 15 :type (integer 1 100))
  (max-concurrent 4 :type (integer 1 16))
  (task-runner nil :type (or null function)))

;;; Subagent manager
(defstruct subagent-manager
  "Manages subagent task execution with concurrency limits."
  (tasks (make-hash-table :test 'eql) :type hash-table)
  (next-id 1 :type (integer 1 *))
  (config (make-subagent-config) :type subagent-config)
  (mutex (sb-thread:make-mutex) :type sb-thread:mutex))

(declaim (ftype (function () subagent-manager) make-default-subagent-manager))
(defun make-default-subagent-manager ()
  "Create a subagent manager with default configuration."
  (make-subagent-manager))

(declaim (ftype (function (subagent-manager) (integer 0 *)) running-count))
(defun running-count (manager)
  "Count currently running tasks."
  (declare (type subagent-manager manager))
  (let ((count 0))
    (sb-thread:with-mutex ((subagent-manager-mutex manager))
      (maphash (lambda (k v)
                 (declare (ignore k))
                 (when (eq :running (task-state-status v))
                   (incf count)))
               (subagent-manager-tasks manager)))
    count))

(declaim (ftype (function (subagent-manager) boolean) concurrency-available-p))
(defun concurrency-available-p (manager)
  "Check if a new task can be spawned."
  (declare (type subagent-manager manager))
  (< (running-count manager)
     (subagent-config-max-concurrent (subagent-manager-config manager))))

(declaim (ftype (function (subagent-manager string &key (:label string) (:session-key (or null string))) 
                  (values (integer 1 *) task-state))
                spawn-task))
(defun spawn-task (manager task-text &key (label "") (session-key nil))
  "Spawn a new subagent task. Returns (values task-id task-state)."
  (declare (type subagent-manager manager)
           (type string task-text)
           (type string label)
           (type (or null string) session-key))
  (let ((task-id 0)
        (state nil))
    (sb-thread:with-mutex ((subagent-manager-mutex manager))
      ;; Check concurrency (without re-acquiring lock)
      (let ((running 0))
        (maphash (lambda (k v)
                   (declare (ignore k))
                   (when (eq :running (task-state-status v))
                     (incf running)))
                 (subagent-manager-tasks manager))
        (when (>= running (subagent-config-max-concurrent (subagent-manager-config manager)))
          (error 'concurrency-limit-exceeded 
                 :max (subagent-config-max-concurrent (subagent-manager-config manager)))))
      ;; Allocate ID
      (setf task-id (subagent-manager-next-id manager))
      (incf (subagent-manager-next-id manager))
      ;; Create state
      (setf state (make-task-state
                   :id task-id
                   :status :running
                   :label label
                   :session-key session-key
                   :started-at (get-universal-time)))
      ;; Store in map
      (setf (gethash task-id (subagent-manager-tasks manager)) state))
    ;; TODO: Spawn actual thread with task runner
    ;; For L2, we provide the state management; thread spawning is integration work
    (values task-id state)))

(declaim (ftype (function (subagent-manager (integer 1 *)) (or null task-state)) get-task))
(defun get-task (manager task-id)
  "Get task state by ID. Returns nil if not found."
  (declare (type subagent-manager manager)
           (type (integer 1 *) task-id))
  (sb-thread:with-mutex ((subagent-manager-mutex manager))
    (gethash task-id (subagent-manager-tasks manager))))

(declaim (ftype (function (subagent-manager (integer 1 *) string) task-state) complete-task))
(defun complete-task (manager task-id result)
  "Mark a task as completed with result."
  (declare (type subagent-manager manager)
           (type (integer 1 *) task-id)
           (type string result))
  (sb-thread:with-mutex ((subagent-manager-mutex manager))
    (let ((state (gethash task-id (subagent-manager-tasks manager))))
      (unless state
        (error 'unknown-task :id task-id))
      (setf (task-state-status state) :completed)
      (setf (task-state-result state) result)
      (setf (task-state-completed-at state) (get-universal-time))
      state)))

(declaim (ftype (function (subagent-manager (integer 1 *) string) task-state) fail-task))
(defun fail-task (manager task-id error-msg)
  "Mark a task as failed with error message."
  (declare (type subagent-manager manager)
           (type (integer 1 *) task-id)
           (type string error-msg))
  (sb-thread:with-mutex ((subagent-manager-mutex manager))
    (let ((state (gethash task-id (subagent-manager-tasks manager))))
      (unless state
        (error 'unknown-task :id task-id))
      (setf (task-state-status state) :failed)
      (setf (task-state-error-msg state) error-msg)
      (setf (task-state-completed-at state) (get-universal-time))
      state)))

(declaim (ftype (function (subagent-manager) list) list-tasks))
(defun list-tasks (manager)
  "List all task states."
  (declare (type subagent-manager manager))
  (let ((result '()))
    (sb-thread:with-mutex ((subagent-manager-mutex manager))
      (maphash (lambda (k v)
                 (declare (ignore k))
                 (push v result))
               (subagent-manager-tasks manager)))
    (nreverse result)))

;;; Error conditions
(define-condition concurrency-limit-exceeded (error)
  ((max :initarg :max :reader concurrency-limit-max))
  (:report (lambda (c s)
             (format s "Concurrency limit exceeded (max ~A)" (concurrency-limit-max c)))))

(define-condition unknown-task (error)
  ((id :initarg :id :reader unknown-task-id))
  (:report (lambda (c s)
             (format s "Unknown task: ~A" (unknown-task-id c)))))
