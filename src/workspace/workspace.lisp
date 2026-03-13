(in-package #:nilclaw/workspace)

(declaim (optimize (safety 3) (debug 3)))

;;; ---------------------------------------------------------------------------
;;; Workspace — core struct and boot process
;;; ---------------------------------------------------------------------------

(defstruct workspace
  "Workspace configuration for the agent boot process.
   Holds the workspace directory, bootstrap provider, and manages
   the loading of identity/workspace files into the system prompt."
  (dir "." :type string)
  (bootstrap-provider nil :type (or null bootstrap-provider)))

;;; ---------------------------------------------------------------------------
;;; Boot Result — captures the output of workspace-boot
;;; ---------------------------------------------------------------------------

(defstruct boot-result
  "Result of the workspace boot process."
  (sections nil :type list)            ; alist of (filename . content)
  (total-chars 0 :type (integer 0 *))  ; total chars loaded
  (truncated-p nil :type boolean)       ; whether total limit was hit
  (fingerprint 0 :type (unsigned-byte 64))
  (files-loaded nil :type list))        ; list of filenames that were loaded

;;; ---------------------------------------------------------------------------
;;; File Loading — respects per-file and total char limits
;;; ---------------------------------------------------------------------------

(defun %load-bootstrap-file (provider filename max-chars)
  "Load a bootstrap file through PROVIDER, truncating at MAX-CHARS.
   Returns (values content truncated-p) or (values nil nil) if not found."
  (declare (type bootstrap-provider provider)
           (type string filename)
           (type (integer 0 *) max-chars))
  ;; Load one extra char to detect truncation
  (let ((content (bootstrap-load-excerpt provider filename (1+ max-chars))))
    (if (null content)
        (values nil nil)
        (if (> (length content) max-chars)
            (values (subseq content 0 max-chars) t)
            (values content nil)))))

(defun %try-memory-md-fallback (provider)
  "If MEMORY.md is not available, try loading memory.md (lowercase fallback).
   Returns the filename that was found, or NIL."
  (declare (type bootstrap-provider provider))
  (when (and (not (bootstrap-exists provider "MEMORY.md"))
             (bootstrap-exists provider "memory.md"))
    "memory.md"))

;;; ---------------------------------------------------------------------------
;;; Workspace Boot — loads all files in canonical order
;;; ---------------------------------------------------------------------------

(declaim (ftype (function (workspace) boot-result) workspace-boot))
(defun workspace-boot (workspace)
  "Execute the workspace boot process.
   Loads all canonical bootstrap files in order, respecting:
   - Per-file limit: BOOTSTRAP_MAX_CHARS (20,000 chars)
   - Total limit: BOOTSTRAP_TOTAL_MAX_CHARS (24,000 chars)
   - Size guard: files > 2 MB are skipped

   Returns a boot-result struct with all loaded sections."
  (declare (type workspace workspace))
  (let ((provider (workspace-bootstrap-provider workspace))
        (sections '())
        (files-loaded '())
        (total-chars 0)
        (truncated-total-p nil))
    (when (null provider)
      (return-from workspace-boot
        (make-boot-result :fingerprint 0)))
    ;; Load each file in canonical order
    (dolist (filename *bootstrap-files*)
      ;; Handle MEMORY.md -> memory.md fallback
      (let ((actual-filename
              (if (string= filename "MEMORY.md")
                  (or (%try-memory-md-fallback provider) filename)
                  filename)))
        ;; Check total budget remaining
        (let ((remaining (- +bootstrap-total-max-chars+ total-chars)))
          (when (<= remaining 0)
            (setf truncated-total-p t)
            (return))
          ;; Load with per-file limit capped to remaining budget
          (let ((per-file-limit (min +bootstrap-max-chars+ remaining)))
            (multiple-value-bind (content file-truncated-p)
                (%load-bootstrap-file provider actual-filename per-file-limit)
              (when content
                (let ((char-count (length content)))
                  (push (cons actual-filename content) sections)
                  (push actual-filename files-loaded)
                  (incf total-chars char-count)
                  ;; Mark truncation if file was truncated
                  (when file-truncated-p
                    (let ((last-section (car sections)))
                      (setf (cdr last-section)
                            (concatenate 'string (cdr last-section)
                                         (format nil "~%~%[... truncated at ~D chars]"
                                                 per-file-limit))))))))))))
    ;; Compute fingerprint
    (let ((fp (bootstrap-fingerprint provider)))
      (make-boot-result
       :sections (nreverse sections)
       :total-chars total-chars
       :truncated-p truncated-total-p
       :fingerprint fp
       :files-loaded (nreverse files-loaded)))))

;;; ---------------------------------------------------------------------------
;;; Project Context Builder — assembles boot result into prompt section
;;; ---------------------------------------------------------------------------

(defparameter *workspace-preamble*
  "The following workspace files define your identity, behavior, and context.
They are maintained by the user and loaded automatically at session start.")

(defparameter *agents-md-guidance*
  "If present, follow its operational guidance including startup routines and red-line constraints unless higher-priority instructions override it.")

(defparameter *soul-md-guidance*
  "If present, embody its persona and tone. Avoid stiff, generic replies; follow its guidance unless higher-priority instructions override it.")

(defparameter *tools-md-guidance*
  "Does not control tool availability; it is user guidance for how to use external tools.")

(defun %guidance-for-file (filename)
  "Return the guidance string for a specific bootstrap file, or NIL."
  (declare (type string filename))
  (cond
    ((string= filename "AGENTS.md") *agents-md-guidance*)
    ((string= filename "SOUL.md") *soul-md-guidance*)
    ((string= filename "TOOLS.md") *tools-md-guidance*)
    (t nil)))

(declaim (ftype (function (boot-result &key (:workspace-dir (or null string)))
                          string)
                build-project-context))
(defun build-project-context (result &key workspace-dir)
  "Build the Project Context section of the system prompt from boot results.
   This is the first section injected into the prompt, containing all workspace
   identity files with preamble guidance.

   RESULT is the boot-result from workspace-boot.
   WORKSPACE-DIR is shown in file path annotations."
  (declare (type boot-result result))
  (if (null (boot-result-sections result))
      ""
      (with-output-to-string (s)
        ;; Preamble
        (format s "## Project Context~%~%~A~%~%" *workspace-preamble*)
        ;; Per-file guidance notes
        (dolist (section (boot-result-sections result))
          (let* ((filename (car section))
                 (content (cdr section))
                 (guidance (%guidance-for-file filename))
                 (display-path (if workspace-dir
                                   (format nil "~A/~A"
                                           (string-right-trim "/" workspace-dir)
                                           filename)
                                   filename)))
            ;; File header
            (format s "### ~A~%" display-path)
            ;; Guidance note if applicable
            (when guidance
              (format s "_~A_~%~%" guidance))
            ;; Content
            (format s "~%~A~%~%" content)))
        ;; Total truncation notice
        (when (boot-result-truncated-p result)
          (format s "~%[... project context truncated at ~D chars total -- use `read` for full files]~%"
                  +bootstrap-total-max-chars+)))))
