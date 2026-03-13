(in-package #:nilclaw/workspace)

(declaim (optimize (safety 3) (debug 3)))

;;; ---------------------------------------------------------------------------
;;; Workspace bootstrap constants — matching OpenClaw specification
;;; ---------------------------------------------------------------------------

(defconstant +bootstrap-max-chars+ 20000
  "Maximum characters from a single bootstrap file.")

(defconstant +bootstrap-total-max-chars+ 24000
  "Maximum total characters from all bootstrap files combined.")

(defconstant +max-workspace-bootstrap-file-bytes+ (* 2 1024 1024)
  "Hard limit on file size for reading (2 MB).")

(defparameter *bootstrap-files*
  '("AGENTS.md" "SOUL.md" "TOOLS.md" "IDENTITY.md"
    "USER.md" "HEARTBEAT.md" "BOOTSTRAP.md" "MEMORY.md")
  "Canonical bootstrap file list in loading order.")

(defun +bootstrap-files+ ()
  "Return the canonical bootstrap file list in loading order."
  (copy-list *bootstrap-files*))

(defparameter *tracked-fingerprint-files*
  '("AGENTS.md" "SOUL.md" "TOOLS.md" "IDENTITY.md"
    "USER.md" "HEARTBEAT.md" "BOOTSTRAP.md" "MEMORY.md" "memory.md")
  "Files tracked for fingerprinting (includes both MEMORY.md and memory.md).")

(defun +tracked-fingerprint-files+ ()
  "Return the list of files tracked for fingerprinting."
  (copy-list *tracked-fingerprint-files*))

(defparameter *bootstrap-memory-key-prefix* "__bootstrap.prompt."
  "Memory key prefix for bootstrap files stored in database backends.")
