;;;; lisp-config.lisp — Native Common Lisp configuration reader
;;;; Configuration is pure s-expressions — no JSON, no YAML
;;;;
;;;; Example config (~/.nilclaw/init.lisp):
;;;;
;;;;   (nilclaw:configure
;;;;     :default-model "anthropic/claude-sonnet-4-20250514"
;;;;     :default-provider "openrouter"
;;;;     :default-temperature 0.7d0
;;;;     :gateway (:port 3000
;;;;               :host "127.0.0.1"
;;;;               :token "my-secret")
;;;;     :memory (:backend "hybrid"
;;;;              :auto-save t)
;;;;     :channels ((:type :cli :enabled t)
;;;;                (:type :web :enabled t
;;;;                 :path "/" :transport :relay)))

(in-package #:nilclaw/config)

(declaim (optimize (safety 3) (debug 3)))

;;; Config file path resolution

(defparameter *default-config-paths*
  '("~/.nilclaw/init.lisp"
    "~/.nilclaw/config.lisp"
    "~/.config/nilclaw/init.lisp")
  "Default paths to search for configuration files.")

(declaim (ftype (function ((or null string)) (or null pathname)) find-config-file))
(defun find-config-file (&optional explicit-path)
  "Find the configuration file. If EXPLICIT-PATH is given, use it.
   Otherwise search default paths."
  (declare (type (or null string) explicit-path))
  (if explicit-path
      (let ((p (probe-file (merge-pathnames (pathname explicit-path)))))
        (when p p))
      (loop for path-str in *default-config-paths*
            for expanded = (merge-pathnames (pathname path-str)
                                            (user-homedir-pathname))
            for probed = (probe-file expanded)
            when probed return probed)))

;;; S-expression config reader

