(in-package #:nilclaw/agent)

(declaim (optimize (safety 3) (debug 3)))

(defstruct agent-runtime
  (cli-entrypoint "nilclaw/agent:main" :type string)
  (subagent-entrypoint "nilclaw/agent:spawn-subagent" :type string)
  (streaming-entrypoint "nilclaw/agent:stream-event" :type string)
  (enabled t :type boolean)
  (max-subagents 8 :type (integer 1 *)))

(defstruct agent-request
  (command "" :type string)
  (payload nil :type list))

(defstruct agent-response
  (ok-p nil :type boolean)
  (code :invalid :type keyword)
  (data nil :type t))

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
       (> (length (agent-runtime-subagent-entrypoint runtime)) 0)
       (> (agent-runtime-max-subagents runtime) 0)))

(declaim (ftype (function (&optional agent-runtime) boolean) streaming-runtime-available-p))
(defun streaming-runtime-available-p (&optional (runtime (make-default-agent-runtime)))
  (declare (type agent-runtime runtime))
  (and (agent-runtime-enabled runtime)
       (> (length (agent-runtime-streaming-entrypoint runtime)) 0)))

(declaim (ftype (function (agent-runtime agent-request) agent-response) agent-handle-request))
(defun agent-handle-request (runtime request)
  (declare (type agent-runtime runtime)
           (type agent-request request))
  (let ((command (agent-request-command request))
        (payload (agent-request-payload request)))
    (cond
      ((not (agent-runtime-enabled runtime))
       (make-agent-response :ok-p nil :code :disabled :data nil))
      ((zerop (length command))
       (make-agent-response :ok-p nil :code :malformed-request :data "missing command"))
      ((not (listp payload))
       (make-agent-response :ok-p nil :code :malformed-request :data "payload must be list"))
      ((string= command "chat.send")
       (if (assoc :message payload)
           (make-agent-response :ok-p t :code :ok :data '(:queued t))
         (make-agent-response :ok-p nil :code :malformed-request :data "missing :message")))
      ((string= command "subagent.spawn")
       (if (and (subagent-runtime-available-p runtime) (assoc :task payload))
           (make-agent-response :ok-p t :code :ok :data '(:spawned t))
         (make-agent-response :ok-p nil :code :capacity-or-payload-error :data nil)))
      ((string= command "stream.event")
       (if (streaming-runtime-available-p runtime)
           (make-agent-response :ok-p t :code :ok :data '(:streamed t))
         (make-agent-response :ok-p nil :code :streaming-unavailable :data nil)))
      (t
       (make-agent-response :ok-p nil :code :unknown-command :data command)))))