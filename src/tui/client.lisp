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
;;; Local TUI client (in-process, no network — for testing & embedding)
;;; ====================================================================

(defstruct (local-tui-client
            (:constructor %make-local-tui-client))
  "A TUI client that operates directly against a gateway-runtime in-process.
No network required — ideal for tests and embedded use."
  (runtime nil :type (or null nilclaw/gateway:gateway-runtime))
  (session-key "tui-local" :type string)
  (connected-p nil :type boolean)
  (connection nil :type (or null nilclaw/gateway:gateway-connection)))

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
           "tui-agent")
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
    (format t "║  Type messages, 'quit' to exit       ║~%")
    (format t "╚══════════════════════════════════════╝~%~%")
    (format t "[connected] session: ~A~%" session-key)
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
              ((string-equal trimmed "/history")
               (let ((msgs (local-tui-history client)))
                 (if msgs
                     (dolist (m msgs)
                       (format t "  [~A] ~A~%"
                               (getf m :role)
                               (getf m :content)))
                     (format t "  (no history)~%"))))
              (t
               (multiple-value-bind (response success-p)
                   (local-tui-send client trimmed)
                 (if success-p
                     (format t "~&assistant> ~A~%" (or response "(no response)"))
                     (format t "~&[error] Failed to send message~%")))))
            (finish-output)))))))
