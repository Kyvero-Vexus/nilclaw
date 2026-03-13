(in-package #:nilclaw/workspace)

(declaim (optimize (safety 3) (debug 3)))

;;; ---------------------------------------------------------------------------
;;; Bootstrap Provider Interface — abstract storage for workspace identity files
;;; ---------------------------------------------------------------------------

(defclass bootstrap-provider () ()
  (:documentation "Abstract base class for workspace bootstrap file providers.
Abstracts whether workspace identity files are stored on disk, in a database,
or nowhere (null provider)."))

(defgeneric bootstrap-load (provider filename)
  (:documentation "Load the full content of FILENAME. Returns content string or NIL."))

(defgeneric bootstrap-load-excerpt (provider filename max-bytes)
  (:documentation "Load at most MAX-BYTES of FILENAME. Returns content string or NIL."))

(defgeneric bootstrap-store (provider filename content)
  (:documentation "Write/overwrite FILENAME with CONTENT. Returns NIL."))

(defgeneric bootstrap-remove (provider filename)
  (:documentation "Delete FILENAME. Returns T if file was removed, NIL otherwise."))

(defgeneric bootstrap-exists (provider filename)
  (:documentation "Check if FILENAME exists. Returns T or NIL."))

(defgeneric bootstrap-list-files (provider)
  (:documentation "List all stored filenames. Returns a list of strings."))

(defgeneric bootstrap-fingerprint (provider)
  (:documentation "Compute a u64 change fingerprint. Returns an unsigned integer."))

;;; ---------------------------------------------------------------------------
;;; File Bootstrap Provider — reads/writes files directly in workspace
;;; ---------------------------------------------------------------------------

(defclass file-bootstrap-provider (bootstrap-provider)
  ((workspace-dir :initarg :workspace-dir
                  :accessor fbp-workspace-dir
                  :type string
                  :documentation "Root workspace directory for file storage."))
  (:documentation "Bootstrap provider that reads/writes files directly in the workspace.
Used when memory.backend is 'hybrid' or 'markdown'."))

(defun make-file-bootstrap-provider (&key workspace-dir)
  "Create a file-based bootstrap provider for WORKSPACE-DIR."
  (check-type workspace-dir string)
  (make-instance 'file-bootstrap-provider :workspace-dir workspace-dir))

(defmethod bootstrap-load ((provider file-bootstrap-provider) filename)
  (declare (type string filename))
  (multiple-value-bind (path status)
      (safe-workspace-path (fbp-workspace-dir provider) filename)
    (if (string= status "ok")
        (ignore-errors (uiop:read-file-string path))
        nil)))

(defmethod bootstrap-load-excerpt ((provider file-bootstrap-provider) filename max-bytes)
  (declare (type string filename)
           (type (integer 0 *) max-bytes))
  (multiple-value-bind (path status)
      (safe-workspace-path (fbp-workspace-dir provider) filename)
    (if (string= status "ok")
        (ignore-errors
          (with-open-file (s path :direction :input :external-format :utf-8)
            (let* ((len (min max-bytes (file-length s)))
                   (buf (make-string len)))
              (read-sequence buf s)
              buf)))
        nil)))

(defmethod bootstrap-store ((provider file-bootstrap-provider) filename content)
  (declare (type string filename content))
  (multiple-value-bind (valid-p reason)
      (validate-bootstrap-filename filename)
    (declare (ignore reason))
    (when valid-p
      (let* ((ws-path (uiop:ensure-directory-pathname (fbp-workspace-dir provider)))
             (target (merge-pathnames filename ws-path)))
        (ensure-directories-exist target)
        (with-open-file (s target :direction :output :if-exists :supersede
                                  :if-does-not-exist :create
                                  :external-format :utf-8)
          (write-string content s)))))
  nil)

(defmethod bootstrap-remove ((provider file-bootstrap-provider) filename)
  (declare (type string filename))
  (multiple-value-bind (path status)
      (safe-workspace-path (fbp-workspace-dir provider) filename)
    (if (string= status "ok")
        (ignore-errors (delete-file path) t)
        nil)))

(defmethod bootstrap-exists ((provider file-bootstrap-provider) filename)
  (declare (type string filename))
  (multiple-value-bind (path status)
      (safe-workspace-path (fbp-workspace-dir provider) filename)
    (declare (ignore path))
    (string= status "ok")))

(defmethod bootstrap-list-files ((provider file-bootstrap-provider))
  (let ((ws-path (uiop:ensure-directory-pathname (fbp-workspace-dir provider)))
        (result '()))
    (dolist (filename *bootstrap-files*)
      (when (probe-file (merge-pathnames filename ws-path))
        (push filename result)))
    ;; Also check memory.md (lowercase fallback)
    (when (probe-file (merge-pathnames "memory.md" ws-path))
      (push "memory.md" result))
    (nreverse result)))

(defmethod bootstrap-fingerprint ((provider file-bootstrap-provider))
  (file-fingerprint (fbp-workspace-dir provider)))

;;; ---------------------------------------------------------------------------
;;; Memory Bootstrap Provider — stores files as memory entries
;;; ---------------------------------------------------------------------------

(defclass memory-bootstrap-provider (bootstrap-provider)
  ((memory-backend :initarg :memory-backend
                   :accessor mbp-memory-backend
                   :documentation "Memory backend instance for storage."))
  (:documentation "Bootstrap provider that stores files as memory entries.
Used for database backends (sqlite, postgres, redis, etc.).
Files are stored with __bootstrap.prompt.* key convention."))

(defun make-memory-bootstrap-provider (&key memory-backend)
  "Create a memory-based bootstrap provider using MEMORY-BACKEND."
  (check-type memory-backend nilclaw/memory:memory-backend)
  (make-instance 'memory-bootstrap-provider :memory-backend memory-backend))

(defun %memory-key (filename)
  "Convert a bootstrap filename to a memory key."
  (declare (type string filename))
  (concatenate 'string *bootstrap-memory-key-prefix* filename))

(defun %strip-memory-header (content key)
  "Strip the markdown header that markdown-memory prepends to content.
   The markdown backend stores content as '# KEY\\n\\nCONTENT'."
  (declare (type string content key))
  (let ((prefix (format nil "# ~A~%~%" key)))
    (if (and (>= (length content) (length prefix))
             (string= prefix (subseq content 0 (length prefix))))
        (subseq content (length prefix))
        content)))

(defmethod bootstrap-load ((provider memory-bootstrap-provider) filename)
  (declare (type string filename))
  (let* ((mem-key (%memory-key filename))
         (entry (nilclaw/memory:memory-get
                 (mbp-memory-backend provider) mem-key)))
    (when entry
      (%strip-memory-header
       (nilclaw/memory:memory-entry-content entry) mem-key))))

(defmethod bootstrap-load-excerpt ((provider memory-bootstrap-provider) filename max-bytes)
  (declare (type string filename)
           (type (integer 0 *) max-bytes))
  (let ((content (bootstrap-load provider filename)))
    (when content
      (subseq content 0 (min max-bytes (length content))))))

(defmethod bootstrap-store ((provider memory-bootstrap-provider) filename content)
  (declare (type string filename content))
  (nilclaw/memory:memory-store
   (mbp-memory-backend provider)
   (%memory-key filename) content "bootstrap")
  nil)

(defmethod bootstrap-remove ((provider memory-bootstrap-provider) filename)
  (declare (type string filename))
  (nilclaw/memory:memory-forget
   (mbp-memory-backend provider)
   (%memory-key filename))
  t)

(defmethod bootstrap-exists ((provider memory-bootstrap-provider) filename)
  (declare (type string filename))
  (not (null (nilclaw/memory:memory-get
              (mbp-memory-backend provider)
              (%memory-key filename)))))

(defmethod bootstrap-list-files ((provider memory-bootstrap-provider))
  (let ((all-entries (nilclaw/memory:memory-list
                      (mbp-memory-backend provider) "bootstrap"))
        (prefix-len (length *bootstrap-memory-key-prefix*))
        (result '()))
    (dolist (entry all-entries)
      (let ((key (nilclaw/memory:memory-entry-key entry)))
        (when (and (> (length key) prefix-len)
                   (alexandria:starts-with-subseq *bootstrap-memory-key-prefix* key))
          (push (subseq key prefix-len) result))))
    (nreverse result)))

(defmethod bootstrap-fingerprint ((provider memory-bootstrap-provider))
  ;; Hash over stored entries' keys and content
  (let ((hash +fnv1a-64-offset-basis+))
    (dolist (filename *tracked-fingerprint-files*)
      (setf hash (fnv1a-64-string filename hash))
      (setf hash (fnv1a-64-string (string #\Newline) hash))
      (let ((content (bootstrap-load provider filename)))
        (if content
            (progn
              (setf hash (fnv1a-64-string "present" hash))
              (setf hash (fnv1a-64-string content hash)))
            (setf hash (fnv1a-64-string "missing" hash)))))
    hash))

;;; ---------------------------------------------------------------------------
;;; Null Bootstrap Provider — no-op for none/memory backends
;;; ---------------------------------------------------------------------------

(defclass null-bootstrap-provider (bootstrap-provider) ()
  (:documentation "No-op bootstrap provider.
Used when memory.backend is 'none' or 'memory'. All operations are no-ops."))

(defun make-null-bootstrap-provider ()
  "Create a null (no-op) bootstrap provider."
  (make-instance 'null-bootstrap-provider))

(defmethod bootstrap-load ((provider null-bootstrap-provider) filename)
  (declare (ignore provider filename)) nil)

(defmethod bootstrap-load-excerpt ((provider null-bootstrap-provider) filename max-bytes)
  (declare (ignore provider filename max-bytes)) nil)

(defmethod bootstrap-store ((provider null-bootstrap-provider) filename content)
  (declare (ignore provider filename content)) nil)

(defmethod bootstrap-remove ((provider null-bootstrap-provider) filename)
  (declare (ignore provider filename)) nil)

(defmethod bootstrap-exists ((provider null-bootstrap-provider) filename)
  (declare (ignore provider filename)) nil)

(defmethod bootstrap-list-files ((provider null-bootstrap-provider))
  (declare (ignore provider)) '())

(defmethod bootstrap-fingerprint ((provider null-bootstrap-provider))
  (declare (ignore provider)) 0)

;;; ---------------------------------------------------------------------------
;;; Provider Factory — selects implementation based on memory backend name
;;; ---------------------------------------------------------------------------

(declaim (ftype (function (&key (:memory-backend (or null nilclaw/memory:memory-backend))
                                (:workspace-dir (or null string)))
                          bootstrap-provider)
                make-bootstrap-provider))
(defun make-bootstrap-provider (&key memory-backend workspace-dir)
  "Create the appropriate bootstrap provider based on memory backend type.

   Selection logic:
   - hybrid/markdown  -> FileBootstrapProvider (requires workspace-dir)
   - none/memory      -> NullBootstrapProvider
   - All others       -> MemoryBootstrapProvider (requires memory-backend)"
  (let ((backend-name (if memory-backend
                          (nilclaw/memory:memory-name memory-backend)
                          "none")))
    (cond
      ;; File-based backends use workspace files
      ((member backend-name '("hybrid" "markdown") :test #'string=)
       (make-file-bootstrap-provider
        :workspace-dir (or workspace-dir ".")))
      ;; None/memory backends use null provider
      ((member backend-name '("none" "memory") :test #'string=)
       (make-null-bootstrap-provider))
      ;; Database backends use memory provider
      (t
       (make-memory-bootstrap-provider
        :memory-backend memory-backend)))))
