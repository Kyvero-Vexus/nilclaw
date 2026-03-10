(in-package #:nilclaw/cron)

(declaim (optimize (safety 3) (debug 3)))

(defstruct cron-runtime
  (name "nilclaw-cron" :type string)
  (enabled t :type boolean)
  (max-tasks 64 :type (integer 1 *))
  (max-retries 1 :type (integer 0 5)))

(defstruct cron-task
  (id "" :type string)
  (due-at 0 :type integer)
  (payload nil :type t)
  (status :pending :type keyword)
  (attempts 0 :type (integer 0 *))
  (last-error nil :type (or null keyword)))

(declaim (ftype (function () cron-runtime) make-default-cron-runtime))
(defun make-default-cron-runtime ()
  (make-cron-runtime))

(declaim (ftype (function (&optional cron-runtime) boolean) cron-runtime-ready-p))
(defun cron-runtime-ready-p (&optional (runtime (make-default-cron-runtime)))
  (declare (type cron-runtime runtime))
  (and (cron-runtime-enabled runtime)
       (> (length (cron-runtime-name runtime)) 0)
       (> (cron-runtime-max-tasks runtime) 0)))

(declaim (ftype (function (cron-runtime list integer function) list) cron-run-due-tasks))
(defun cron-run-due-tasks (runtime tasks now executor-fn)
  (declare (type cron-runtime runtime)
           (type list tasks)
           (type integer now)
           (type function executor-fn))
  (mapcar (lambda (task)
            (declare (type cron-task task))
            (if (or (not (eq (cron-task-status task) :pending))
                    (> (cron-task-due-at task) now))
                task
              (multiple-value-bind (ok error-code)
                  (funcall executor-fn task)
                (let ((attempts (+ 1 (cron-task-attempts task))))
                  (cond
                    (ok
                     (make-cron-task
                      :id (cron-task-id task)
                      :due-at (cron-task-due-at task)
                      :payload (cron-task-payload task)
                      :status :completed
                      :attempts attempts
                      :last-error nil))
                    ((and (member error-code '(:timeout :network-fault) :test #'eq)
                          (<= attempts (cron-runtime-max-retries runtime)))
                     (make-cron-task
                      :id (cron-task-id task)
                      :due-at (cron-task-due-at task)
                      :payload (cron-task-payload task)
                      :status :pending
                      :attempts attempts
                      :last-error error-code))
                    (t
                     (make-cron-task
                      :id (cron-task-id task)
                      :due-at (cron-task-due-at task)
                      :payload (cron-task-payload task)
                      :status :failed
                      :attempts attempts
                      :last-error (or error-code :task-failed))))))))
          tasks))