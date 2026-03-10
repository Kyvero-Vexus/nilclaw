(in-package #:nilclaw/security)

(declaim (optimize (safety 3) (debug 3)))

(defun autonomy-default () +autonomy-supervised+)

(defun autonomy-to-string (autonomy)
  (ecase autonomy
    (:full "full")
    (:read-only "readonly")
    (:supervised "supervised")
    (:yolo "yolo")))

(defun autonomy-from-string (s)
  (cond
    ((string= s "full") :full)
    ((string= s "supervised") :supervised)
    ((or (string= s "readonly") (string= s "read_only")) :read-only)
    ((string= s "yolo") :yolo)
    (t nil)))

(defun can-act (autonomy)
  (not (eq autonomy :read-only)))

(defun policy-autonomy (p) (security-policy-autonomy p))
(defun policy-allowed-commands (p) (security-policy-allowed-commands p))
(defun policy-require-approval-for-medium-risk (p)
  (security-policy-require-approval-for-medium-risk p))
(defun policy-block-high-risk-commands (p)
  (security-policy-block-high-risk-commands p))
(defun policy-allow-raw-url-chars (p)
  (security-policy-allow-raw-url-chars p))

(defun make-default-policy ()
  (make-security-policy
   :allowed-commands '("git" "npm" "cargo" "ls" "cat" "grep" "head" "tail" "wc" "echo" "find" "touch" "mkdir" "mv" "cp" "rm")))

(defun resolve-allowed-commands (autonomy configured)
  (cond
    ((and (eq autonomy :full) (or (null configured) (null (remove-if-not #'stringp configured)))) '("*"))
    ((or (null configured) (null (remove-if-not #'stringp configured)))
     (policy-allowed-commands (make-default-policy)))
    (t configured)))

(defun record-action (tracker autonomy)
  (cond
    ((eq autonomy :yolo) t)
    ((null tracker) t)
    ((< (rate-tracker-count tracker) (rate-tracker-limit tracker))
     (incf (rate-tracker-count tracker))
     t)
    (t nil)))

(defun is-rate-limited (tracker autonomy)
  (cond
    ((eq autonomy :yolo) nil)
    ((null tracker) nil)
    (t (>= (rate-tracker-count tracker) (rate-tracker-limit tracker)))))
