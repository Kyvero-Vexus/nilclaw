(in-package #:nilclaw/agent)

(declaim (optimize (safety 3) (debug 3)))

(defstruct agent-runtime
  (cli-entrypoint "nilclaw/agent:main" :type string)
  (subagent-entrypoint "nilclaw/agent:spawn-subagent" :type string)
  (streaming-entrypoint "nilclaw/agent:stream-event" :type string)
  (enabled t :type boolean))

(declaim (ftype (function () agent-runtime) make-default-agent-runtime))
(defun make-default-agent-runtime ()
  (make-agent-runtime))

(declaim (ftype (function (&optional agent-runtime) boolean) cli-entrypoint-available-p))
(defun cli-entrypoint-available-p (&optional (runtime (make-default-agent-runtime)))
  (declare (type agent-runtime runtime))
  (and (agent-runtime-enabled runtime)
       (> (length (agent-runtime-cli-entrypoint runtime)) 0)))

(declaim (ftype (function (&optional agent-runtime) boolean) subagent-runtime-available-p))
(defun subagent-runtime-available-p (&optional (runtime (make-default-agent-runtime)))
  (declare (type agent-runtime runtime))
  (and (agent-runtime-enabled runtime)
       (> (length (agent-runtime-subagent-entrypoint runtime)) 0)))

(declaim (ftype (function (&optional agent-runtime) boolean) streaming-runtime-available-p))
(defun streaming-runtime-available-p (&optional (runtime (make-default-agent-runtime)))
  (declare (type agent-runtime runtime))
  (and (agent-runtime-enabled runtime)
       (> (length (agent-runtime-streaming-entrypoint runtime)) 0)))
