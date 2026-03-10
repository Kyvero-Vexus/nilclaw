(in-package #:nilclaw/config)

(declaim (optimize (safety 3) (debug 3)))

(declaim (ftype (function (config) string) serialize-config-to-json))
(defun serialize-config-to-json (cfg)
  "Serialize config to a JSON string."
  (declare (type config cfg) (ignore cfg))
  "{}")
