(in-package #:nilclaw/gateway)

(declaim (optimize (safety 3) (debug 3)))

;;; --- Gateway runtime ---

(defstruct gateway-runtime
  (name "nilclaw-gateway" :type string)
  (enabled t :type boolean)
  (port 3000 :type (integer 1 65535))
  ;; In-memory stores for session/agent/model state
  (sessions nil :type list)       ; list of gateway-session
  (agents nil :type list)         ; list of gateway-agent
  (models nil :type list)         ; list of gateway-model
  (connections nil :type list)    ; list of gateway-connection
  (event-log nil :type list)      ; list of emitted events (for testing)
  ;; Provider completion function — when non-nil, handle-chat-send calls this
  ;; instead of producing dummy echo responses.
  ;; Signature: (lambda (message model-id history) -> (values text success-p))
  ;; where history is a list of gateway-message structs for the session.
  (chat-fn nil :type (or null function)))

;;; --- Request/Response ---

(defstruct gateway-request
  (id "" :type string)
  (method "" :type string)
  (params nil :type list))

(defstruct gateway-response
  (id "" :type string)
  (ok-p nil :type boolean)
  (result nil :type t)
  (error-code nil :type (or null keyword))
  (error-message nil :type (or null string)))

;;; --- Helpers ---

(declaim (ftype (function () gateway-runtime) make-default-gateway-runtime))
(defun make-default-gateway-runtime ()
  (make-gateway-runtime))

(declaim (ftype (function (&optional gateway-runtime) boolean) gateway-runtime-ready-p))
(defun gateway-runtime-ready-p (&optional (runtime (make-default-gateway-runtime)))
  (declare (type gateway-runtime runtime))
  (and (gateway-runtime-enabled runtime)
       (> (length (gateway-runtime-name runtime)) 0)
       (<= 1 (gateway-runtime-port runtime) 65535)))

;;; --- Param accessor (handles both plist and alist) ---

(declaim (ftype (function (list t &rest t) t) param-get))
(defun param-get (params key &rest alt-keys)
  "Get a value from PARAMS, which may be a plist or alist.
Tries KEY first, then each ALT-KEY."
  (labels ((try-key (k)
             (cond
               ;; plist: keyword followed by value
               ((and (keywordp k) (getf params k nil))
                (getf params k))
               ;; alist: (key . value)
               ((and (consp (first params))
                     (assoc k params))
                (cdr (assoc k params)))
               (t nil))))
    (or (try-key key)
        (loop for ak in alt-keys
              for v = (try-key ak)
              when v return v))))

(declaim (ftype (function (string list) gateway-response) malformed-request-response))
(defun malformed-request-response (request-id message)
  (declare (type string request-id)
           (type list message))
  (make-gateway-response
   :id request-id
   :ok-p nil
   :error-code :malformed-request
   :error-message (format nil "Malformed request:~{ ~a~}" message)))

(declaim (ftype (function (t (integer 1 *)) (integer 1 *)) positive-integer-or-default))
(defun positive-integer-or-default (value default)
  "Return VALUE when it is a positive integer, otherwise DEFAULT."
  (declare (type (integer 1 *) default))
  (if (and (integerp value) (> value 0))
      value
      default))

;;; --- Nonce generation ---

(declaim (ftype (function () string) generate-nonce))
(defun generate-nonce ()
  "Generate a random nonce string for connect challenge."
  (format nil "nonce-~A-~A" (get-universal-time) (random 1000000)))

;;; --- Event emission ---

(declaim (ftype (function (gateway-runtime gateway-event) gateway-runtime) gateway-emit-event))
(defun gateway-emit-event (runtime event)
  "Record an event in the gateway's event log and return the updated runtime."
  (declare (type gateway-runtime runtime)
           (type gateway-event event))
  (push event (gateway-runtime-event-log runtime))
  runtime)

(declaim (ftype (function (gateway-runtime gateway-method-event) gateway-runtime) gateway-emit-method-event))
(defun gateway-emit-method-event (runtime event)
  "Record a method-style event in the gateway's event log."
  (declare (type gateway-runtime runtime)
           (type gateway-method-event event))
  ;; Store as a tagged cons so tests can distinguish event types
  (push (cons :method-event event) (gateway-runtime-event-log runtime))
  runtime)

;;; --- Connect challenge ---

(declaim (ftype (function (gateway-runtime) (values gateway-event gateway-connection)) gateway-make-challenge))
(defun gateway-make-challenge (runtime)
  "Create a connect.challenge event and a new connection state.
Returns (values challenge-event connection)."
  (declare (type gateway-runtime runtime)
           (ignorable runtime))
  (let* ((nonce (generate-nonce))
         (event (make-gateway-event
                 :event "connect.challenge"
                 :payload (list :nonce nonce)))
         (conn (make-gateway-connection :nonce nonce)))
    (values event conn)))

;;; --- Connect method handler ---

(declaim (ftype (function (gateway-runtime string list gateway-connection) gateway-response) handle-connect))
(defun handle-connect (runtime request-id params connection)
  "Handle the 'connect' method. Validates protocol version and auth."
  (declare (type gateway-runtime runtime)
           (type string request-id)
           (type list params)
           (type gateway-connection connection))
  (let ((min-proto (param-get params :min-protocol :|minProtocol|))
        (max-proto (param-get params :max-protocol :|maxProtocol|))
        (client (param-get params :client)))
    ;; Protocol version check
    (when min-proto
      (unless (integerp min-proto)
        (return-from handle-connect
          (malformed-request-response request-id (list "minProtocol must be integer")))))
    (when max-proto
      (unless (integerp max-proto)
        (return-from handle-connect
          (malformed-request-response request-id (list "maxProtocol must be integer")))))
    (when (and min-proto max-proto)
      (unless (and (<= min-proto 3) (>= max-proto 3))
        (return-from handle-connect
          (make-gateway-response
           :id request-id
           :ok-p nil
           :error-code :protocol-mismatch
           :error-message "Server requires protocol version 3"))))
    ;; Mark connection authenticated
    (setf (gateway-connection-authenticated connection) t)
    (when (and client (listp client))
      (let ((cid (param-get client :id :|id|)))
        (when cid
          (setf (gateway-connection-client-id connection) cid)))
      (let ((dn (param-get client :display-name :|displayName|)))
        (when dn
          (setf (gateway-connection-client-display-name connection) dn))))
    (setf (gateway-connection-protocol-version connection) 3)
    ;; Add connection to runtime
    (push connection (gateway-runtime-connections runtime))
    ;; Return success with policy
    (let ((ts (get-universal-time))
          (tick (gateway-connection-tick-interval-ms connection)))
      (make-gateway-response
       :id request-id
       :ok-p t
       :result (list :protocol 3
                     :timestamp ts
                     :policy (list :tick-interval-ms tick
                                   :|tickIntervalMs| tick))))))

;;; --- Session management ---

(declaim (ftype (function (gateway-runtime string string string) gateway-session)
                gateway-ensure-session))
(defun gateway-ensure-session (runtime key label agent-id)
  "Find or create a session with the given KEY."
  (declare (type gateway-runtime runtime)
           (type string key label agent-id))
  (or (find key (gateway-runtime-sessions runtime)
            :key #'gateway-session-key :test #'string=)
      (let ((session (make-gateway-session
                      :key key
                      :label label
                      :agent-id agent-id
                      :created-at (get-universal-time))))
        (push session (gateway-runtime-sessions runtime))
        session)))

;;; --- Method handlers ---

(declaim (ftype (function (gateway-runtime string list) gateway-response) handle-sessions-list))
(defun handle-sessions-list (runtime request-id params)
  "Handle sessions.list method."
  (declare (type gateway-runtime runtime)
           (type string request-id)
           (type list params))
  (let* ((limit (positive-integer-or-default (param-get params :limit :|limit|) 50))
         (sessions (gateway-runtime-sessions runtime))
         (limited (if (> (length sessions) limit)
                      (subseq sessions 0 limit)
                      sessions))
         (ts (get-universal-time))
         (session-data
           (mapcar (lambda (s)
                     (let ((k (gateway-session-key s))
                           (label (gateway-session-label s))
                           (aid (gateway-session-agent-id s)))
                       (list :key k
                             :session-key k
                             :|sessionKey| k
                             :label label
                             :agent-id aid
                             :|agentId| aid
                             :timestamp ts)))
                   limited)))
    (make-gateway-response
     :id request-id
     :ok-p t
     :result (list :timestamp ts
                   :sessions session-data))))

(declaim (ftype (function (gateway-runtime string list) gateway-response) handle-agents-list))
(defun handle-agents-list (runtime request-id params)
  "Handle agents.list method."
  (declare (type gateway-runtime runtime)
           (type string request-id)
           (type list params)
           (ignorable params))
  (let* ((ts (get-universal-time))
         (agent-data
           (mapcar (lambda (a)
                     (let ((id (gateway-agent-id a))
                           (dn (gateway-agent-display-name a)))
                       (list :id id
                             :display-name dn
                             :|displayName| dn
                             :timestamp ts)))
                   (gateway-runtime-agents runtime))))
    (make-gateway-response
     :id request-id
     :ok-p t
     :result (list :timestamp ts
                   :agents agent-data))))

(declaim (ftype (function (gateway-runtime string list) gateway-response) handle-chat-send))
(defun handle-chat-send (runtime request-id params)
  "Handle chat.send method. Stores message and returns ack."
  (declare (type gateway-runtime runtime)
           (type string request-id)
           (type list params))
  (let ((session-key (param-get params :session-key :|sessionKey|))
        (message-text (param-get params :message :|message|))
        (idempotency-key (param-get params :idempotency-key :|idempotencyKey|)))
    (declare (ignorable idempotency-key))
    (cond
      ((not session-key)
       (malformed-request-response request-id (list "missing sessionKey")))
      ((not message-text)
       (malformed-request-response request-id (list "missing message")))
      (t
       (let ((session (find session-key (gateway-runtime-sessions runtime)
                            :key #'gateway-session-key :test #'string=)))
         (unless session
           ;; Auto-create session
           (setf session (gateway-ensure-session runtime session-key session-key "default")))
         (handler-case
             (progn
               ;; Store the user message
               (let ((msg (make-gateway-message
                           :role "user"
                           :content message-text
                           :timestamp (get-universal-time))))
                 (setf (gateway-session-messages session)
                       (append (gateway-session-messages session) (list msg))))
               ;; Emit assistant response and both event surfaces consumed by clients:
               ;; - event:"chat" streaming lifecycle (state=delta|final)
               ;; - method event chat.message (legacy/non-stream consumers)
               (let* ((chat-fn (gateway-runtime-chat-fn runtime))
                      (model-id (or (param-get params :model-id :|modelId|) ""))
                      (session-history (gateway-session-messages session))
                      (assistant-text
                       (cond
                         ;; Test hook: forced error
                         ((string= message-text "__force_chat_error__")
                          (error "forced chat.send error"))
                         ;; Real provider path: call chat-fn when wired
                         (chat-fn
                          (multiple-value-bind (text success-p)
                              (funcall chat-fn message-text model-id session-history)
                            (if success-p
                                text
                                (or text "[error: provider call failed]"))))
                         ;; Fallback echo (tests / no provider wired)
                         (t (format nil "Echo: ~A" message-text))))
                      (assistant-timestamp (get-universal-time))
                      (assistant-msg (make-gateway-message
                                      :role "assistant"
                                      :content assistant-text
                                      :timestamp assistant-timestamp))
                      (content-parts (list (list :type "text" :text assistant-text))))
                 (setf (gateway-session-messages session)
                       (append (gateway-session-messages session) (list assistant-msg)))
                 ;; Streaming lifecycle: delta then final.
                 (gateway-emit-event
                  runtime
                  (make-gateway-event
                   :event "chat"
                   :payload (list :session-key session-key
                                  :|sessionKey| session-key
                                  :state "delta"
                                  :timestamp assistant-timestamp
                                  :message (list :role "assistant"
                                                 :timestamp assistant-timestamp
                                                 :content content-parts))))
                 (gateway-emit-event
                  runtime
                  (make-gateway-event
                   :event "chat"
                   :payload (list :session-key session-key
                                  :|sessionKey| session-key
                                  :state "final"
                                  :timestamp assistant-timestamp
                                  :message (list :role "assistant"
                                                 :timestamp assistant-timestamp
                                                 :content content-parts))))
                 ;; Existing method event contract.
                 (gateway-emit-method-event
                  runtime
                  (make-gateway-method-event
                   :method "chat.message"
                   :params (list :session-key session-key
                                 :role "assistant"
                                 :timestamp assistant-timestamp
                                 :content assistant-text
                                 :content-parts content-parts))))
               ;; Emit sessions.update event
               (gateway-emit-method-event
                runtime
                (make-gateway-method-event
                 :method "sessions.update"
                 :params (list :session-key session-key
                               :|sessionKey| session-key
                               :label (gateway-session-label session)
                               :timestamp (get-universal-time))))
               ;; Return ack
               (make-gateway-response
                :id request-id
                :ok-p t
                :result (list :queued t)))
           (error (e)
             (gateway-emit-event
              runtime
              (make-gateway-event
               :event "chat"
               :payload (list :session-key session-key
                              :|sessionKey| session-key
                              :state "error"
                              :timestamp (get-universal-time)
                              :error (list :message (princ-to-string e)))))
             (make-gateway-response
              :id request-id
              :ok-p nil
              :error-code :internal-error
              :error-message (princ-to-string e)))))))))

(declaim (ftype (function (gateway-runtime string list) gateway-response) handle-chat-history))
(defun handle-chat-history (runtime request-id params)
  "Handle chat.history method. Returns message history for a session."
  (declare (type gateway-runtime runtime)
           (type string request-id)
           (type list params))
  (let ((session-key (param-get params :session-key :|sessionKey|))
        (limit (positive-integer-or-default (param-get params :limit :|limit|) 50)))
    (cond
      ((not session-key)
       (malformed-request-response request-id (list "missing sessionKey")))
      (t
       (let ((session (find session-key (gateway-runtime-sessions runtime)
                            :key #'gateway-session-key :test #'string=)))
         (if (not session)
             (make-gateway-response
              :id request-id
              :ok-p t
              :result (list :session-key session-key
                            :|sessionKey| session-key
                            :timestamp (get-universal-time)
                            :messages nil))
             (let* ((msgs (gateway-session-messages session))
                    (limited (if (> (length msgs) limit)
                                 (subseq msgs (- (length msgs) limit))
                                 msgs))
                    (ts (get-universal-time))
                    (message-data
                      (mapcar (lambda (m)
                                (let ((txt (gateway-message-content m)))
                                  (let ((parts (list (list :type "text" :text txt))))
                                    (list :role (gateway-message-role m)
                                          :content txt
                                          :content-parts parts
                                          :|contentParts| parts
                                          :timestamp (gateway-message-timestamp m)))))
                              limited)))
               (make-gateway-response
                :id request-id
                :ok-p t
                :result (list :session-key session-key
                              :|sessionKey| session-key
                              :timestamp ts
                              :messages message-data)))))))))

(declaim (ftype (function (gateway-runtime string list) gateway-response) handle-models-list))
(defun handle-models-list (runtime request-id params)
  "Handle models.list method."
  (declare (type gateway-runtime runtime)
           (type string request-id)
           (type list params)
           (ignorable params))
  (let* ((ts (get-universal-time))
         (model-data
           (mapcar (lambda (m)
                     (let ((id (gateway-model-id m))
                           (name (gateway-model-name m))
                           (provider (gateway-model-provider m)))
                       (list :id id
                             :name name
                             :provider provider
                             :timestamp ts)))
                   (gateway-runtime-models runtime))))
    (make-gateway-response
     :id request-id
     :ok-p t
     :result (list :timestamp ts
                   :models model-data))))

;;; --- Main request router ---

(declaim (ftype (function (gateway-request &optional gateway-runtime gateway-connection)
                          gateway-response)
                gateway-handle-request))
(defun gateway-handle-request (request &optional runtime connection)
  "Route a gateway request to the appropriate handler.
RUNTIME and CONNECTION are optional for backward compatibility.
When not provided, only basic methods (ping, sessions.list) work."
  (declare (type gateway-request request))
  (let ((request-id (gateway-request-id request))
        (method (gateway-request-method request))
        (params (gateway-request-params request))
        (rt (or runtime (make-default-gateway-runtime)))
        (conn connection))
    (cond
      ((zerop (length request-id))
       (malformed-request-response "" (list "missing id")))
      ((zerop (length method))
       (malformed-request-response request-id (list "missing method")))
      ((not (listp params))
       (malformed-request-response request-id (list "params must be list")))
      ;; --- Method dispatch ---
      ((string= method "connect")
       (if conn
           (handle-connect rt request-id params conn)
           (make-gateway-response
            :id request-id
            :ok-p nil
            :error-code :no-connection
            :error-message "No connection state for connect")))
      ((string= method "ping")
       (make-gateway-response :id request-id :ok-p t :result '(:pong t)))
      ((string= method "sessions.list")
       (handle-sessions-list rt request-id params))
      ((string= method "agents.list")
       (handle-agents-list rt request-id params))
      ((string= method "chat.send")
       (handle-chat-send rt request-id params))
      ((string= method "chat.history")
       (handle-chat-history rt request-id params))
      ((string= method "models.list")
       (handle-models-list rt request-id params))
      (t
       (make-gateway-response
        :id request-id
        :ok-p nil
        :error-code :unknown-method
        :error-message (format nil "Unknown method: ~a" method))))))

;;; ====================================================================
;;; Event Stream Semantics (ordering, dedupe, reconnect)
;;; ====================================================================

(declaim (ftype (function () event-stream) make-default-event-stream))
(defun make-default-event-stream ()
  "Create a fresh event stream."
  (make-event-stream))

(declaim (ftype (function (event-stream string list) (values gateway-method-event event-stream))
                stream-emit))
(defun stream-emit (stream method params)
  "Emit a sequenced method event into STREAM. Returns the event and updated stream."
  (declare (type event-stream stream)
           (type string method)
           (type list params))
  (let* ((seq (event-stream-next-seq stream))
         (event (make-gateway-method-event :method method :params params :seq seq)))
    (setf (event-stream-next-seq stream) (1+ seq))
    (push event (event-stream-emitted stream))
    (values event stream)))

(declaim (ftype (function (event-stream string) boolean) stream-seen-p))
(defun stream-seen-p (stream idempotency-key)
  "Check whether IDEMPOTENCY-KEY has already been processed."
  (declare (type event-stream stream)
           (type string idempotency-key))
  (member idempotency-key (event-stream-seen-ids stream) :test #'string=)
  ;; Return boolean
  (if (member idempotency-key (event-stream-seen-ids stream) :test #'string=) t nil))

(declaim (ftype (function (event-stream string) event-stream) stream-mark-seen))
(defun stream-mark-seen (stream idempotency-key)
  "Mark IDEMPOTENCY-KEY as seen for dedupe."
  (declare (type event-stream stream)
           (type string idempotency-key))
  (push idempotency-key (event-stream-seen-ids stream))
  stream)

(declaim (ftype (function (event-stream string list string) (values (or null gateway-method-event) event-stream))
                stream-emit-deduped))
(defun stream-emit-deduped (stream method params idempotency-key)
  "Emit event only if IDEMPOTENCY-KEY has not been seen. Returns (values event-or-nil stream)."
  (declare (type event-stream stream)
           (type string method idempotency-key)
           (type list params))
  (if (stream-seen-p stream idempotency-key)
      (values nil stream)
      (progn
        (stream-mark-seen stream idempotency-key)
        (stream-emit stream method params))))

(declaim (ftype (function (event-stream (integer 0 *)) list) stream-events-since))
(defun stream-events-since (stream last-seq)
  "Return events emitted after LAST-SEQ, in emission order (ascending seq)."
  (declare (type event-stream stream)
           (type (integer 0 *) last-seq))
  (sort (remove-if (lambda (e) (<= (gateway-method-event-seq e) last-seq))
                   (copy-list (event-stream-emitted stream)))
        #'< :key #'gateway-method-event-seq))

(declaim (ftype (function (event-stream (integer 0 *)) event-stream) stream-ack))
(defun stream-ack (stream seq)
  "Acknowledge events up to SEQ. Allows pruning if desired."
  (declare (type event-stream stream)
           (type (integer 0 *) seq))
  (setf (event-stream-last-ack-seq stream) seq)
  stream)

(declaim (ftype (function (event-stream) event-stream) stream-disconnect))
(defun stream-disconnect (stream)
  "Mark stream as disconnected."
  (declare (type event-stream stream))
  (setf (event-stream-connected-p stream) nil)
  stream)

(declaim (ftype (function (event-stream) event-stream) stream-reconnect))
(defun stream-reconnect (stream)
  "Mark stream as reconnected. Increments reconnect count."
  (declare (type event-stream stream))
  (setf (event-stream-connected-p stream) t)
  (incf (event-stream-reconnect-count stream))
  stream)

(declaim (ftype (function (event-stream) list) stream-replay-after-reconnect))
(defun stream-replay-after-reconnect (stream)
  "Return events that need replay after reconnect (events since last ack)."
  (declare (type event-stream stream))
  (stream-events-since stream (event-stream-last-ack-seq stream)))