(declaim (ftype (function (list) config) apply-config-plist))
(defun apply-config-plist (plist)
  "Apply a property list of configuration options to a fresh config.
   Returns a populated config struct."
  (declare (type list plist))
  (let ((cfg (make-default-config)))
    (loop for (key val) on plist by #'cddr
          do (case key
               (:default-provider
                (setf (config-default-provider cfg) (string val)))
               (:default-model
                (setf (config-default-model cfg) (string val)))
               (:default-temperature
                (setf (config-default-temperature cfg) (coerce val 'double-float)))
               (:workspace-dir
                (setf (config-workspace-dir cfg) (string val)))
               (:reasoning-effort
                (setf (config-reasoning-effort cfg) (string val)))
               ;; Sub-config plists — merge with defaults
               (:gateway
                (setf (config-gateway cfg) (merge-plist (config-gateway cfg) val)))
               (:memory
                (setf (config-memory cfg) (merge-plist (config-memory cfg) val)))
               (:heartbeat
                (setf (config-heartbeat cfg) (merge-plist (config-heartbeat cfg) val)))
               (:autonomy
                (setf (config-autonomy cfg) (merge-plist (config-autonomy cfg) val)))
               (:diagnostics
                (setf (config-diagnostics cfg) (merge-plist (config-diagnostics cfg) val)))
               (:reliability
                (setf (config-reliability cfg) (merge-plist (config-reliability cfg) val)))
               (:scheduler
                (setf (config-scheduler cfg) (merge-plist (config-scheduler cfg) val)))
               (:agent
                (setf (config-agent cfg) (merge-plist (config-agent cfg) val)))
               (:security
                (setf (config-security cfg) (merge-plist (config-security cfg) val)))
               (:browser
                (setf (config-browser cfg) (merge-plist (config-browser cfg) val)))
               (:http-request
                (setf (config-http-request cfg) (merge-plist (config-http-request cfg) val)))
               (:session
                (setf (config-session cfg) (merge-plist (config-session cfg) val)))
               (:cost
                (setf (config-cost cfg) (merge-plist (config-cost cfg) val)))
               ;; List-of-plists configs
               (:channels
                (setf (config-channels cfg) val))
               (:providers
                (setf (config-providers cfg) (append (config-providers cfg)
                                                      (normalize-providers val))))
               (:agents
                (setf (config-agents-list cfg) val))
               (:mcp-servers
                (setf (config-mcp-servers cfg) val))
               (:model-routes
                (setf (config-model-routes cfg) val))
               ;; Nested :MODELS (:PROVIDERS ...) structure from migrated configs
               (:models
                (let ((providers-plist (getf val :providers)))
                  (when providers-plist
                    (setf (config-providers cfg)
                          (append (config-providers cfg)
                                  (parse-nested-providers providers-plist))))))
               (otherwise
                (warn "Unknown config key: ~S" key))))
    cfg))

(declaim (ftype (function (list list) list) merge-plist))
(defun merge-plist (defaults overrides)
  "Merge OVERRIDES into DEFAULTS plist. Overrides win."
  (declare (type list defaults overrides))
  (let ((result (copy-list defaults)))
    (loop for (key val) on overrides by #'cddr
          do (setf (getf result key) val))
    result))

;;; Keyword case normalization for provider plists

(declaim (ftype (function (list) list) normalize-provider-plist))
(defun normalize-provider-plist (plist)
  "Normalize keyword case in a single provider plist.
   Converts all keyword symbols to uppercase for consistent lookup.
   This handles config files with mixed-case keywords."
  (declare (type list plist))
  (loop for (key val) on plist by #'cddr
        when (and key (keywordp key))
        collect (intern (symbol-name key) (find-package :keyword))
        and collect val))

(declaim (ftype (function (list) list) normalize-providers))
(defun normalize-providers (providers-list)
  "Normalize keyword case in a list of provider plists.
   Input: ((:name \"foo\" :api-key \"...\") ...)
   Output: ((:NAME \"foo\" :API-KEY \"...\") ...)"
  (declare (type list providers-list))
  (mapcar #'normalize-provider-plist providers-list))

;;; Nested providers parsing from migrated configs

(declaim (ftype (function (list) list) parse-nested-providers))
(defun parse-nested-providers (providers-plist)
  "Parse nested providers plist from migrated config.
   Input: (:LMSTUDIO (:BASE-URL \"...\" :API-KEY \"...\" :MODELS (...)) ...)
   Output: ((:name \"lmstudio\" :api-key \"...\" :base-url \"...\") ...)
   
   Handles both uppercase and lowercase keywords in input."
  (declare (type list providers-plist))
  (flet ((get-case-insensitive (plist key)
           "Get value from plist using case-insensitive keyword matching."
           (loop for (k v) on plist by #'cddr
                 when (and k (keywordp k)
                           (string= (string-downcase (symbol-name k))
                                    (string-downcase (symbol-name key))))
                 return v)))
    (loop for (provider-key provider-val) on providers-plist by #'cddr
          when (and provider-key (keywordp provider-key) provider-val)
          collect (list :name (string-downcase (symbol-name provider-key))
                        :api-key (get-case-insensitive provider-val :api-key)
                        :base-url (get-case-insensitive provider-val :base-url)
                        :native-tools (let ((v (get-case-insensitive provider-val :native-tools)))
                                        (if (or (null v) (eq v :unset)) t v))))))

;;; File-based config loading

(declaim (ftype (function (pathname) config) load-lisp-config))
(defun load-lisp-config (path)
  "Load configuration from a Common Lisp file.
   The file should contain a single plist form or a (nilclaw:configure ...) form."
  (declare (type pathname path))
  (let* ((contents (uiop:read-file-string path))
         (form (read-from-string contents)))
    (cond
      ;; Direct plist: (:default-model "..." ...)
      ((keywordp (car form))
       (apply-config-plist form))
      ;; (configure ...) or (nilclaw/config:configure ...)
      ((and (listp form)
            (member (string (car form)) '("CONFIGURE" "NILCLAW:CONFIGURE" "NILCLAW/CONFIG:CONFIGURE")
                    :test #'string-equal))
       (apply-config-plist (cdr form)))
      (t
       (error "Config file must contain a plist or (configure ...) form: ~A" path)))))

;;; Top-level config loading (tries Lisp first, falls back to JSON)

(declaim (ftype (function (&optional (or null string)) config) load-config))
(defun load-config (&optional explicit-path)
  "Load configuration from file. Searches default paths if no path given.
   Supports .lisp (native) and .json (legacy) formats."
  (declare (type (or null string) explicit-path))
  (let ((path (find-config-file explicit-path)))
    (unless path
      (return-from load-config (make-default-config)))
    (let ((ext (pathname-type path)))
      (cond
        ((member ext '("lisp" "cl" "sexp") :test #'string-equal)
         (load-lisp-config path))
        ((string-equal ext "json")
         ;; Fall back to JSON parser for migration period
         (parse-config-from-string (uiop:read-file-string path)))
        (t
         (error "Unknown config file type: ~A (expected .lisp or .json)" ext))))))

;;; Config serialization to s-expression

(declaim (ftype (function (config) string) config-to-sexp-string))
(defun config-to-sexp-string (cfg)
  "Serialize a config struct to a readable s-expression string."
  (declare (type config cfg))
  (with-output-to-string (s)
    (format s ";;; NilClaw Configuration~%")
    (format s ";;; Generated by NilClaw — edit freely~%~%")
    (format s "(configure~%")
    ;; Top-level scalars
    (when (config-default-model cfg)
      (format s "  :default-model ~S~%" (config-default-model cfg)))
    (format s "  :default-provider ~S~%" (config-default-provider cfg))
    (format s "  :default-temperature ~F~%" (config-default-temperature cfg))
    (when (config-workspace-dir cfg)
      (format s "  :workspace-dir ~S~%" (config-workspace-dir cfg)))
    (when (config-reasoning-effort cfg)
      (format s "  :reasoning-effort ~S~%" (config-reasoning-effort cfg)))
    ;; Sub-configs
    (flet ((emit-plist (key plist)
             (when plist
               (format s "  ~S (~{~S ~S~^~%~10T~})~%" key
                       (loop for (k v) on plist by #'cddr
                             collect k collect v)))))
      (emit-plist :gateway (config-gateway cfg))
      (emit-plist :memory (config-memory cfg))
      (emit-plist :heartbeat (config-heartbeat cfg))
      (emit-plist :security (config-security cfg))
      (emit-plist :agent (config-agent cfg))
      (emit-plist :scheduler (config-scheduler cfg))
      (emit-plist :reliability (config-reliability cfg)))
    ;; List configs
    (when (config-channels cfg)
      (format s "  :channels ~S~%" (config-channels cfg)))
    (when (config-providers cfg)
      (format s "  :providers ~S~%" (config-providers cfg)))
    (format s ")~%")))
