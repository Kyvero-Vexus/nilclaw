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
  (reasoning-mode :off :type keyword))

(declaim (ftype (function (nilclaw/gateway:gateway-runtime &key (:session-key string))
                          local-tui-client)
                make-local-tui-client))
(defun make-local-tui-client (runtime &key (session-key "tui-local"))
  "Create a local TUI client backed by RUNTIME."
  (declare (type nilclaw/gateway:gateway-runtime runtime)
           (type string session-key))
  (%make-local-tui-client :runtime runtime :session-key session-key))

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
         (response (nilclaw/gateway:gateway-handle-request
                    (nilclaw/gateway:make-gateway-request
                     :id (format nil "tui-msg-~A" (get-universal-time))
                     :method "chat.send"
                     :params (list :session-key session-key
                                   :message message))
                    runtime)))
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
;;; Display helpers (Phase 1 parity)
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
  (format nil "~&[status]~%  connected: ~A~%  session:   ~A~%  agent:     ~A~%  model:     ~A~%  deliver:   ~A~%  think:     ~A~%  verbose:   ~A~%  reasoning: ~A"
          (if (local-tui-client-connected-p client) "yes" "no")
          (local-tui-client-session-key client)
          (local-tui-client-agent-id client)
          (let ((m (local-tui-client-model-id client)))
            (if (string= m "") "(default)" m))
          (if (local-tui-client-deliver-p client) "on" "off")
          (string-downcase (symbol-name (local-tui-client-think-level client)))
          (string-downcase (symbol-name (local-tui-client-verbose-mode client)))
          (string-downcase (symbol-name (local-tui-client-reasoning-mode client)))))

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
        (reasoning (string-downcase (symbol-name (local-tui-client-reasoning-mode client)))))
    (format nil "[~A] agent:~A session:~A model:~A deliver:~A think:~A verbose:~A reasoning:~A"
            conn agent session model deliver think verbose reasoning)))

(declaim (ftype (function () string) tui-format-help))
(defun tui-format-help ()
  "Format the /help output listing available slash commands."
  (format nil "~&NilClaw TUI Commands:~%~
  /help                    Show this help~%~
  /status                  Show connection & session status~%~
  /sessions                List sessions~%~
  /session <key>           Switch to session~%~
  /agents                  List agents~%~
  /agent <id>              Switch agent~%~
  /models                  List models~%~
  /model <provider/model>  Set model~%~
  /new, /reset             Reset current session~%~
  /deliver <on|off>        Toggle delivery~%~
  /think <off|minimal|low|medium|high>  Set thinking level~%~
  /verbose <on|full|off>   Set verbose mode~%~
  /reasoning <on|off|stream>  Set reasoning mode~%~
  /abort                   Abort active run~%~
  /exit                    Exit TUI"))

;;; ====================================================================
;;; Slash command dispatch (Phase 1 parity)
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

(declaim (ftype (function (local-tui-client string) (values string keyword))
                tui-handle-slash-command))
(defun tui-handle-slash-command (client input)
  "Handle a slash command for the local TUI client.
Returns (values output-text action) where action is :continue, :exit, or :reset."
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

        ;; /session <key>
        ((string= cmd-down "session")
         (if (string= arg "")
             (values "[error] Usage: /session <key>" :continue)
             (let ((runtime (local-tui-client-runtime client)))
               ;; Ensure session exists and switch to it
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

        ;; /model <id>
        ((string= cmd-down "model")
         (if (string= arg "")
             (values "[error] Usage: /model <provider/model>" :continue)
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
            (if (char= (char trimmed 0) #\/)
                ;; Slash command
                (multiple-value-bind (output action)
                    (tui-handle-slash-command client trimmed)
                  (format t "~&~A~%" output)
                  (when (eq action :exit)
                    (return)))
                ;; Regular message
                (multiple-value-bind (response success-p)
                    (local-tui-send client trimmed)
                  (if success-p
                      (format t "~&~A assistant> ~A~%"
                              (format-timestamp (get-universal-time))
                              (or response "(no response)"))
                      (format t "~&[error] Failed to send message~%"))))
            ;; Footer after each interaction
            (format t "~A~%" (tui-format-footer client))
            (finish-output)))))))
