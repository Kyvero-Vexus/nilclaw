(defpackage #:nilclaw/toolbox
  (:use #:cl)
  (:export
   ;; Identity & system prompt
   #:build-nilclaw-identity
   #:build-system-prompt
   ;; Core tool builders
   #:make-shell-tool
   #:make-file-read-tool
   #:make-file-write-tool
   #:make-file-edit-tool
   ;; Standard tool builders
   #:make-git-tool
   #:make-image-info-tool
   ;; Memory tool builders
   #:make-memory-store-tool
   #:make-memory-recall-tool
   #:make-memory-list-tool
   #:make-memory-forget-tool
   ;; Agent tool builders
   #:make-delegate-tool
   #:make-spawn-tool
   #:make-schedule-tool
   ;; Presets
   #:default-tools
   #:all-tools
   #:subagent-tools
   #:populate-registry
   ;; Toolbox struct
   #:toolbox
   #:make-toolbox
   #:toolbox-workspace-dir
   #:toolbox-allowed-paths
   #:toolbox-memory-backend
   #:toolbox-max-output-bytes
   #:toolbox-max-file-size
   #:toolbox-shell-timeout-secs))
