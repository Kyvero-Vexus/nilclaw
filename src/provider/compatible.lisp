(in-package #:nilclaw/provider)

(declaim (optimize (safety 3) (debug 3)))

(defstruct provider-runtime
  (name "openai" :type string)
  (integration-entrypoint "nilclaw/provider:complete" :type string)
  (enabled t :type boolean)
  (model "openai/gpt-4o-mini" :type string)
  (max-retries 2 :type (integer 0 10)))

(defstruct provider-request
  (model "" :type string)
  (messages nil :type list))

(defstruct provider-result
  (success-p nil :type boolean)
  (content nil :type (or null string))
  (attempts 0 :type (integer 0 *))
  (error-code nil :type (or null keyword)))

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

(declaim (ftype (function (provider-runtime provider-request function) provider-result) provider-complete))
(defun provider-complete (runtime request transport-fn)
  (declare (type provider-runtime runtime)
           (type provider-request request)
           (type function transport-fn))
  (let ((max-attempts (+ 1 (provider-runtime-max-retries runtime))))
    (labels ((attempt (index)
               (multiple-value-bind (content error-code)
                   (funcall transport-fn request index)
                 (cond
                   (content
                    (make-provider-result
                     :success-p t
                     :content content
                     :attempts index
                     :error-code nil))
                   ((and (< index max-attempts)
                         (member error-code '(:timeout :rate-limited :network-fault) :test #'eq))
                    (attempt (+ index 1)))
                   (t
                    (make-provider-result
                     :success-p nil
                     :content nil
                     :attempts index
                     :error-code (or error-code :provider-error)))))))
      (attempt 1))))