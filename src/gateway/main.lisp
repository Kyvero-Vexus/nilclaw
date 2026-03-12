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

  ;; Print status
  (let ((gw (nilclaw/config:config-gateway *config*)))
    (format t "[nilclaw] Gateway listening on ~A:~A~%"
            (getf gw :host) (getf gw :port)))
  (format t "[nilclaw] NilClaw is ready.~%")

  ;; Main loop
  (setf *running* t)
  (unwind-protect
      (loop while *running*
            do (sleep 1))
    ;; Cleanup
    (format t "~&[nilclaw] Shutting down...~%")
    (nilclaw/channel:stop-all-channels *channel-manager*)
    (format t "[nilclaw] Channels stopped~%")
    (format t "[nilclaw] NilClaw stopped.~%")
    (setf *running* nil))
  nil)

;;; CLI entry point

(defun main ()
  "CLI entry point for NilClaw."
  (let* ((args (uiop:command-line-arguments))
         (command (first args)))
    (cond
      ((or (null command) (string= command "start"))
       (start-daemon :config-path (second args)))
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
       (format t "  start [config]  Start the daemon (default)~%")
       (format t "  check [config]  Validate configuration~%")
       (format t "  migrate         Show migration instructions~%")
       (format t "  version         Print version~%")
       (format t "  help            Show this help~%~%")
       (format t "Config search path:~%")
       (format t "  ~~/.nilclaw/init.lisp~%")
       (format t "  ~~/.nilclaw/config.lisp~%")
       (format t "  ~~/.config/nilclaw/init.lisp~%"))
      (t
       (format *error-output* "Unknown command: ~A~%Use 'nilclaw help' for usage.~%" command)
       (uiop:quit 1)))))
