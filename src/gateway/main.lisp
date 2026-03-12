;;;; main.lisp — NilClaw daemon entry point
;;;; Loads config, starts gateway, channels, and cron scheduler

(in-package #:nilclaw/gateway)

(declaim (optimize (safety 3) (debug 3)))

;;; Daemon state

(defvar *running* nil "Whether the daemon is running.")
(defvar *config* nil "Current loaded configuration.")
(defvar *channel-manager* nil "Active channel manager.")

;;; Signal handling

(defun install-signal-handlers ()
  "Install UNIX signal handlers for graceful shutdown."
  (sb-sys:enable-interrupt sb-unix:sigterm
    (lambda (sig info context)
      (declare (ignore sig info context))
      (format *error-output* "~&[nilclaw] SIGTERM received, shutting down...~%")
      (setf *running* nil)))
  (sb-sys:enable-interrupt sb-unix:sigint
    (lambda (sig info context)
      (declare (ignore sig info context))
      (format *error-output* "~&[nilclaw] SIGINT received, shutting down...~%")
      (setf *running* nil))))

;;; Startup

(declaim (ftype (function (&key (:config-path (or null string))
                                (:foreground boolean))
                          (values null &optional))
                start-daemon))
(defun start-daemon (&key config-path (foreground t))
  "Start the NilClaw daemon."
  (declare (type (or null string) config-path)
           (type boolean foreground))
  (format t "~&[nilclaw] Starting NilClaw daemon...~%")

  ;; Load configuration
  (setf *config* (nilclaw/config:load-config config-path))
  (format t "[nilclaw] Configuration loaded~%")

  ;; Validate config
  (let ((errors (nilclaw/config:validate-config *config*)))
    (when errors
      (format *error-output* "[nilclaw] Configuration warnings:~%")
      (dolist (err errors)
        (format *error-output* "  - ~A: ~A~%"
                (nilclaw/config:validation-error-kind err)
                (nilclaw/config:validation-error-message err)))))

  ;; Set up channel manager
  (setf *channel-manager* (nilclaw/channel:make-channel-manager))

  ;; Register CLI channel if configured or default
  (nilclaw/channel:register-channel *channel-manager* "cli"
    (nilclaw/channel:make-cli-channel))

  ;; Start channels
  (nilclaw/channel:start-all-channels *channel-manager*)
  (format t "[nilclaw] Channels started~%")

  ;; Install signal handlers
  (install-signal-handlers)

  ;; Start HTTP server
  (let* ((gw (nilclaw/config:config-gateway *config*))
         (port (or (getf gw :port) *default-http-port*))
         (runtime (make-gateway-runtime :port port)))
    (start-http-server :port port :runtime runtime)
    (format t "[nilclaw] Gateway listening on ~A:~A~%"
            (getf gw :host) port))
  (format t "[nilclaw] NilClaw is ready.~%")

  ;; Main loop
  (setf *running* t)
  (unwind-protect
      (loop while *running*
            do (sleep 1))
    ;; Cleanup
    (format t "~&[nilclaw] Shutting down...~%")
    (stop-http-server)
    (nilclaw/channel:stop-all-channels *channel-manager*)
    (format t "[nilclaw] Channels stopped~%")
    (format t "[nilclaw] NilClaw stopped.~%")
    (setf *running* nil))
  nil)

;;; CLI chat command

(declaim (ftype (function (&key (:config-path (or null string))
                                (:model (or null string))
                                (:system-prompt (or null string)))
                          (values null &optional))
                run-chat))
(defun run-chat (&key config-path model system-prompt)
  "Run a single-shot chat: read stdin, call provider, print response to stdout."
  (declare (type (or null string) config-path model system-prompt))
  ;; Load config
  (let* ((cfg (nilclaw/config:load-config config-path))
         ;; Resolve provider/model
         (default-model (or model
                            (nilclaw/config:config-default-model cfg)
                            (format nil "~A/default"
                                    (nilclaw/config:config-default-provider cfg)))))
    (declare (type string default-model))
    (multiple-value-bind (provider-name model-name)
        (nilclaw/config:parse-model-string default-model)
      ;; Build provider runtime from config
      (multiple-value-bind (provider-runtime found-p)
          (nilclaw/config:make-provider-runtime-from-config
           cfg provider-name :model default-model)
        (declare (ignore found-p))
        (unless provider-runtime
          (format *error-output* "[nilclaw] Error: could not create provider runtime for ~A~%"
                  provider-name)
          (uiop:quit 1))
        ;; Enable HTTP backend
        (nilclaw/provider:enable-dexador-backend)
        ;; Read all of stdin
        (let ((input (with-output-to-string (s)
                       (loop for line = (read-line *standard-input* nil nil)
                             while line
                             do (write-line line s)))))
          (let ((trimmed (string-trim '(#\Space #\Tab #\Newline #\Return) input)))
            (when (zerop (length trimmed))
              (format *error-output* "[nilclaw] Error: no input provided~%")
              (uiop:quit 1))
            ;; Call agent-chat
            (multiple-value-bind (response success-p)
                (nilclaw/agent:agent-chat trimmed provider-runtime
                                         :system-prompt system-prompt)
              (format t "~A~%" response)
              (finish-output)
              (unless success-p
                (uiop:quit 1)))))))))

;;; Interactive chat REPL

(declaim (ftype (function (&key (:config-path (or null string))
                                (:model (or null string))
                                (:system-prompt (or null string)))
                          (values null &optional))
                run-chat-repl))
(defun run-chat-repl (&key config-path model system-prompt)
  "Run an interactive chat REPL: read lines, call provider, print responses."
  (declare (type (or null string) config-path model system-prompt))
  (let* ((cfg (nilclaw/config:load-config config-path))
         (default-model (or model
                            (nilclaw/config:config-default-model cfg)
                            (format nil "~A/default"
                                    (nilclaw/config:config-default-provider cfg)))))
    (declare (type string default-model))
    (multiple-value-bind (provider-name model-name)
        (nilclaw/config:parse-model-string default-model)
      (declare (ignore model-name))
      (multiple-value-bind (provider-runtime found-p)
          (nilclaw/config:make-provider-runtime-from-config
           cfg provider-name :model default-model)
        (declare (ignore found-p))
        (unless provider-runtime
          (format *error-output* "[nilclaw] Error: could not create provider runtime for ~A~%"
                  provider-name)
          (uiop:quit 1))
        (nilclaw/provider:enable-dexador-backend)
        (format t "[nilclaw] Chat session with ~A (type 'quit' to exit)~%" default-model)
        (finish-output)
        (let ((history '()))
          (loop
            (format t "~&> ")
            (finish-output)
            (let ((line (read-line *standard-input* nil nil)))
              (when (or (null line)
                        (string-equal (string-trim '(#\Space #\Tab) line) "quit"))
                (format t "~&[nilclaw] Goodbye.~%")
                (return))
              (let ((trimmed (string-trim '(#\Space #\Tab #\Newline #\Return) line)))
                (when (> (length trimmed) 0)
                  (multiple-value-bind (response success-p)
                      (nilclaw/agent:agent-chat trimmed provider-runtime
                                               :system-prompt system-prompt
                                               :history history)
                    (format t "~&~A~%" response)
                    (finish-output)
                    ;; Accumulate history for multi-turn
                    (when success-p
                      (push `((:role . "user") (:content . ,trimmed)) history)
                      (push `((:role . "assistant") (:content . ,response)) history)
                      (setf history (nreverse history)))))))))))))

;;; CLI entry point

(defun main ()
  "CLI entry point for NilClaw."
  (let* ((raw-args (uiop:command-line-arguments))
         ;; Filter out the "--" separator that SBCL includes
         (args (remove "--" raw-args :test #'string=))
         (command (first args)))
    (cond
      ((or (null command) (string= command "start"))
       (start-daemon :config-path (second args)))
      ((string= command "chat")
       ;; Parse chat sub-options
       (let ((config-path nil)
             (model nil)
             (system-prompt nil)
             (interactive nil)
             (rest-args (rest args)))
         (loop while rest-args
               do (let ((arg (pop rest-args)))
                    (cond
                      ((string= arg "--config")
                       (setf config-path (pop rest-args)))
                      ((string= arg "--model")
                       (setf model (pop rest-args)))
                      ((string= arg "--system")
                       (setf system-prompt (pop rest-args)))
                      ((string= arg "-i")
                       (setf interactive t))
                      ((string= arg "--interactive")
                       (setf interactive t)))))
         (if interactive
             (run-chat-repl :config-path config-path
                            :model model
                            :system-prompt system-prompt)
             (run-chat :config-path config-path
                       :model model
                       :system-prompt system-prompt))))
      ((string= command "version")
       (format t "NilClaw 0.1.0~%"))
      ((string= command "check")
       (let ((cfg (nilclaw/config:load-config (second args))))
         (let ((errors (nilclaw/config:validate-config cfg)))
           (if errors
               (progn
                 (format t "Configuration has ~D warning(s):~%" (length errors))
                 (dolist (err errors)
                   (format t "  - ~A: ~A~%"
                           (nilclaw/config:validation-error-kind err)
                           (nilclaw/config:validation-error-message err)))
                 (uiop:quit 1))
               (format t "Configuration OK~%")))))
      ((string= command "migrate")
       (format t "Use: sbcl --script scripts/migrate-openclaw-config.lisp~%"))
      ((string= command "help")
       (format t "NilClaw — Statically typed Common Lisp agent harness~%~%")
       (format t "Usage: nilclaw [command] [options]~%~%")
       (format t "Commands:~%")
       (format t "  start [config]   Start the daemon (default)~%")
       (format t "  chat [options]   Chat with a provider~%")
       (format t "  check [config]   Validate configuration~%")
       (format t "  migrate          Show migration instructions~%")
       (format t "  version          Print version~%")
       (format t "  help             Show this help~%~%")
       (format t "Chat options:~%")
       (format t "  --config PATH    Configuration file~%")
       (format t "  --model MODEL    Model to use (provider/model)~%")
       (format t "  --system TEXT    System prompt~%")
       (format t "  -i, --interactive  Interactive REPL mode~%~%")
       (format t "Examples:~%")
       (format t "  echo 'hello' | nilclaw chat~%")
       (format t "  nilclaw chat -i~%")
       (format t "  echo 'hello' | nilclaw chat --model openai/gpt-4o~%~%")
       (format t "Config search path:~%")
       (format t "  ~~/.nilclaw/init.lisp~%")
       (format t "  ~~/.nilclaw/config.lisp~%")
       (format t "  ~~/.config/nilclaw/init.lisp~%"))
      (t
       (format *error-output* "Unknown command: ~A~%Use 'nilclaw help' for usage.~%" command)
       (uiop:quit 1)))))
