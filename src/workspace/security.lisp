(in-package #:nilclaw/workspace)

(declaim (optimize (safety 3) (debug 3)))

;;; ---------------------------------------------------------------------------
;;; Workspace file security — filename validation & path traversal protection
;;; ---------------------------------------------------------------------------

(declaim (ftype (function (string) (values boolean string)) validate-bootstrap-filename))
(defun validate-bootstrap-filename (filename)
  "Validate a bootstrap filename for safety.
   Returns (values valid-p reason).
   Rejects absolute paths, null bytes, and .. path components."
  (declare (type string filename))
  (cond
    ;; Empty filename
    ((zerop (length filename))
     (values nil "empty filename"))
    ;; Absolute path check
    ((char= (char filename 0) #\/)
     (values nil "absolute path not allowed"))
    ;; Null bytes
    ((position #\Nul filename)
     (values nil "null bytes not allowed"))
    ;; Path traversal via ..
    ((or (string= filename "..")
         (search "/../" (concatenate 'string "/" filename "/"))
         (alexandria:starts-with-subseq "../" filename)
         (alexandria:ends-with-subseq "/.." filename))
     (values nil "path traversal not allowed"))
    ;; Valid
    (t (values t "ok"))))

(declaim (ftype (function (string string) (values (or null string) string))
                safe-workspace-path))
(defun safe-workspace-path (workspace-dir filename)
  "Resolve FILENAME within WORKSPACE-DIR with security guards.
   Returns (values resolved-path status) where status is one of:
   \"ok\", \"invalid-filename\", \"outside-workspace\", \"too-large\", \"not-found\".
   resolved-path is nil when status is not \"ok\"."
  (declare (type string workspace-dir filename))
  ;; Validate filename first
  (multiple-value-bind (valid-p reason) (validate-bootstrap-filename filename)
    (declare (ignore reason))
    (unless valid-p
      (return-from safe-workspace-path (values nil "invalid-filename"))))
  ;; Build the candidate path
  (let* ((ws-path (uiop:ensure-directory-pathname workspace-dir))
         (candidate (merge-pathnames filename ws-path)))
    ;; Check existence
    (unless (probe-file candidate)
      (return-from safe-workspace-path (values nil "not-found")))
    ;; Resolve canonical paths (follows symlinks)
    (let ((canonical-candidate (truename candidate))
          (canonical-workspace (truename ws-path)))
      ;; Path traversal check: canonical path must be under workspace
      (let ((ws-str (namestring canonical-workspace))
            (cand-str (namestring canonical-candidate)))
        (unless (alexandria:starts-with-subseq ws-str cand-str)
          (return-from safe-workspace-path (values nil "outside-workspace"))))
      ;; Size guard: files larger than 2 MB are treated as not found
      (let ((size (ignore-errors
                    (with-open-file (s canonical-candidate :direction :input)
                      (file-length s)))))
        (when (and size (> size +max-workspace-bootstrap-file-bytes+))
          (return-from safe-workspace-path (values nil "too-large"))))
      ;; All checks passed
      (values (namestring canonical-candidate) "ok"))))
