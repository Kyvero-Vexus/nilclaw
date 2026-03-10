(in-package #:nilclaw/bootstrap)

(declaim (optimize (safety 3) (debug 3)))

(defstruct bootstrap-runtime
  (entrypoint "nilclaw/bootstrap:bootstrap" :type string)
  (workspace "." :type string))

(declaim (ftype (function () bootstrap-runtime) make-default-bootstrap-runtime))
(defun make-default-bootstrap-runtime ()
  (make-bootstrap-runtime))

(declaim (ftype (function (&optional bootstrap-runtime) boolean) bootstrap-entrypoint-available-p))
(defun bootstrap-entrypoint-available-p (&optional (runtime (make-default-bootstrap-runtime)))
  (declare (type bootstrap-runtime runtime))
  (and (> (length (bootstrap-runtime-entrypoint runtime)) 0)
       (> (length (bootstrap-runtime-workspace runtime)) 0)))
