(in-package #:nilclaw/workspace)

(declaim (optimize (safety 3) (debug 3)))

;;; ---------------------------------------------------------------------------
;;; FNV-1a 64-bit fingerprinting for workspace change detection
;;; ---------------------------------------------------------------------------

(defconstant +fnv1a-64-offset-basis+ 14695981039346656037
  "FNV-1a 64-bit offset basis.")

(defconstant +fnv1a-64-prime+ 1099511628211
  "FNV-1a 64-bit prime.")

(defconstant +fnv1a-64-mask+ (1- (ash 1 64))
  "64-bit mask for wrapping arithmetic.")

(declaim (ftype (function ((simple-array (unsigned-byte 8) (*))
                           &optional (unsigned-byte 64))
                          (unsigned-byte 64))
                fnv1a-64))
(defun fnv1a-64 (octets &optional (hash +fnv1a-64-offset-basis+))
  "Compute FNV-1a 64-bit hash of OCTETS byte vector.
   Optionally continues from a previous HASH state."
  (declare (type (simple-array (unsigned-byte 8) (*)) octets)
           (type (unsigned-byte 64) hash))
  (loop for byte across octets
        do (setf hash (logand +fnv1a-64-mask+
                              (* (logxor hash byte)
                                 +fnv1a-64-prime+))))
  hash)

(declaim (ftype (function (string &optional (unsigned-byte 64))
                          (unsigned-byte 64))
                fnv1a-64-string))
(defun fnv1a-64-string (str &optional (hash +fnv1a-64-offset-basis+))
  "Compute FNV-1a 64-bit hash of STR (UTF-8 encoded)."
  (declare (type string str))
  (fnv1a-64 (babel:string-to-octets str :encoding :utf-8) hash))

(declaim (ftype (function (string) (unsigned-byte 64)) file-fingerprint))
(defun file-fingerprint (workspace-dir)
  "Compute a fingerprint over all tracked workspace bootstrap files.
   Uses FNV-1a 64-bit hash over file metadata (presence, mtime, size, path).
   WORKSPACE-DIR is the root workspace directory."
  (declare (type string workspace-dir))
  (let ((hash +fnv1a-64-offset-basis+)
        (ws-path (uiop:ensure-directory-pathname workspace-dir)))
    (dolist (filename *tracked-fingerprint-files*)
      ;; Hash the filename and separator
      (setf hash (fnv1a-64-string filename hash))
      (setf hash (fnv1a-64-string (string #\Newline) hash))
      (let ((candidate (merge-pathnames filename ws-path)))
        (if (probe-file candidate)
            (let ((truepath (truename candidate)))
              ;; File exists: hash present + canonical path + stats
              (setf hash (fnv1a-64-string "present" hash))
              (setf hash (fnv1a-64-string (namestring truepath) hash))
              ;; Hash file size
              (let ((size (ignore-errors
                            (with-open-file (s truepath :direction :input)
                              (file-length s)))))
                (when size
                  (setf hash (fnv1a-64-string (write-to-string size) hash))))
              ;; Hash file write date
              (let ((mtime (ignore-errors (file-write-date truepath))))
                (when mtime
                  (setf hash (fnv1a-64-string (write-to-string mtime) hash)))))
            ;; File missing
            (setf hash (fnv1a-64-string "missing" hash)))))
    hash))
