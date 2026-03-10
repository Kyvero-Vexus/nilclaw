(in-package #:nilclaw/provider)

(declaim (optimize (safety 3) (debug 3)))

(defstruct provider-runtime
  (name "openai" :type string)
  (integration-entrypoint "nilclaw/provider:complete" :type string)
  (enabled t :type boolean)
  (model "openai/gpt-4o-mini" :type string))

(declaim (ftype (function () provider-runtime) make-default-provider-runtime))
(defun make-default-provider-runtime ()
  (make-provider-runtime))

(declaim (ftype (function (&optional provider-runtime) boolean) provider-integration-ready-p))
(defun provider-integration-ready-p (&optional (runtime (make-default-provider-runtime)))
  (declare (type provider-runtime runtime))
  (and (provider-runtime-enabled runtime)
       (> (length (provider-runtime-name runtime)) 0)
       (> (length (provider-runtime-model runtime)) 0)
       (> (length (provider-runtime-integration-entrypoint runtime)) 0)))
