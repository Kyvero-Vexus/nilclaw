;;;; client.lisp — Native TUI client for NilClaw gateway
;;;; Provides both a network-free local client (for testing/embedded use)
;;;; and a remote WebSocket client for connecting to a running gateway.
;;;;
;;;; NilClaw - Statically typed Common Lisp agent harness

(in-package #:nilclaw/tui)

(declaim (optimize (safety 3) (debug 3)))

;;; ====================================================================
;;; Remote TUI client (connects to gateway via URL)
;;; ====================================================================

(defstruct tui-client
  "A TUI client that connects to a NilClaw gateway."
  (gateway-url "ws://127.0.0.1:18789" :type string)
  (session-key "tui-session" :type string)
  (connected-p nil :type boolean)
  (protocol-version 0 :type integer)
  (history nil :type list)          ; list of (role . content) pairs
  (display-name "NilClaw TUI" :type string))

(declaim (ftype (function (tui-client) boolean) tui-client-ready-p))
(defun tui-client-ready-p (client)
  "Return T if the TUI client is connected and has negotiated protocol."
  (declare (type tui-client client))
  (and (tui-client-connected-p client)
       (> (tui-client-protocol-version client) 0)))

(declaim (ftype (function () boolean) tui-entrypoint-available-p))
(defun tui-entrypoint-available-p ()
  "Return T indicating the TUI entrypoint is available."
  t)

;;; ====================================================================
;;; Valid values for TUI state toggles
;;; ====================================================================

(deftype think-level ()
  '(member :off :minimal :low :medium :high))

(deftype verbose-mode ()
  '(member :off :on :full))

(deftype reasoning-mode ()
  '(member :off :on :stream))

(deftype activation-mode ()
  '(member :off :on))

;;; ====================================================================
;;; Streaming display state (Phase 2)
;;; ====================================================================

(defstruct tui-streaming-state
  "Tracks incremental streaming display state for assistant responses."
  (buffer "" :type string)
  (chunks-received 0 :type (integer 0 *))
  (started-at 0 :type integer)
  (finished-p nil :type boolean))

(declaim (ftype (function (tui-streaming-state string) tui-streaming-state)
                tui-streaming-append))
(defun tui-streaming-append (state chunk)
  "Append a streaming chunk to the buffer. Returns the updated state."
  (declare (type tui-streaming-state state)
           (type string chunk))
  (setf (tui-streaming-state-buffer state)
        (concatenate 'string (tui-streaming-state-buffer state) chunk))
  (incf (tui-streaming-state-chunks-received state))
  state)

(declaim (ftype (function (tui-streaming-state) tui-streaming-state)
                tui-streaming-finish))
(defun tui-streaming-finish (state)
  "Mark the streaming state as finished. Returns the updated state."
  (declare (type tui-streaming-state state))
  (setf (tui-streaming-state-finished-p state) t)
  state)

(declaim (ftype (function (tui-streaming-state) (integer 0 *))
                tui-streaming-elapsed-ms))
(defun tui-streaming-elapsed-ms (state)
  "Return elapsed milliseconds since streaming started (approximate)."
  (declare (type tui-streaming-state state))
  (let ((started (tui-streaming-state-started-at state)))
    (if (zerop started)
        0
        (* 1000 (- (get-universal-time) started)))))

;;; ====================================================================
;;; Token usage tracking (Phase 2)
;;; ====================================================================

(defstruct token-usage
  "Tracks token usage for the current session."
  (prompt-tokens 0 :type (integer 0 *))
  (completion-tokens 0 :type (integer 0 *))
  (total-tokens 0 :type (integer 0 *))
  (request-count 0 :type (integer 0 *)))

;;; ====================================================================
;;; Local TUI client (in-process, no network — for testing & embedding)
;;; ====================================================================

(defstruct (local-tui-client
            (:constructor %make-local-tui-client))
  "A TUI client that operates directly against a gateway-runtime in-process.
No network required — ideal for tests and embedded use."
  (runtime nil :type (or null nilclaw/gateway:gateway-runtime))
  (session-key "tui-local" :type string)
  (connected-p nil :type boolean)
  (connection nil :type (or null nilclaw/gateway:gateway-connection))
  ;; Phase 1 parity: TUI state
  (agent-id "default" :type string)
  (model-id "" :type string)
  (deliver-p nil :type boolean)
  (think-level :off :type keyword)
  (verbose-mode :off :type keyword)
  (reasoning-mode :off :type keyword)
  ;; Phase 2 parity: extended state
  (elevated-p nil :type boolean)
  (activation-mode :off :type keyword)
  (shell-allowed-p nil :type boolean)       ; session-scoped ! shell gate
  (token-usage nil :type (or null token-usage))
  (streaming nil :type (or null tui-streaming-state)))

(declaim (ftype (function (nilclaw/gateway:gateway-runtime &key (:session-key string))
                          local-tui-client)
                make-local-tui-client))
(defun make-local-tui-client (runtime &key (session-key "tui-local"))
  "Create a local TUI client backed by RUNTIME."
  (declare (type nilclaw/gateway:gateway-runtime runtime)
           (type string session-key))
  (%make-local-tui-client :runtime runtime
                          :session-key session-key
                          :token-usage (make-token-usage)))

;;; --- Local connect ---

(declaim (ftype (function (local-tui-client) boolean) local-tui-connect))
(defun local-tui-connect (client)
  "Connect the local TUI client through the gateway protocol.
Performs challenge → connect handshake in-process."
  (declare (type local-tui-client client))
  (let ((runtime (local-tui-client-runtime client)))
    (unless runtime
      (return-from local-tui-connect nil))
    ;; Generate challenge
    (multiple-value-bind (challenge-event conn)
        (nilclaw/gateway:gateway-make-challenge runtime)
      (declare (ignore challenge-event))
      ;; Send connect request
      (let ((response (nilclaw/gateway:gateway-handle-request
                       (nilclaw/gateway:make-gateway-request
                        :id "tui-connect-1"
                        :method "connect"
                        :params (list :min-protocol 3
                                      :max-protocol 3
                                      :client (list :id "nilclaw-tui"
                                                    :display-name "NilClaw TUI")))
                       runtime
                       conn)))
        (when (nilclaw/gateway:gateway-response-ok-p response)
          (setf (local-tui-client-connected-p client) t)
          (setf (local-tui-client-connection client) conn)
          ;; Ensure session exists
          (nilclaw/gateway:gateway-ensure-session
           runtime
           (local-tui-client-session-key client)
           "TUI Session"
           (local-tui-client-agent-id client))
          t)))))

;;; --- Local send ---

(declaim (ftype (function (local-tui-client string) (values (or null string) boolean))
                local-tui-send))
(defun local-tui-send (client message)
  "Send a message through the local TUI client. Returns (values response-text success-p)."
  (declare (type local-tui-client client)
           (type string message))
  (unless (local-tui-client-connected-p client)
    (return-from local-tui-send (values nil nil)))
  (let* ((runtime (local-tui-client-runtime client))
         (session-key (local-tui-client-session-key client))
         (usage (local-tui-client-token-usage client))
         (response (nilclaw/gateway:gateway-handle-request
                    (nilclaw/gateway:make-gateway-request
                     :id (format nil "tui-msg-~A" (get-universal-time))
                     :method "chat.send"
                     :params (list :session-key session-key
                                   :message message))
                    runtime)))
    ;; Update token usage estimates (gateway doesn't provide real counts yet,
    ;; so we estimate based on message length)
    (when usage
      (let ((prompt-est (ceiling (length message) 4))
            (completion-est 0))
        (incf (token-usage-prompt-tokens usage) prompt-est)
        (incf (token-usage-request-count usage))))
    (if (nilclaw/gateway:gateway-response-ok-p response)
        ;; Extract the assistant response from the event log
        (let* ((events (nilclaw/gateway:gateway-runtime-event-log runtime))
               (chat-events (remove-if-not
                             (lambda (e)
                               (and (typep e 'nilclaw/gateway:gateway-event)
                                    (string= "chat" (nilclaw/gateway:gateway-event-event e))))
                             events))
               (final-event (find-if
                             (lambda (e)
                               (string= "final"
                                        (getf (nilclaw/gateway:gateway-event-payload e) :state)))
                             chat-events)))
          (if final-event
              (let* ((payload (nilclaw/gateway:gateway-event-payload final-event))
                     (msg (getf payload :message))
                     (content-parts (getf msg :content))
                     (text (when (and content-parts (listp content-parts))
                             (getf (first content-parts) :text))))
                ;; Update completion token estimate
                (when (and usage text)
                  (let ((comp-est (ceiling (length text) 4)))
                    (incf (token-usage-completion-tokens usage) comp-est)
                    (setf (token-usage-total-tokens usage)
                          (+ (token-usage-prompt-tokens usage)
                             (token-usage-completion-tokens usage)))))
                (values (or text "") t))
              (values nil t)))
        (values nil nil))))

;;; --- Local history ---

(declaim (ftype (function (local-tui-client &key (:limit (integer 1 *))) list)
                local-tui-history))
(defun local-tui-history (client &key (limit 50))
  "Retrieve chat history through the local TUI client."
  (declare (type local-tui-client client)
           (type (integer 1 *) limit))
  (unless (local-tui-client-connected-p client)
    (return-from local-tui-history nil))
  (let* ((runtime (local-tui-client-runtime client))
         (session-key (local-tui-client-session-key client))
         (response (nilclaw/gateway:gateway-handle-request
                    (nilclaw/gateway:make-gateway-request
                     :id "tui-history-1"
                     :method "chat.history"
                     :params (list :session-key session-key
                                   :limit limit))
                    runtime)))
    (when (nilclaw/gateway:gateway-response-ok-p response)
      (getf (nilclaw/gateway:gateway-response-result response) :messages))))

;;; ====================================================================
;;; Shell command execution (Phase 2) — session-scoped allow/deny gate
;;; ====================================================================

(declaim (ftype (function (local-tui-client string &key (:input-fn (or null function))
                                                         (:output-fn (or null function)))
                          (values string boolean))
                tui-handle-shell-command))
(defun tui-handle-shell-command (client command &key input-fn output-fn)
  "Handle a ! shell command. Checks session-scoped permission gate.
INPUT-FN: (lambda (prompt) → string) for interactive input (defaults to read-line).
OUTPUT-FN: (lambda (text) → nil) for output display (defaults to format *standard-output*).
Returns (values output-text success-p)."
  (declare (type local-tui-client client)
           (type string command))
  (let ((ask-input (or input-fn
                       (lambda (prompt)
                         (format *query-io* "~A" prompt)
                         (finish-output *query-io*)
                         (read-line *query-io* nil ""))))
        (show-output (or output-fn
                         (lambda (text)
                           (format *standard-output* "~A" text)
                           (finish-output *standard-output*)))))
    (declare (ignorable show-output))
    ;; Check if shell is allowed for this session
    (unless (local-tui-client-shell-allowed-p client)
      ;; Prompt user for permission
      (let ((answer (funcall ask-input
                             "[shell] Shell execution is disabled. Allow for this session? (y/n): ")))
        (cond
          ((member (string-trim '(#\Space #\Tab) answer)
                   '("y" "yes" "Y" "YES") :test #'string=)
           (setf (local-tui-client-shell-allowed-p client) t))
          (t
           (return-from tui-handle-shell-command
             (values "[shell] Denied. Use /settings to enable shell access." nil))))))
    ;; Execute command
    (handler-case
        (let ((trimmed (string-trim '(#\Space #\Tab) command)))
          (when (zerop (length trimmed))
            (return-from tui-handle-shell-command
              (values "[shell] Empty command." nil)))
          (multiple-value-bind (output error-output exit-code)
              (uiop:run-program trimmed
                                :output :string
                                :error-output :string
                                :ignore-error-status t)
            (let ((combined (with-output-to-string (s)
                              (when (and output (> (length output) 0))
                                (write-string output s))
                              (when (and error-output (> (length error-output) 0))
                                (when (and output (> (length output) 0))
                                  (terpri s))
                                (write-string error-output s))
                              (format s "~&[exit ~D]" exit-code))))
              (values combined (zerop exit-code)))))
      (error (e)
        (values (format nil "[shell] Error: ~A" e) nil)))))

;;; ====================================================================
;;; Display helpers (Phase 1 + Phase 2 parity)
;;; ====================================================================

(declaim (ftype (function (integer) string) format-timestamp))
(defun format-timestamp (universal-time)
  "Format a universal-time as [HH:MM]."
  (declare (type integer universal-time))
  (if (zerop universal-time)
      "[--:--]"
      (multiple-value-bind (sec min hour)
          (decode-universal-time universal-time)
        (declare (ignore sec))
        (format nil "[~2,'0D:~2,'0D]" hour min))))

(declaim (ftype (function (list) string) tui-format-history-entry))
(defun tui-format-history-entry (message)
  "Format a history message as '[HH:MM] role> content'.
MESSAGE is a plist with :role, :content, :timestamp."
  (declare (type list message))
  (let ((role (or (getf message :role) "unknown"))
        (content (or (getf message :content) ""))
        (ts (or (getf message :timestamp) 0)))
    (format nil "~A ~A> ~A" (format-timestamp ts) role content)))

(declaim (ftype (function (local-tui-client) string) tui-format-status))
(defun tui-format-status (client)
  "Format the /status output for the TUI client."
  (declare (type local-tui-client client))
  (format nil "~&[status]~%  connected:  yes~\
               ~%  session:    ~A~\
               ~%  agent:      ~A~\
               ~%  model:      ~A~\
               ~%  deliver:    ~A~\
               ~%  think:      ~A~\
               ~%  verbose:    ~A~\
               ~%  reasoning:  ~A~\
               ~%  elevated:   ~A~\
               ~%  activation: ~A~\
               ~%  shell:      ~A"
          (local-tui-client-session-key client)
          (local-tui-client-agent-id client)
          (let ((m (local-tui-client-model-id client)))
            (if (string= m "") "(default)" m))
          (if (local-tui-client-deliver-p client) "on" "off")
          (string-downcase (symbol-name (local-tui-client-think-level client)))
          (string-downcase (symbol-name (local-tui-client-verbose-mode client)))
          (string-downcase (symbol-name (local-tui-client-reasoning-mode client)))
          (if (local-tui-client-elevated-p client) "on" "off")
          (string-downcase (symbol-name (local-tui-client-activation-mode client)))
          (if (local-tui-client-shell-allowed-p client) "allowed" "denied")))

(declaim (ftype (function (local-tui-client) string) tui-format-footer))
(defun tui-format-footer (client)
  "Format the status footer line: connection+agent+session+model+toggles."
  (declare (type local-tui-client client))
  (let ((conn (if (local-tui-client-connected-p client) "connected" "disconnected"))
        (agent (local-tui-client-agent-id client))
        (session (local-tui-client-session-key client))
        (model (let ((m (local-tui-client-model-id client)))
                 (if (string= m "") "-" m)))
        (deliver (if (local-tui-client-deliver-p client) "on" "off"))
        (think (string-downcase (symbol-name (local-tui-client-think-level client))))
        (verbose (string-downcase (symbol-name (local-tui-client-verbose-mode client))))
        (reasoning (string-downcase (symbol-name (local-tui-client-reasoning-mode client))))
        (usage (local-tui-client-token-usage client)))
    (format nil "[~A] agent:~A session:~A model:~A deliver:~A think:~A verbose:~A reasoning:~A~A"
            conn agent session model deliver think verbose reasoning
            (if (and usage (> (token-usage-total-tokens usage) 0))
                (format nil " tokens:~D" (token-usage-total-tokens usage))
                ""))))

(declaim (ftype (function () string) tui-format-help))
(defun tui-format-help ()
  "Format the /help output listing available slash commands."
  (format nil "~&NilClaw TUI Commands:~%~
  /help                    Show this help~%~
  /status                  Show connection & session status~%~
  /sessions                List sessions~%~
  /session [key]           Switch/pick session~%~
  /agents                  List agents~%~
  /agent <id>              Switch agent~%~
  /models                  List models~%~
  /model [provider/model]  Set/pick model~%~
  /new, /reset             Reset current session~%~
  /deliver <on|off>        Toggle delivery~%~
  /think <off|minimal|low|medium|high>  Set thinking level~%~
  /verbose <on|full|off>   Set verbose mode~%~
  /reasoning <on|off|stream>  Set reasoning mode~%~
  /context                 Show context info~%~
  /usage                   Show token usage~%~
  /elevated <on|off>       Toggle elevated mode~%~
  /activation <on|off>     Toggle activation mode~%~
  /settings                Show all settings~%~
  /abort                   Abort active run~%~
  /exit                    Exit TUI~%~
  !<command>               Execute shell command"))

;;; ====================================================================
;;; Phase 2 display helpers
;;; ====================================================================

(declaim (ftype (function (local-tui-client) string) tui-format-context))
(defun tui-format-context (client)
  "Format /context output showing session context info."
  (declare (type local-tui-client client))
  (let* ((runtime (local-tui-client-runtime client))
         (session-key (local-tui-client-session-key client))
         (sessions (nilclaw/gateway:gateway-runtime-sessions runtime))
         (session (find session-key sessions
                        :key #'nilclaw/gateway:gateway-session-key :test #'string=))
         (msg-count (if session
                        (length (nilclaw/gateway:gateway-session-messages session))
                        0)))
    (format nil "~&[context]~\
                 ~%  session:  ~A~\
                 ~%  agent:    ~A~\
                 ~%  model:    ~A~\
                 ~%  messages: ~D~\
                 ~%  elevated: ~A~\
                 ~%  shell:    ~A"
            session-key
            (local-tui-client-agent-id client)
            (let ((m (local-tui-client-model-id client)))
              (if (string= m "") "(default)" m))
            msg-count
            (if (local-tui-client-elevated-p client) "on" "off")
            (if (local-tui-client-shell-allowed-p client) "allowed" "denied"))))

(declaim (ftype (function (local-tui-client) string) tui-format-usage))
(defun tui-format-usage (client)
  "Format /usage output showing token usage statistics."
  (declare (type local-tui-client client))
  (let ((usage (local-tui-client-token-usage client)))
    (if (and usage (> (token-usage-request-count usage) 0))
        (format nil "~&[usage]~\
                     ~%  prompt tokens:     ~D~\
                     ~%  completion tokens: ~D~\
                     ~%  total tokens:      ~D~\
                     ~%  requests:          ~D"
                (token-usage-prompt-tokens usage)
                (token-usage-completion-tokens usage)
                (token-usage-total-tokens usage)
                (token-usage-request-count usage))
        "[usage] No usage data yet.")))

(declaim (ftype (function (local-tui-client) string) tui-format-settings))
(defun tui-format-settings (client)
  "Format /settings output showing all current settings."
  (declare (type local-tui-client client))
  (format nil "~&[settings]~\
               ~%  Session:    ~A~\
               ~%  Agent:      ~A~\
               ~%  Model:      ~A~\
               ~%  Deliver:    ~A~\
               ~%  Think:      ~A~\
               ~%  Verbose:    ~A~\
               ~%  Reasoning:  ~A~\
               ~%  Elevated:   ~A~\
               ~%  Activation: ~A~\
               ~%  Shell:      ~A"
          (local-tui-client-session-key client)
          (local-tui-client-agent-id client)
          (let ((m (local-tui-client-model-id client)))
            (if (string= m "") "(default)" m))
          (if (local-tui-client-deliver-p client) "on" "off")
          (string-downcase (symbol-name (local-tui-client-think-level client)))
          (string-downcase (symbol-name (local-tui-client-verbose-mode client)))
          (string-downcase (symbol-name (local-tui-client-reasoning-mode client)))
          (if (local-tui-client-elevated-p client) "on" "off")
          (string-downcase (symbol-name (local-tui-client-activation-mode client)))
          (if (local-tui-client-shell-allowed-p client) "allowed" "denied")))

;;; ====================================================================
;;; Picker helper — textual numbered-list selector (Phase 2)
;;; ====================================================================

(declaim (ftype (function (list string &key (:input-fn (or null function))
                                            (:display-fn (or null function)))
                          (values (or null string) boolean))
                tui-pick-from-list))
(defun tui-pick-from-list (items prompt &key input-fn display-fn)
  "Present a numbered list of ITEMS and let the user pick one.
INPUT-FN: (lambda (prompt) → string) — defaults to read-line from *query-io*.
DISPLAY-FN: (lambda (index item) → string) — format each item for display.
Returns (values chosen-item success-p)."
  (declare (type list items)
           (type string prompt))
  (when (null items)
    (return-from tui-pick-from-list (values nil nil)))
  (let ((ask-input (or input-fn
                       (lambda (p)
                         (format *query-io* "~A" p)
                         (finish-output *query-io*)
                         (read-line *query-io* nil ""))))
        (fmt-item (or display-fn
                      (lambda (idx item)
                        (format nil "  ~D) ~A" idx item)))))
    ;; Build display
    (let ((display (with-output-to-string (s)
                     (format s "~A~%" prompt)
                     (loop for item in items
                           for i from 1
                           do (format s "~A~%" (funcall fmt-item i item))))))
      ;; Show options and ask
      (funcall ask-input display)  ; display first (ask-input prints prompt)
      (let* ((answer (funcall ask-input
                              (format nil "  Pick [1-~D] or name: " (length items))))
             (trimmed (string-trim '(#\Space #\Tab) answer)))
        ;; Try numeric selection
        (let ((num (ignore-errors (parse-integer trimmed))))
          (cond
            ((and num (>= num 1) (<= num (length items)))
             (values (nth (1- num) items) t))
            ;; Try name match
            ((> (length trimmed) 0)
             (let ((match (find trimmed items :test #'string-equal)))
               (if match
                   (values match t)
                   (values nil nil))))
            (t (values nil nil))))))))

;;; ====================================================================
;;; Slash command parsing
;;; ====================================================================

(declaim (ftype (function (string) (values string string)) parse-slash-command))
(defun parse-slash-command (input)
  "Parse a slash command into (values command-name argument).
E.g. '/agent foo' → (values \"agent\" \"foo\"), '/help' → (values \"help\" \"\")."
  (declare (type string input))
  (let* ((trimmed (string-trim '(#\Space #\Tab) (subseq input 1)))  ; strip leading /
         (space-pos (position #\Space trimmed)))
    (if space-pos
        (values (subseq trimmed 0 space-pos)
                (string-trim '(#\Space #\Tab) (subseq trimmed (1+ space-pos))))
        (values trimmed ""))))

;;; ====================================================================
;;; Slash command dispatch (Phase 1 + Phase 2 parity)
;;; ====================================================================

(declaim (ftype (function (local-tui-client string &key (:input-fn (or null function)))
                          (values string keyword))
                tui-handle-slash-command))
(defun tui-handle-slash-command (client input &key input-fn)
  "Handle a slash command for the local TUI client.
Returns (values output-text action) where action is :continue, :exit, or :reset.
INPUT-FN: optional (lambda (prompt) → string) for interactive picker input."
  (declare (type local-tui-client client)
           (type string input))
  (multiple-value-bind (cmd arg) (parse-slash-command input)
    (let ((cmd-down (string-downcase cmd)))
      (cond
        ;; /help
        ((string= cmd-down "help")
         (values (tui-format-help) :continue))

        ;; /status
        ((string= cmd-down "status")
         (values (tui-format-status client) :continue))

        ;; /sessions
        ((string= cmd-down "sessions")
         (let* ((runtime (local-tui-client-runtime client))
                (response (nilclaw/gateway:gateway-handle-request
                           (nilclaw/gateway:make-gateway-request
                            :id "tui-sessions"
                            :method "sessions.list"
                            :params (list :limit 50))
                           runtime)))
           (if (nilclaw/gateway:gateway-response-ok-p response)
               (let ((sessions (getf (nilclaw/gateway:gateway-response-result response) :sessions)))
                 (if sessions
                     (values (with-output-to-string (s)
                               (format s "[sessions]~%")
                               (dolist (sess sessions)
                                 (format s "  ~A  (agent: ~A)~%"
                                         (getf sess :key)
                                         (or (getf sess :agent-id) "-"))))
                             :continue)
                     (values "[sessions] (none)" :continue)))
               (values "[error] Failed to list sessions" :continue))))

        ;; /session [key] — picker when no arg
        ((string= cmd-down "session")
         (if (string= arg "")
             ;; Picker mode: list sessions and let user pick
             (let* ((runtime (local-tui-client-runtime client))
                    (response (nilclaw/gateway:gateway-handle-request
                               (nilclaw/gateway:make-gateway-request
                                :id "tui-session-pick"
                                :method "sessions.list"
                                :params (list :limit 50))
                               runtime)))
               (if (nilclaw/gateway:gateway-response-ok-p response)
                   (let* ((sessions (getf (nilclaw/gateway:gateway-response-result response) :sessions))
                          (keys (mapcar (lambda (s) (getf s :key)) sessions)))
                     (if (null keys)
                         (values "[session] No sessions available." :continue)
                         (multiple-value-bind (chosen success-p)
                             (tui-pick-from-list
                              keys "[session] Pick a session:"
                              :input-fn input-fn
                              :display-fn (lambda (idx item)
                                            (let ((sess (nth (1- idx) sessions)))
                                              (format nil "  ~D) ~A  (agent: ~A)"
                                                      idx item
                                                      (or (getf sess :agent-id) "-")))))
                           (if success-p
                               (progn
                                 (nilclaw/gateway:gateway-ensure-session
                                  runtime chosen chosen (local-tui-client-agent-id client))
                                 (setf (local-tui-client-session-key client) chosen)
                                 (values (format nil "[session] Switched to: ~A" chosen) :continue))
                               (values "[session] Cancelled." :continue)))))
                   (values "[error] Failed to list sessions" :continue)))
             ;; Direct key mode
             (let ((runtime (local-tui-client-runtime client)))
               (nilclaw/gateway:gateway-ensure-session
                runtime arg arg (local-tui-client-agent-id client))
               (setf (local-tui-client-session-key client) arg)
               (values (format nil "[session] Switched to: ~A" arg) :continue))))

        ;; /agents
        ((string= cmd-down "agents")
         (let* ((runtime (local-tui-client-runtime client))
                (response (nilclaw/gateway:gateway-handle-request
                           (nilclaw/gateway:make-gateway-request
                            :id "tui-agents"
                            :method "agents.list"
                            :params nil)
                           runtime)))
           (if (nilclaw/gateway:gateway-response-ok-p response)
               (let ((agents (getf (nilclaw/gateway:gateway-response-result response) :agents)))
                 (if agents
                     (values (with-output-to-string (s)
                               (format s "[agents]~%")
                               (dolist (a agents)
                                 (format s "  ~A  (~A)~%"
                                         (getf a :id)
                                         (or (getf a :display-name) "-"))))
                             :continue)
                     (values "[agents] (none registered)" :continue)))
               (values "[error] Failed to list agents" :continue))))

        ;; /agent <id>
        ((string= cmd-down "agent")
         (if (string= arg "")
             (values "[error] Usage: /agent <id>" :continue)
             (progn
               (setf (local-tui-client-agent-id client) arg)
               (values (format nil "[agent] Switched to: ~A" arg) :continue))))

        ;; /models
        ((string= cmd-down "models")
         (let* ((runtime (local-tui-client-runtime client))
                (response (nilclaw/gateway:gateway-handle-request
                           (nilclaw/gateway:make-gateway-request
                            :id "tui-models"
                            :method "models.list"
                            :params nil)
                           runtime)))
           (if (nilclaw/gateway:gateway-response-ok-p response)
               (let ((models (getf (nilclaw/gateway:gateway-response-result response) :models)))
                 (if models
                     (values (with-output-to-string (s)
                               (format s "[models]~%")
                               (dolist (m models)
                                 (format s "  ~A  (~A)~%"
                                         (getf m :id)
                                         (or (getf m :provider) "-"))))
                             :continue)
                     (values "[models] (none registered)" :continue)))
               (values "[error] Failed to list models" :continue))))

        ;; /model [id] — picker when no arg
        ((string= cmd-down "model")
         (if (string= arg "")
             ;; Picker mode: list models and let user pick
             (let* ((runtime (local-tui-client-runtime client))
                    (response (nilclaw/gateway:gateway-handle-request
                               (nilclaw/gateway:make-gateway-request
                                :id "tui-model-pick"
                                :method "models.list"
                                :params nil)
                               runtime)))
               (if (nilclaw/gateway:gateway-response-ok-p response)
                   (let* ((models (getf (nilclaw/gateway:gateway-response-result response) :models))
                          (ids (mapcar (lambda (m) (getf m :id)) models)))
                     (if (null ids)
                         (values "[model] No models available." :continue)
                         (multiple-value-bind (chosen success-p)
                             (tui-pick-from-list
                              ids "[model] Pick a model:"
                              :input-fn input-fn
                              :display-fn (lambda (idx item)
                                            (let ((model (nth (1- idx) models)))
                                              (format nil "  ~D) ~A  (~A)"
                                                      idx item
                                                      (or (getf model :provider) "-")))))
                           (if success-p
                               (progn
                                 (setf (local-tui-client-model-id client) chosen)
                                 (values (format nil "[model] Set to: ~A" chosen) :continue))
                               (values "[model] Cancelled." :continue)))))
                   (values "[error] Failed to list models" :continue)))
             ;; Direct id mode
             (progn
               (setf (local-tui-client-model-id client) arg)
               (values (format nil "[model] Set to: ~A" arg) :continue))))

        ;; /new, /reset
        ((or (string= cmd-down "new") (string= cmd-down "reset"))
         (let* ((new-key (format nil "~A-~A"
                                 (local-tui-client-agent-id client)
                                 (get-universal-time)))
                (runtime (local-tui-client-runtime client)))
           (nilclaw/gateway:gateway-ensure-session
            runtime new-key "New Session" (local-tui-client-agent-id client))
           (setf (local-tui-client-session-key client) new-key)
           ;; Reset token usage on new session
           (setf (local-tui-client-token-usage client) (make-token-usage))
           (values (format nil "[reset] New session: ~A" new-key) :reset)))

        ;; /deliver <on|off>
        ((string= cmd-down "deliver")
         (cond
           ((string-equal arg "on")
            (setf (local-tui-client-deliver-p client) t)
            (values "[deliver] on" :continue))
           ((string-equal arg "off")
            (setf (local-tui-client-deliver-p client) nil)
            (values "[deliver] off" :continue))
           (t
            (values "[error] Usage: /deliver <on|off>" :continue))))

        ;; /think <off|minimal|low|medium|high>
        ((string= cmd-down "think")
         (let ((level (cond
                        ((string-equal arg "off") :off)
                        ((string-equal arg "minimal") :minimal)
                        ((string-equal arg "low") :low)
                        ((string-equal arg "medium") :medium)
                        ((string-equal arg "high") :high)
                        (t nil))))
           (if level
               (progn
                 (setf (local-tui-client-think-level client) level)
                 (values (format nil "[think] ~A" (string-downcase (symbol-name level)))
                         :continue))
               (values "[error] Usage: /think <off|minimal|low|medium|high>" :continue))))

        ;; /verbose <on|full|off>
        ((string= cmd-down "verbose")
         (let ((mode (cond
                       ((string-equal arg "on") :on)
                       ((string-equal arg "full") :full)
                       ((string-equal arg "off") :off)
                       (t nil))))
           (if mode
               (progn
                 (setf (local-tui-client-verbose-mode client) mode)
                 (values (format nil "[verbose] ~A" (string-downcase (symbol-name mode)))
                         :continue))
               (values "[error] Usage: /verbose <on|full|off>" :continue))))

        ;; /reasoning <on|off|stream>
        ((string= cmd-down "reasoning")
         (let ((mode (cond
                       ((string-equal arg "on") :on)
                       ((string-equal arg "off") :off)
                       ((string-equal arg "stream") :stream)
                       (t nil))))
           (if mode
               (progn
                 (setf (local-tui-client-reasoning-mode client) mode)
                 (values (format nil "[reasoning] ~A" (string-downcase (symbol-name mode)))
                         :continue))
               (values "[error] Usage: /reasoning <on|off|stream>" :continue))))

        ;; /context (Phase 2)
        ((string= cmd-down "context")
         (values (tui-format-context client) :continue))

        ;; /usage (Phase 2)
        ((string= cmd-down "usage")
         (values (tui-format-usage client) :continue))

        ;; /elevated <on|off> (Phase 2)
        ((string= cmd-down "elevated")
         (cond
           ((string-equal arg "on")
            (setf (local-tui-client-elevated-p client) t)
            (values "[elevated] on" :continue))
           ((string-equal arg "off")
            (setf (local-tui-client-elevated-p client) nil)
            (values "[elevated] off" :continue))
           (t
            (values "[error] Usage: /elevated <on|off>" :continue))))

        ;; /activation <on|off> (Phase 2)
        ((string= cmd-down "activation")
         (cond
           ((string-equal arg "on")
            (setf (local-tui-client-activation-mode client) :on)
            (values "[activation] on" :continue))
           ((string-equal arg "off")
            (setf (local-tui-client-activation-mode client) :off)
            (values "[activation] off" :continue))
           (t
            (values "[error] Usage: /activation <on|off>" :continue))))

        ;; /settings (Phase 2)
        ((string= cmd-down "settings")
         (values (tui-format-settings client) :continue))

        ;; /abort
        ((string= cmd-down "abort")
         (values "[abort] No active run to abort." :continue))

        ;; /exit
        ((string= cmd-down "exit")
         (values "[nilclaw-tui] Goodbye." :exit))

        ;; /history (legacy, still supported)
        ((string= cmd-down "history")
         (let ((msgs (local-tui-history client)))
           (if msgs
               (values (with-output-to-string (s)
                         (dolist (m msgs)
                           (format s "  ~A~%" (tui-format-history-entry m))))
                       :continue)
               (values "  (no history)" :continue))))

        ;; Unknown slash command
        (t
         (values (format nil "[error] Unknown command: /~A — type /help for commands" cmd)
                 :continue))))))

;;; ====================================================================
;;; Interactive TUI REPL (terminal UI)
;;; ====================================================================

(declaim (ftype (function (&key (:gateway-url string)
                                (:session-key string))
                          (values null &optional))
                run-tui))
(defun run-tui (&key (gateway-url "ws://127.0.0.1:18789")
                      (session-key "tui-session"))
  "Run the interactive NilClaw TUI.
Connects to a running gateway and provides a terminal chat interface."
  (declare (type string gateway-url session-key)
           (ignorable gateway-url))
  ;; For the interactive TUI, we use a local runtime
  ;; (in a full implementation, this would connect via WebSocket)
  (let* ((runtime (nilclaw/gateway:make-gateway-runtime))
         (client (make-local-tui-client runtime :session-key session-key)))
    ;; Connect
    (unless (local-tui-connect client)
      (format *error-output* "[nilclaw-tui] Failed to connect~%")
      (uiop:quit 1))
    ;; Banner
    (format t "~&╔══════════════════════════════════════╗~%")
    (format t "║       NilClaw TUI — Terminal UI      ║~%")
    (format t "║  Type /help for commands              ║~%")
    (format t "╚══════════════════════════════════════╝~%~%")
    ;; Initial footer
    (format t "~A~%" (tui-format-footer client))
    (finish-output)
    ;; REPL
    (loop
      (format t "~&you> ")
      (finish-output)
      (let ((line (read-line *standard-input* nil nil)))
        (when (or (null line)
                  (string-equal (string-trim '(#\Space #\Tab) line) "quit")
                  (string-equal (string-trim '(#\Space #\Tab) line) "/quit"))
          (format t "~&[nilclaw-tui] Goodbye.~%")
          (return))
        (let ((trimmed (string-trim '(#\Space #\Tab #\Newline #\Return) line)))
          (when (> (length trimmed) 0)
            (cond
              ;; Slash command
              ((char= (char trimmed 0) #\/)
               (multiple-value-bind (output action)
                   (tui-handle-slash-command client trimmed)
                 (format t "~&~A~%" output)
                 (when (eq action :exit)
                   (return))))
              ;; Shell command (! prefix)
              ((char= (char trimmed 0) #\!)
               (let ((shell-cmd (subseq trimmed 1)))
                 (multiple-value-bind (output success-p)
                     (tui-handle-shell-command client shell-cmd)
                   (declare (ignore success-p))
                   (format t "~&~A~%" output))))
              ;; Regular message
              (t
               (multiple-value-bind (response success-p)
                   (local-tui-send client trimmed)
                 (if success-p
                     (format t "~&~A assistant> ~A~%"
                             (format-timestamp (get-universal-time))
                             (or response "(no response)"))
                     (format t "~&[error] Failed to send message~%")))))
            ;; Footer after each interaction
            (format t "~A~%" (tui-format-footer client))
            (finish-output)))))))
