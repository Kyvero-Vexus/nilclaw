;;;; cli.lisp - CLI channel implementation
;;;; NilClaw - Statically typed Common Lisp agent harness

(in-package #:nilclaw/channel)

(declaim (optimize (speed 3) (safety 3) (debug 1)))

;;; CLI channel - built-in stdin/stdout channel

(defstruct (cli-channel
            (:constructor make-cli-channel ()))
  "CLI channel using stdin/stdout."
  (running nil :type boolean))

(defmethod channel-start ((channel cli-channel))
  "Start the CLI channel (no-op, always available)."
  (declare (type cli-channel channel))
  (setf (cli-channel-running channel) t)
  t)

(defmethod channel-stop ((channel cli-channel))
  "Stop the CLI channel."
  (declare (type cli-channel channel))
  (setf (cli-channel-running channel) nil)
  t)

(defmethod channel-send ((channel cli-channel) target message &optional media)
  "Send a message to stdout."
  (declare (type cli-channel channel)
           (type string target message)
           (ignore target media))
  (when (cli-channel-running channel)
    (format t "~A~%" message)
    (finish-output))
  t)

(defmethod channel-name ((channel cli-channel))
  "Return the channel name."
  (declare (type cli-channel channel))
  "cli")

(defmethod channel-health-check ((channel cli-channel))
  "CLI is always healthy."
  (declare (type cli-channel channel))
  (cli-channel-running channel))

;;; Web channel stub (for config compatibility)

(defstruct (web-channel
            (:constructor %make-web-channel))
  "Web channel for browser-based messaging."
  (path "/" :type string)
  (auth-token nil :type (or null string))
  (allowed-origins '() :type list)
  (transport :relay :type (member :relay :local))
  (relay-url nil :type (or null string))
  (message-auth-mode :none :type (member :none :token))
  (running nil :type boolean))

(declaim (ftype (function (&key (:path string)
                         (:auth-token (or null string))
                         (:allowed-origins list)
                         (:transport (member :relay :local))
                         (:relay-url (or null string))
                         (:message-auth-mode (member :none :token)))
                        (values web-channel &optional))
                make-web-channel))
(defun make-web-channel (&key (path "/")
                           (auth-token nil)
                           (allowed-origins '())
                           (transport :relay)
                           (relay-url nil)
                           (message-auth-mode :none))
  "Create a web channel with the given configuration."
  (declare (type string path)
           (type (or null string) auth-token relay-url)
           (type list allowed-origins)
           (type (member :relay :local) transport)
           (type (member :none :token) message-auth-mode))
  (%make-web-channel :path path
                     :auth-token auth-token
                     :allowed-origins allowed-origins
                     :transport transport
                     :relay-url relay-url
                     :message-auth-mode message-auth-mode))

(defmethod channel-start ((channel web-channel))
  "Start the web channel."
  (declare (type web-channel channel))
  ;; TODO: Implement WebSocket connection for relay/local transport
  (setf (web-channel-running channel) t)
  t)

(defmethod channel-stop ((channel web-channel))
  "Stop the web channel."
  (declare (type web-channel channel))
  (setf (web-channel-running channel) nil)
  t)

(defmethod channel-send ((channel web-channel) target message &optional media)
  "Send a message through the web channel."
  (declare (type web-channel channel)
           (type string target message)
           (ignore media))
  ;; TODO: Implement actual sending logic
  (when (web-channel-running channel)
    ;; Stub: just return success
    t))

(defmethod channel-name ((channel web-channel))
  "Return the channel name."
  (declare (type web-channel channel))
  "web")

(defmethod channel-health-check ((channel web-channel))
  "Check web channel health."
  (declare (type web-channel channel))
  (web-channel-running channel))
