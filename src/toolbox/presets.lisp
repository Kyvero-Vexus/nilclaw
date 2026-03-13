(in-package #:nilclaw/toolbox)

(declaim (optimize (safety 3) (debug 3)))

;;; ---------------------------------------------------------------------------
;;; Tool Presets — standard collections matching OpenClaw conventions
;;; ---------------------------------------------------------------------------

(declaim (ftype (function (toolbox) list) default-tools))
(defun default-tools (toolbox)
  "Return the default tool set (4 core tools).
   These are always available: shell, file_read, file_write, file_edit."
  (declare (type toolbox toolbox))
  (list (make-shell-tool toolbox)
        (make-file-read-tool toolbox)
        (make-file-write-tool toolbox)
        (make-file-edit-tool toolbox)))

(declaim (ftype (function (toolbox) list) all-tools))
(defun all-tools (toolbox)
  "Return the full standard tool set (core + standard + memory + agent tools).
   Includes all tools that would be available with allTools configuration."
  (declare (type toolbox toolbox))
  (append
   ;; Core tools (always available)
   (default-tools toolbox)
   ;; Standard tools
   (list (make-git-tool toolbox)
         (make-image-info-tool toolbox))
   ;; Memory tools (if backend configured)
   (when (toolbox-memory-backend toolbox)
     (list (make-memory-store-tool toolbox)
           (make-memory-recall-tool toolbox)
           (make-memory-list-tool toolbox)
           (make-memory-forget-tool toolbox)))
   ;; Agent lifecycle tools
   (list (make-delegate-tool toolbox)
         (make-spawn-tool toolbox)
         (make-schedule-tool toolbox))))

(declaim (ftype (function (toolbox) list) subagent-tools))
(defun subagent-tools (toolbox)
  "Return the restricted tool set for sub-agents.
   Sub-agents get core tools + git but NOT memory, spawn, delegate, or schedule.
   This prevents infinite loops and cross-channel side effects."
  (declare (type toolbox toolbox))
  (list (make-shell-tool toolbox)
        (make-file-read-tool toolbox)
        (make-file-write-tool toolbox)
        (make-file-edit-tool toolbox)
        (make-git-tool toolbox)))

(declaim (ftype (function (nilclaw/dispatcher:tool-registry list) nilclaw/dispatcher:tool-registry)
                populate-registry))
(defun populate-registry (registry tools)
  "Register all tools from a preset list into a registry.
   REGISTRY is the target tool-registry.
   TOOLS is a list of tool-definition structs (e.g., from default-tools).
   Returns the registry for chaining."
  (declare (type nilclaw/dispatcher:tool-registry registry)
           (type list tools))
  (dolist (tool tools)
    (nilclaw/dispatcher:register-tool registry tool))
  registry)
