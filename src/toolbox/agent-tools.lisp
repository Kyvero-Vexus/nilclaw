(in-package #:nilclaw/toolbox)

(declaim (optimize (safety 3) (debug 3)))

;;; ---------------------------------------------------------------------------
;;; Agent Tools — delegation, spawning, and scheduling
;;; ---------------------------------------------------------------------------

(defun %git-handler (args-json workspace)
  "Handler implementation for the git tool."
  (let* ((args (%json-args args-json))
         (git-args (%arg args :args)))
    (unless git-args
      (return-from %git-handler "Error: missing required parameter 'args'"))
    (handler-case
        (with-output-to-string (out)
          (uiop:run-program
           (format nil "git ~A" git-args)
           :output out
           :error-output out
           :ignore-error-status t
           :directory workspace))
      (error (e)
        (format nil "Git error: ~A" e)))))

(declaim (ftype (function (toolbox) nilclaw/dispatcher:tool-definition) make-git-tool))
(defun make-git-tool (toolbox)
  "Create the git tool definition."
  (declare (type toolbox toolbox))
  (let ((workspace (toolbox-workspace-dir toolbox)))
    (nilclaw/dispatcher:make-tool-definition
     :name "git"
     :description "Execute a git command in the workspace repository.
Supports all standard git operations: status, diff, log, add, commit, push, pull, branch, etc.
The command runs in the workspace directory."
     :parameters-schema
     '((:type . "object")
       (:properties
        . ((:args . ((:type . "string")
                     (:description . "Git command arguments (e.g., 'status', 'log --oneline -10')")))))
       (:required . ("args")))
     :handler (lambda (args-json)
                (%git-handler args-json workspace))
     :risk-level :medium)))

(defun %image-info-handler (args-json toolbox)
  "Handler implementation for the image_info tool."
  (let* ((args (%json-args args-json))
         (path (or (%arg args :file--path) (%arg args :file-path)))
         (full-path (%resolve-path path (toolbox-workspace-dir toolbox))))
    (unless path
      (return-from %image-info-handler "Error: missing required parameter 'file_path'"))
    (unless (%path-allowed-p full-path toolbox)
      (return-from %image-info-handler
        (format nil "Error: path ~A is outside allowed directories" path)))
    (handler-case
        (with-output-to-string (out)
          (uiop:run-program
           (list "identify" "-verbose" full-path)
           :output out
           :error-output out
           :ignore-error-status t))
      (error (e)
        (format nil "Error getting image info: ~A" e)))))

(declaim (ftype (function (toolbox) nilclaw/dispatcher:tool-definition) make-image-info-tool))
(defun make-image-info-tool (toolbox)
  "Create the image_info tool definition."
  (declare (type toolbox toolbox))
  (nilclaw/dispatcher:make-tool-definition
   :name "image_info"
   :description "Get metadata about an image file (dimensions, format, size).
Requires the `identify` command (ImageMagick) to be available."
   :parameters-schema
   '((:type . "object")
     (:properties
      . ((:file--path . ((:type . "string")
                         (:description . "Path to the image file")))))
     (:required . ("file_path")))
   :handler (lambda (args-json)
              (%image-info-handler args-json toolbox))
   :risk-level :low))

(declaim (ftype (function (toolbox) nilclaw/dispatcher:tool-definition) make-delegate-tool))
(defun make-delegate-tool (toolbox)
  "Create the delegate tool definition."
  (declare (ignore toolbox))
  (nilclaw/dispatcher:make-tool-definition
   :name "delegate"
   :description "Delegate a task to a named sub-agent configuration.
Sub-agents have their own tool set and conversation context.
Use this for specialized tasks that benefit from a different agent configuration."
   :parameters-schema
   '((:type . "object")
     (:properties
      . ((:agent . ((:type . "string")
                    (:description . "Name of the agent configuration to delegate to")))
         (:task . ((:type . "string")
                   (:description . "Description of the task to perform")))
         (:context . ((:type . "string")
                      (:description . "Optional context to pass to the sub-agent")))))
     (:required . ("agent" "task")))
   :handler (lambda (args-json)
              (declare (ignore args-json))
              "Error: delegate tool not bound to agent runtime")
   :risk-level :medium))

(declaim (ftype (function (toolbox) nilclaw/dispatcher:tool-definition) make-spawn-tool))
(defun make-spawn-tool (toolbox)
  "Create the spawn tool definition."
  (declare (ignore toolbox))
  (nilclaw/dispatcher:make-tool-definition
   :name "spawn"
   :description "Spawn an asynchronous sub-agent to work on a task in parallel.
The sub-agent runs independently and results can be checked later.
Use this for tasks that don't need to block the current conversation."
   :parameters-schema
   '((:type . "object")
     (:properties
      . ((:task . ((:type . "string")
                   (:description . "Description of the task for the sub-agent")))
         (:tools . ((:type . "array")
                    (:items . ((:type . "string")))
                    (:description . "Optional list of tool names to make available")))))
     (:required . ("task")))
   :handler (lambda (args-json)
              (declare (ignore args-json))
              "Error: spawn tool not bound to agent runtime")
   :risk-level :medium))

(declaim (ftype (function (toolbox) nilclaw/dispatcher:tool-definition) make-schedule-tool))
(defun make-schedule-tool (toolbox)
  "Create the schedule tool definition."
  (declare (ignore toolbox))
  (nilclaw/dispatcher:make-tool-definition
   :name "schedule"
   :description "Create a scheduled task that runs on a cron schedule.
Tasks run automatically at the specified times. Use standard cron syntax.
Examples: '0 9 * * *' (daily at 9am), '*/30 * * * *' (every 30 minutes)."
   :parameters-schema
   '((:type . "object")
     (:properties
      . ((:name . ((:type . "string")
                   (:description . "Name for this scheduled task")))
         (:schedule . ((:type . "string")
                       (:description . "Cron expression (e.g., '0 9 * * *')")))
         (:task . ((:type . "string")
                   (:description . "Description of the task to perform")))))
     (:required . ("name" "schedule" "task")))
   :handler (lambda (args-json)
              (declare (ignore args-json))
              "Error: schedule tool not bound to cron runtime")
   :risk-level :medium))
