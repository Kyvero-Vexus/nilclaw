;;;; Provider runtime construction from config
;;;; Bridges nilclaw/config with nilclaw/provider

(in-package #:nilclaw/config)

(declaim (optimize (safety 3) (debug 3)))

;;; Provider runtime construction

(declaim (ftype (function (config string) list) get-provider-config))
(defun get-provider-config (cfg provider-name)
  "Get provider plist from config by name. Returns nil if not found."
  (declare (type config cfg)
           (type string provider-name))
  (let ((providers (config-providers cfg)))
    (find provider-name providers
          :key (lambda (p) (getf p :name))
          :test #'string=)))

(declaim (ftype (function (config string &key (:model (or null string))) (values t t))
                make-provider-runtime-from-config))
(defun make-provider-runtime-from-config (cfg provider-name &key (model nil model-p))
  "Create a provider-runtime struct from config for the named provider.
   Returns (values runtime found-p) where found-p indicates if the provider was in config.
   If not found, returns a default runtime with the provider name.
   
   NOTE: Requires nilclaw/provider system to be loaded. Returns (values nil nil)
   if provider module is not available."
  (declare (type config cfg)
           (type string provider-name))
  (let* ((pconfig (get-provider-config cfg provider-name))
         (api-key (when pconfig (getf pconfig :api-key)))
         (base-url (when pconfig (getf pconfig :base-url)))
         (native-tools (if pconfig (getf pconfig :native-tools) t))
         (reliability (config-reliability cfg))
         (max-retries (getf reliability :provider-retries 2)))
    ;; Late-bound symbol lookup - provider module may not be loaded yet
    (let ((runtime-sym (find-symbol "MAKE-PROVIDER-RUNTIME" :nilclaw/provider)))
      (if runtime-sym
          (values
           (funcall (symbol-function runtime-sym)
                    :name provider-name
                    :api-key api-key
                    :base-url base-url
                    :model (or model
                               (and model-p nil)
                               (format nil "~a/default" provider-name))
                    :max-retries max-retries)
           (not (null pconfig)))
          ;; Provider module not loaded - return nil
          (values nil nil)))))

;;; Provider lookup helpers

(declaim (ftype (function (config) list) list-configured-providers))
(defun list-configured-providers (cfg)
  "Return list of provider names configured in this config."
  (declare (type config cfg))
  (mapcar (lambda (p) (getf p :name)) (config-providers cfg)))

(declaim (ftype (function (config string) boolean) provider-configured-p))
(defun provider-configured-p (cfg provider-name)
  "Check if a provider is configured in this config."
  (declare (type config cfg)
           (type string provider-name))
  (not (null (get-provider-config cfg provider-name))))

;;; Default provider resolution

(declaim (ftype (function (config) (values string (or null string))) resolve-default-provider))
(defun resolve-default-provider (cfg)
  "Resolve the default provider and model from config.
   Returns (values provider-name model-name)."
  (declare (type config cfg))
  (let* ((default-provider (config-default-provider cfg))
         (default-model (config-default-model cfg)))
    (if default-model
        ;; If default-model is set, it may include provider prefix
        (multiple-value-bind (provider model)
            (parse-model-string default-model)
          (values (if (> (length provider) 0) provider default-provider)
                  model))
        ;; Just use default-provider
        (values default-provider nil))))
