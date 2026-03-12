(in-package #:nilclaw/agent)

(declaim (optimize (safety 3) (debug 3)))

;;; ---------------------------------------------------------------------------
;;; Agent Chat Loop — wires provider-complete to channel send
;;; ---------------------------------------------------------------------------

(declaim (ftype (function (nilclaw/provider:provider-runtime)
                          function)
                make-chat-transport-fn))
(defun make-chat-transport-fn (runtime)
  "Create a transport function for provider-complete that uses the HTTP layer.
   The returned function has signature (request attempt-index) -> (values content error-code)."
  (declare (type nilclaw/provider:provider-runtime runtime))
  (let ((backoff (nilclaw/provider:make-backoff-config)))
    (lambda (request attempt-index)
      (declare (type nilclaw/provider:provider-request request)
               (type (integer 0 *) attempt-index)
               (ignore attempt-index))
      (let ((result (nilclaw/provider:http-transport-with-backoff
                     request runtime backoff)))
        (values (nilclaw/provider:http-transport-result-content result)
                (nilclaw/provider:http-transport-result-error-code result))))))

(declaim (ftype (function (string nilclaw/provider:provider-runtime
                           &key (:system-prompt (or null string))
                                (:history list))
                          (values (or null string) boolean &optional))
                agent-chat))
(defun agent-chat (user-message provider-runtime
                   &key (system-prompt nil) (history nil))
  "Process a chat message through the provider and return the response text.
   USER-MESSAGE is the user's input string.
   PROVIDER-RUNTIME is the configured provider runtime.
   SYSTEM-PROMPT is an optional system message prepended to the conversation.
   HISTORY is an optional list of prior message alists.
   Returns (values response-text success-p)."
  (declare (type string user-message)
           (type nilclaw/provider:provider-runtime provider-runtime)
           (type (or null string) system-prompt)
           (type list history))
  ;; Build message list
  (let* ((messages (append
                    (when system-prompt
                      (list `((:role . "system") (:content . ,system-prompt))))
                    history
                    (list `((:role . "user") (:content . ,user-message)))))
         (request (nilclaw/provider:make-provider-request
                   :model (nilclaw/provider:provider-runtime-model provider-runtime)
                   :messages messages))
         (transport-fn (make-chat-transport-fn provider-runtime))
         (result (nilclaw/provider:provider-complete
                  provider-runtime request transport-fn)))
    (if (nilclaw/provider:provider-result-success-p result)
        (values (or (nilclaw/provider:provider-result-content result) "") t)
        (values (format nil "[error: ~A after ~D attempt~:P]"
                        (or (nilclaw/provider:provider-result-error-code result) :unknown)
                        (nilclaw/provider:provider-result-attempts result))
                nil))))

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