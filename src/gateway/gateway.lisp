(in-package #:nilclaw/gateway)

(declaim (optimize (safety 3) (debug 3)))

(defstruct gateway-runtime
  (name "nilclaw-gateway" :type string)
  (enabled t :type boolean)
  (port 3000 :type (integer 1 65535)))

(declaim (ftype (function () gateway-runtime) make-default-gateway-runtime))
(defun make-default-gateway-runtime ()
  (make-gateway-runtime))

(declaim (ftype (function (&optional gateway-runtime) boolean) gateway-runtime-ready-p))
(defun gateway-runtime-ready-p (&optional (runtime (make-default-gateway-runtime)))
  (declare (type gateway-runtime runtime))
  (and (gateway-runtime-enabled runtime)
       (> (length (gateway-runtime-name runtime)) 0)
       (<= 1 (gateway-runtime-port runtime) 65535)))
