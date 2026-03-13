;;;; claude-cli.lisp — Claude Code CLI transport for Claude Max subscription path
;;;; Sends completions through the `claude` CLI binary, bypassing HTTP API keys.
;;;; This enables Claude Max (claude.ai subscription) usage for Anthropic models.
;;;;
;;;; NilClaw - Statically typed Common Lisp agent harness

(in-package #:nilclaw/provider)

(declaim (optimize (safety 3) (debug 3)))

;;; ====================================================================
;;; Claude CLI availability detection
;;; ====================================================================

(declaim (ftype (function () (or null string)) find-claude-cli-path))
(defun find-claude-cli-path ()
  "Find the claude CLI binary path. Returns nil if not found."
  (handler-case
      (let ((output (string-trim '(#\Space #\Tab #\Newline #\Return)
                                 (uiop:run-program "which claude"
                                                   :output :string
                                                   :error-output nil
                                                   :ignore-error-status t))))
        (if (and (> (length output) 0)
                 (probe-file output))
            output
            nil))
    (error () nil)))

(defvar *claude-cli-path-cache* :unset
  "Cached result of find-claude-cli-path. :unset means not yet checked.")

(declaim (ftype (function () boolean) claude-cli-available-p))
(defun claude-cli-available-p ()
  "Return T if the claude CLI binary is available on the system."
  (when (eq *claude-cli-path-cache* :unset)
    (setf *claude-cli-path-cache* (find-claude-cli-path)))
  (not (null *claude-cli-path-cache*)))

(defun reset-claude-cli-cache ()
  "Reset the cached CLI path (useful for testing)."
  (setf *claude-cli-path-cache* :unset))

;;; ====================================================================
;;; Claude CLI invocation
;;; ====================================================================

(declaim (ftype (function (string string) (values (or null string) (or null keyword)))
                claude-cli-complete))
(defun claude-cli-complete (prompt model)
  "Send a completion request through the claude CLI.
   PROMPT is the user message text.
   MODEL is the Anthropic model name (e.g. \"claude-opus-4-0520\").
   Returns (values content error-code).
   Content is the assistant response text on success, nil on failure.
   Error-code is nil on success, a keyword on failure."
  (declare (type string prompt model))
  (unless (claude-cli-available-p)
    (return-from claude-cli-complete
      (values nil :claude-cli-unavailable)))
  (let ((cli-path (or *claude-cli-path-cache*
                      (find-claude-cli-path))))
    (unless cli-path
      (return-from claude-cli-complete
        (values nil :claude-cli-unavailable)))
    ;; Strip provider prefix if present (e.g. "anthropic/claude-opus-4-0520" -> "claude-opus-4-0520")
    (let* ((bare-model (let ((slash (position #\/ model)))
                         (if (and slash (> slash 0))
                             (subseq model (1+ slash))
                             model)))
           ;; Build claude CLI command
           ;; Force Claude Max subscription auth path by unsetting ANTHROPIC_API_KEY
           ;; so local environment API keys don't force pay-as-you-go mode.
           ;; env -u ANTHROPIC_API_KEY claude -p "prompt" --model MODEL --output-format text
           (cmd (format nil "env -u ANTHROPIC_API_KEY ~A -p ~A --model ~A --output-format text 2>&1"
                        cli-path
                        (shell-escape prompt)
                        (shell-escape bare-model))))
      (handler-case
          (multiple-value-bind (output error-output exit-code)
              (uiop:run-program cmd
                                :output :string
                                :error-output :string
                                :ignore-error-status t)
            (declare (ignore error-output))
            (cond
              ;; Success
              ((zerop exit-code)
               (let ((trimmed (string-trim '(#\Space #\Tab #\Newline #\Return)
                                           (or output ""))))
                 (if (> (length trimmed) 0)
                     (values trimmed nil)
                     (values nil :empty-response))))
              ;; Auth/login errors (exit code 1 with auth-related output)
              ((and (= exit-code 1)
                    (or (search "not logged in" (or output "") :test #'char-equal)
                        (search "authentication" (or output "") :test #'char-equal)
                        (search "login" (or output "") :test #'char-equal)
                        (search "unauthorized" (or output "") :test #'char-equal)
                        (search "invalid api key" (or output "") :test #'char-equal)
                        (search "api key" (or output "") :test #'char-equal)))
               (values nil :claude-cli-not-logged-in))
              ;; Other errors
              (t
               (values nil :claude-cli-error))))
        (error ()
          (values nil :claude-cli-error))))))

;;; ====================================================================
;;; Shell escaping helper
;;; ====================================================================

(declaim (ftype (function (string) string) shell-escape))
(defun shell-escape (str)
  "Escape a string for safe use in a shell command (single-quote wrapping)."
  (declare (type string str))
  (with-output-to-string (s)
    (write-char #\' s)
    (loop for ch across str
          do (if (char= ch #\')
                 (write-string "'\\''" s)
                 (write-char ch s)))
    (write-char #\' s)))

;;; ====================================================================
;;; Transport function for provider-complete integration
;;; ====================================================================

(declaim (ftype (function (string) function) make-claude-cli-transport-fn))
(defun make-claude-cli-transport-fn (model)
  "Create a transport function for provider-complete that uses the Claude CLI.
   MODEL is the full model string (may include provider/ prefix).
   The returned function has signature (request attempt-index) -> (values content error-code)."
  (declare (type string model))
  (lambda (request attempt-index)
    (declare (type provider-request request)
             (type (integer 0 *) attempt-index)
             (ignore attempt-index))
    ;; Extract the last user message from the request
    (let* ((messages (provider-request-messages request))
           (last-user-msg (find-if (lambda (msg)
                                     (let ((role (cdr (assoc :role msg))))
                                       (and role (string-equal role "user"))))
                                   messages
                                   :from-end t))
           (prompt (if last-user-msg
                       (or (cdr (assoc :content last-user-msg)) "")
                       "")))
      (claude-cli-complete prompt model))))

;;; ====================================================================
;;; Claude CLI transport type for provider-runtime
;;; ====================================================================

(deftype provider-transport ()
  "Transport mechanism for provider completions."
  '(member :http :claude-cli))

;;; Provider error code extension for Claude CLI errors
;;; These are already valid under (or null keyword) type.
;;; :claude-cli-unavailable — CLI binary not found
;;; :claude-cli-not-logged-in — CLI not authenticated
;;; :claude-cli-error — generic CLI execution error
;;; :empty-response — CLI returned empty output
