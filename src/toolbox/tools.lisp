(in-package #:nilclaw/toolbox)

(declaim (optimize (safety 3) (debug 3)))

;;; ---------------------------------------------------------------------------
;;; Toolbox configuration — shared context for tool construction
;;; ---------------------------------------------------------------------------

(defstruct toolbox
  "Configuration context for building standard tools."
  (workspace-dir "." :type string)
  (allowed-paths nil :type list)
  (memory-backend nil :type (or null nilclaw/memory:memory-backend))
  (max-output-bytes 1048576 :type (integer 1 *))
  (max-file-size 10485760 :type (integer 1 *))
  (shell-timeout-secs 60 :type (integer 1 *)))

;;; ---------------------------------------------------------------------------
;;; Path security helpers
;;; ---------------------------------------------------------------------------

(declaim (ftype (function (string toolbox) boolean) %path-allowed-p))
(defun %path-allowed-p (path toolbox)
  "Check if PATH is within workspace-dir or allowed-paths."
  (declare (type string path)
           (type toolbox toolbox))
  (let ((resolved (handler-case (namestring (truename path))
                    (error () nil))))
    (when (null resolved)
      (return-from %path-allowed-p nil))
    (let ((ws (handler-case (namestring (truename (toolbox-workspace-dir toolbox)))
                (error () nil))))
      (when (and ws (eql 0 (search ws resolved)))
        (return-from %path-allowed-p t)))
    (dolist (allowed (toolbox-allowed-paths toolbox))
      (let ((ap (handler-case (namestring (truename allowed))
                  (error () nil))))
        (when (and ap (eql 0 (search ap resolved)))
          (return-from %path-allowed-p t))))
    nil))

(declaim (ftype (function (string) list) %json-args))
(defun %json-args (json-string)
  "Decode JSON arguments string to an alist."
  (declare (type string json-string))
  (handler-case (json:decode-json-from-string json-string)
    (error () nil)))

(defun %arg (args key)
  "Extract a value from decoded JSON args alist by keyword KEY."
  (cdr (assoc key args)))

(defun %resolve-path (path workspace-dir)
  "Resolve PATH relative to WORKSPACE-DIR if not absolute."
  (if (and path (> (length path) 0) (char= (char path 0) #\/))
      path
      (format nil "~A/~A" workspace-dir path)))

;;; ---------------------------------------------------------------------------
;;; Core Tools — always available
;;; ---------------------------------------------------------------------------

(defun %shell-handler (args-json workspace max-output timeout)
  "Handler implementation for the shell tool."
  (declare (ignore timeout))
  (let* ((args (%json-args args-json))
         (command (%arg args :command)))
    (unless command
      (return-from %shell-handler "Error: missing required parameter 'command'"))
    (handler-case
        (let* ((output (with-output-to-string (out)
                         (uiop:run-program
                          (list "/bin/sh" "-c" command)
                          :output out
                          :error-output out
                          :ignore-error-status t
                          :directory workspace))))
          (if (> (length output) max-output)
              (format nil "~A~%[... output truncated at ~D bytes]"
                      (subseq output 0 max-output) max-output)
              output))
      (error (e)
        (format nil "Shell error: ~A" e)))))

(declaim (ftype (function (toolbox) nilclaw/dispatcher:tool-definition) make-shell-tool))
(defun make-shell-tool (toolbox)
  "Create the shell tool definition."
  (declare (type toolbox toolbox))
  (let ((workspace (toolbox-workspace-dir toolbox))
        (timeout (toolbox-shell-timeout-secs toolbox))
        (max-output (toolbox-max-output-bytes toolbox)))
    (nilclaw/dispatcher:make-tool-definition
     :name "shell"
     :description "Execute a shell command in the workspace directory.
Use this for running programs, scripts, git commands, build tools, and system operations.
Commands run with a timeout and output is truncated if too large.
Always use non-interactive flags (-f, -y) to prevent hanging on prompts."
     :parameters-schema
     '((:type . "object")
       (:properties
        . ((:command . ((:type . "string")
                        (:description . "The shell command to execute")))
           (:timeout . ((:type . "number")
                        (:description . "Optional timeout override in seconds")))))
       (:required . ("command")))
     :handler (lambda (args-json)
                (%shell-handler args-json workspace max-output timeout))
     :risk-level :high)))

(defun %file-read-handler (args-json toolbox max-size)
  "Handler implementation for the file_read tool."
  (let* ((args (%json-args args-json))
         (path (or (%arg args :file--path) (%arg args :file-path)))
         (full-path (%resolve-path path (toolbox-workspace-dir toolbox))))
    (unless path
      (return-from %file-read-handler "Error: missing required parameter 'file_path'"))
    (unless (%path-allowed-p full-path toolbox)
      (return-from %file-read-handler
        (format nil "Error: path ~A is outside allowed directories" path)))
    (handler-case
        (let ((content (uiop:read-file-string full-path)))
          (if (> (length content) max-size)
              (format nil "~A~%[... file truncated at ~D bytes, use offset/limit for full content]"
                      (subseq content 0 max-size) max-size)
              content))
      (file-error (e)
        (format nil "Error reading file: ~A" e)))))

(declaim (ftype (function (toolbox) nilclaw/dispatcher:tool-definition) make-file-read-tool))
(defun make-file-read-tool (toolbox)
  "Create the file_read tool definition."
  (declare (type toolbox toolbox))
  (let ((max-size (toolbox-max-file-size toolbox)))
    (nilclaw/dispatcher:make-tool-definition
     :name "file_read"
     :description "Read the contents of a file. Returns the file content as text.
Use this to examine source code, configuration files, documentation, and data.
Paths are relative to the workspace directory or absolute."
     :parameters-schema
     '((:type . "object")
       (:properties
        . ((:file--path . ((:type . "string")
                           (:description . "Path to the file to read (relative or absolute)")))
           (:offset . ((:type . "number")
                       (:description . "Optional byte offset to start reading from")))
           (:limit . ((:type . "number")
                      (:description . "Optional maximum number of bytes to read")))))
       (:required . ("file_path")))
     :handler (lambda (args-json)
                (%file-read-handler args-json toolbox max-size))
     :risk-level :low)))

(defun %file-write-handler (args-json toolbox)
  "Handler implementation for the file_write tool."
  (let* ((args (%json-args args-json))
         (path (or (%arg args :file--path) (%arg args :file-path)))
         (content (%arg args :content))
         (full-path (%resolve-path path (toolbox-workspace-dir toolbox))))
    (unless path
      (return-from %file-write-handler "Error: missing required parameter 'file_path'"))
    (unless content
      (return-from %file-write-handler "Error: missing required parameter 'content'"))
    (unless (%path-allowed-p (directory-namestring full-path) toolbox)
      (return-from %file-write-handler
        (format nil "Error: path ~A is outside allowed directories" path)))
    (handler-case
        (progn
          (ensure-directories-exist full-path)
          (with-open-file (s full-path :direction :output
                                       :if-exists :supersede
                                       :if-does-not-exist :create)
            (write-string content s))
          (format nil "Wrote ~D bytes to ~A" (length content) path))
      (error (e)
        (format nil "Error writing file: ~A" e)))))

(declaim (ftype (function (toolbox) nilclaw/dispatcher:tool-definition) make-file-write-tool))
(defun make-file-write-tool (toolbox)
  "Create the file_write tool definition."
  (declare (type toolbox toolbox))
  (nilclaw/dispatcher:make-tool-definition
   :name "file_write"
   :description "Write content to a file, creating it if necessary.
This overwrites the entire file content. Use file_edit for targeted changes.
Parent directories are created automatically."
   :parameters-schema
   '((:type . "object")
     (:properties
      . ((:file--path . ((:type . "string")
                         (:description . "Path to the file to write")))
         (:content . ((:type . "string")
                      (:description . "The content to write to the file")))))
     (:required . ("file_path" "content")))
   :handler (lambda (args-json)
              (%file-write-handler args-json toolbox))
   :risk-level :medium))

