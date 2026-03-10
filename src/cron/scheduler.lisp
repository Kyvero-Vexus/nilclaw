(in-package #:nilclaw/cron)

(declaim (optimize (safety 3) (debug 3)))

(defstruct cron-runtime
  (name "nilclaw-cron" :type string)
  (enabled t :type boolean)
  (max-tasks 64 :type (integer 1 *)))

(declaim (ftype (function () cron-runtime) make-default-cron-runtime))
(defun make-default-cron-runtime ()
  (make-cron-runtime))

(declaim (ftype (function (&optional cron-runtime) boolean) cron-runtime-ready-p))
(defun cron-runtime-ready-p (&optional (runtime (make-default-cron-runtime)))
  (declare (type cron-runtime runtime))
  (and (cron-runtime-enabled runtime)
       (> (length (cron-runtime-name runtime)) 0)
       (> (cron-runtime-max-tasks runtime) 0)))
