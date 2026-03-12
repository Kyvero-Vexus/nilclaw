;;;; permissions.lisp - Channel permission checking
;;;; NilClaw - Statically typed Common Lisp agent harness

(in-package #:nilclaw/channel)

(declaim (optimize (speed 3) (safety 3) (debug 1)))

(declaim (ftype (function (dm-policy string list &key (:case-sensitive boolean))
                          (values boolean &optional))
                check-dm-permission))
(defun check-dm-permission (policy sender allowlist &key (case-sensitive nil))
  "Check if a DM sender is allowed by the policy."
  (declare (type dm-policy policy)
           (type string sender)
           (type list allowlist)
           (type boolean case-sensitive))
  (ecase policy
    (:allow t)
    (:deny nil)
    (:allowlist (if case-sensitive
                    (not (null (member sender allowlist :test #'string=)))
                    (not (null (member sender allowlist :test #'string-equal)))))))

(declaim (ftype (function (group-policy string list boolean &key (:case-sensitive boolean))
                          (values boolean &optional))
                check-group-permission))
(defun check-group-permission (policy sender allowlist is-mention
                               &key (case-sensitive nil))
  "Check if a group message sender is allowed by the policy."
  (declare (type group-policy policy)
           (type string sender)
           (type list allowlist)
           (type boolean is-mention case-sensitive))
  (ecase policy
    (:open t)
    (:mention-only is-mention)
    (:allowlist (if case-sensitive
                    (not (null (member sender allowlist :test #'string=)))
                    (not (null (member sender allowlist :test #'string-equal)))))))

(declaim (ftype (function (dm-policy group-policy string list boolean boolean
                           &key (:case-sensitive boolean))
                          (values boolean &optional))
                check-permission))
(defun check-permission (dm-policy group-policy sender allowlist
                         is-group is-mention &key (case-sensitive nil))
  "Check message permission based on DM/group policy."
  (declare (type dm-policy dm-policy)
           (type group-policy group-policy)
           (type string sender)
           (type list allowlist)
           (type boolean is-group is-mention case-sensitive))
  (if is-group
      (check-group-permission group-policy sender allowlist is-mention
                              :case-sensitive case-sensitive)
      (check-dm-permission dm-policy sender allowlist
                           :case-sensitive case-sensitive)))
