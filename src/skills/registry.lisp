(in-package #:nilclaw/skills)

(declaim (optimize (safety 3) (debug 3)))

(defstruct skills-runtime
  (entrypoint "nilclaw/skills:load-skills" :type string)
  (enabled t :type boolean))

(declaim (ftype (function () skills-runtime) make-default-skills-runtime))
(defun make-default-skills-runtime ()
  (make-skills-runtime))

(declaim (ftype (function (&optional skills-runtime) boolean) skills-loader-entrypoint-available-p))
(defun skills-loader-entrypoint-available-p (&optional (runtime (make-default-skills-runtime)))
  (declare (type skills-runtime runtime))
  (and (skills-runtime-enabled runtime)
       (> (length (skills-runtime-entrypoint runtime)) 0)))