(defun %file-edit-handler (args-json toolbox)
  "Handler implementation for the file_edit tool."
  (let* ((args (%json-args args-json))
         (path (or (%arg args :file--path) (%arg args :file-path)))
         (old-str (or (%arg args :old--string) (%arg args :old-string)))
         (new-str (or (%arg args :new--string) (%arg args :new-string)))
         (replace-all (or (%arg args :replace--all) (%arg args :replace-all)))
         (full-path (%resolve-path path (toolbox-workspace-dir toolbox))))
    (unless path
      (return-from %file-edit-handler "Error: missing required parameter 'file_path'"))
    (unless old-str
      (return-from %file-edit-handler "Error: missing required parameter 'old_string'"))
    (unless new-str
      (return-from %file-edit-handler "Error: missing required parameter 'new_string'"))
    (unless (%path-allowed-p full-path toolbox)
      (return-from %file-edit-handler
        (format nil "Error: path ~A is outside allowed directories" path)))
    (handler-case
        (let* ((content (uiop:read-file-string full-path))
               (count (let ((c 0) (start 0))
                        (loop
                          (let ((pos (search old-str content :start2 start)))
                            (unless pos (return c))
                            (incf c)
                            (setf start (+ pos (length old-str))))))))
          (cond
            ((= count 0)
             (format nil "Error: old_string not found in ~A" path))
            ((and (> count 1) (not replace-all))
             (format nil "Error: old_string found ~D times in ~A (use replace_all for global replacement)"
                     count path))
            (t
             (let ((new-content
                     (if replace-all
                         (let ((result content) (offset 0))
                           (loop
                             (let ((pos (search old-str result :start2 offset)))
                               (unless pos (return result))
                               (setf result (concatenate 'string
                                                         (subseq result 0 pos)
                                                         new-str
                                                         (subseq result (+ pos (length old-str)))))
                               (setf offset (+ pos (length new-str))))))
                         (let ((pos (search old-str content)))
                           (concatenate 'string
                                        (subseq content 0 pos)
                                        new-str
                                        (subseq content (+ pos (length old-str))))))))
               (with-open-file (s full-path :direction :output
                                             :if-exists :supersede)
                 (write-string new-content s))
               (format nil "Edited ~A: replaced ~D occurrence~:P"
                       path (if replace-all count 1))))))
      (file-error (e)
        (format nil "Error editing file: ~A" e)))))

(declaim (ftype (function (toolbox) nilclaw/dispatcher:tool-definition) make-file-edit-tool))
(defun make-file-edit-tool (toolbox)
  "Create the file_edit tool definition."
  (declare (type toolbox toolbox))
  (nilclaw/dispatcher:make-tool-definition
   :name "file_edit"
   :description "Edit a file by finding and replacing a specific string.
The old_string must appear exactly once in the file (or use replace_all for global replacement).
This is safer and more precise than file_write for modifications."
   :parameters-schema
   '((:type . "object")
     (:properties
      . ((:file--path . ((:type . "string")
                         (:description . "Path to the file to edit")))
         (:old--string . ((:type . "string")
                          (:description . "The exact text to find and replace")))
         (:new--string . ((:type . "string")
                          (:description . "The replacement text")))
         (:replace--all . ((:type . "boolean")
                           (:description . "Replace all occurrences (default: false)")))))
     (:required . ("file_path" "old_string" "new_string")))
   :handler (lambda (args-json)
              (%file-edit-handler args-json toolbox))
   :risk-level :medium))
