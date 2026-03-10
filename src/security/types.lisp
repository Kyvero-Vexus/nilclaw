(in-package #:nilclaw/security)

(declaim (optimize (safety 3) (debug 3)))

(defconstant +autonomy-read-only+ :read-only)
(defconstant +autonomy-supervised+ :supervised)
(defconstant +autonomy-full+ :full)
(defconstant +autonomy-yolo+ :yolo)

(defconstant +risk-low+ :low)
(defconstant +risk-medium+ :medium)
(defconstant +risk-high+ :high)

(defstruct security-policy
  (autonomy +autonomy-supervised+ :type keyword)
  (workspace-only t :type boolean)
  (max-actions-per-hour 20 :type (integer 0 *))
  (require-approval-for-medium-risk t :type boolean)
  (block-high-risk-commands t :type boolean)
  (allow-raw-url-chars nil :type boolean)
  (allowed-commands nil :type list))

(defstruct rate-tracker
  (count 0 :type (integer 0 *))
  (limit 20 :type (integer 1 *)))
