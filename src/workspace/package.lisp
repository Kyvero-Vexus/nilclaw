(defpackage #:nilclaw/workspace
  (:use #:cl)
  (:export
   ;; Constants
   #:+bootstrap-max-chars+
   #:+bootstrap-total-max-chars+
   #:+max-workspace-bootstrap-file-bytes+
   #:+bootstrap-files+
   #:+tracked-fingerprint-files+
   ;; Security
   #:validate-bootstrap-filename
   #:safe-workspace-path
   ;; Fingerprinting
   #:fnv1a-64
   #:fnv1a-64-string
   #:file-fingerprint
   ;; Bootstrap Provider Interface
   #:bootstrap-provider
   #:bootstrap-load
   #:bootstrap-load-excerpt
   #:bootstrap-store
   #:bootstrap-remove
   #:bootstrap-exists
   #:bootstrap-list-files
   #:bootstrap-fingerprint
   ;; Provider Implementations
   #:file-bootstrap-provider
   #:make-file-bootstrap-provider
   #:memory-bootstrap-provider
   #:make-memory-bootstrap-provider
   #:null-bootstrap-provider
   #:make-null-bootstrap-provider
   ;; Provider Factory
   #:make-bootstrap-provider
   ;; Workspace
   #:workspace
   #:make-workspace
   #:workspace-dir
   #:workspace-bootstrap-provider
   ;; Boot Process
   #:workspace-boot
   #:boot-result
   #:make-boot-result
   #:boot-result-sections
   #:boot-result-total-chars
   #:boot-result-truncated-p
   #:boot-result-fingerprint
   #:boot-result-files-loaded
   #:build-project-context
   ;; AIEOS
   #:aieos-configured-p
   #:parse-aieos
   #:render-aieos))
