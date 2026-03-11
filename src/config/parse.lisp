(in-package #:nilclaw/config)

(declaim (optimize (safety 3) (debug 3)))

(defun json-getf (alist key &optional default)
  "Get value from cl-json decoded alist by keyword key."
  (declare (type (or null list) alist))
  (let ((pair (assoc key alist)))
    (if pair (cdr pair) default)))

(defun json-getf-nested (alist &rest keys)
  "Navigate nested alists by keys."
  (let ((current alist))
    (dolist (key keys current)
      (if (and current (listp current))
          (setf current (json-getf current key))
          (return nil)))))

(declaim (ftype (function (string) (values string string)) parse-model-string))
(defun parse-model-string (model-string)
  "Parse 'provider/model' string into (values provider model).
   Handles custom:url/model format."
  (declare (type string model-string))
  ;; Check for custom: prefix with versioned path
  (when (and (>= (length model-string) 7)
             (string= "custom:" (subseq model-string 0 7)))
    ;; Split on versioned API path segment
    (let ((pos nil))
      (dolist (seg '("/v1/" "/v2/" "/v3/" "/v4/"))
        (let ((found (search seg model-string)))
          (when found
            (setf pos (+ found (length seg)))
            (return))))
      (when pos
        (return-from parse-model-string
          (values (subseq model-string 0 (- pos 1))
                  (subseq model-string pos))))))
  ;; Standard provider/model split
  (let ((slash-pos (position #\/ model-string)))
    (if slash-pos
        (values (subseq model-string 0 slash-pos)
                (subseq model-string (1+ slash-pos)))
        (values "" model-string))))

(declaim (ftype (function (string) (values boolean (unsigned-byte 32))) parse-duration-string))
(defun parse-duration-string (duration-str)
  "Parse duration string like '30m' or '2h' into (values enabled minutes)."
  (declare (type string duration-str))
  (let ((len (length duration-str)))
    (when (> len 1)
      (let* ((unit (char duration-str (1- len)))
             (num-str (subseq duration-str 0 (1- len)))
             (num (ignore-errors (parse-integer num-str))))
        (when num
          (case unit
            (#\m (return-from parse-duration-string (values t num)))
            (#\h (return-from parse-duration-string (values t (* num 60))))))))
    (values nil 0)))

(defvar *valid-reasoning-efforts*
  '("high" "medium" "low" "minimal" "xhigh")
  "Valid reasoning effort values.")

(defun parse-config-from-string (json-string)
  "Parse a JSON configuration string into a config struct."
  (declare (type string json-string))
  (let ((data (handler-case
                  (cl-json:decode-json-from-string json-string)
                (error () nil))))
    (if data
        (parse-config-from-json data)
        (make-default-config))))

(defun parse-config-from-json (data)
  "Parse cl-json decoded alist into a config struct."
  (let ((cfg (make-default-config)))
    ;; Temperature
    (let ((temp (json-getf data :default--temperature)))
      (when temp
        (setf (config-default-temperature cfg)
              (coerce (if (integerp temp) (float temp 1.0d0) temp) 'double-float))))
    ;; Workspace override
    (let ((ws (json-getf data :workspace)))
      (when ws
        (setf (config-workspace-dir-override cfg) ws)))
    ;; Reasoning effort
    (let ((re (json-getf data :reasoning--effort)))
      (when re
        (if (member re *valid-reasoning-efforts* :test #'string=)
            (setf (config-reasoning-effort cfg) re)
            (setf (config-reasoning-effort cfg) nil))))
    ;; Legacy default_provider
    (let ((dp (json-getf data :default--provider)))
      (when dp
        (setf (config-default-provider cfg) dp)
        (setf (config-legacy-default-provider-detected cfg) t)))
    ;; Legacy default_model
    (let ((dm (json-getf data :default--model)))
      (when dm
        (setf (config-legacy-default-model-detected cfg) t)))
    ;; Parse agents.defaults.model.primary
    (let* ((agents-data (json-getf data :agents))
           (defaults (json-getf agents-data :defaults))
           (model-cfg (json-getf defaults :model))
           (primary (json-getf model-cfg :primary)))
      (when primary
        (multiple-value-bind (provider model)
            (parse-model-string primary)
          (when (or (> (length provider) 0)
                    (not (config-legacy-default-provider-detected cfg)))
            (setf (config-default-provider cfg) provider))
          (setf (config-default-model cfg) model))))
    ;; Gateway
    (let ((gw (json-getf data :gateway)))
      (when gw
        (let ((current (config-gateway cfg)))
          (let ((port (json-getf gw :port)))
            (when port (setf (getf current :port) port)))
          (let ((host (json-getf gw :host)))
            (when host (setf (getf current :host) host)))
          (let ((url (json-getf gw :url)))
            (when url (setf (getf current :url) url)))
          (let ((token (json-getf gw :token)))
            (when token (setf (getf current :token) token)))
          (let ((rp (json-getf gw :require--pairing)))
            (when (not (null rp)) (setf (getf current :require-pairing) rp)))
          (let ((apb (json-getf gw :allow--public--bind)))
            (when (not (null apb)) (setf (getf current :allow-public-bind) apb)))
          (let ((keepalive (json-getf gw :keepalive--interval--ms)))
            (when keepalive (setf (getf current :keepalive-interval-ms) keepalive)))
          (let ((reconnect-initial (json-getf gw :reconnect--initial--backoff--ms)))
            (when reconnect-initial (setf (getf current :reconnect-initial-backoff-ms) reconnect-initial)))
          (let ((reconnect-max (json-getf gw :reconnect--max--backoff--ms)))
            (when reconnect-max (setf (getf current :reconnect-max-backoff-ms) reconnect-max)))
          (let ((tokens (json-getf gw :paired--tokens)))
            (when tokens (setf (getf current :paired-tokens) tokens)))
          (setf (config-gateway cfg) current))))
    ;; Reliability
    (let ((rel (json-getf data :reliability)))
      (when rel
        (let ((current (config-reliability cfg)))
          (let ((retries (json-getf rel :provider--retries)))
            (when retries (setf (getf current :provider-retries) retries)))
          (let ((backoff (json-getf rel :provider--backoff--ms)))
            (when backoff (setf (getf current :provider-backoff-ms) backoff)))
          (let ((fb (json-getf rel :fallback--providers)))
            (when fb (setf (getf current :fallback-providers) fb)))
          (let ((keys (json-getf rel :api--keys)))
            (when keys (setf (getf current :api-keys) keys)))
          (let ((mf (json-getf rel :model--fallbacks)))
            (when mf (setf (getf current :model-fallbacks) mf)))
          (setf (config-reliability cfg) current))))
    ;; Heartbeat
    (let ((hb (json-getf data :heartbeat)))
      (when hb
        (let ((current (config-heartbeat cfg)))
          (let ((enabled (json-getf hb :enabled)))
            (when (not (null enabled))
              (setf (getf current :enabled) enabled)))
          (let ((every-str (json-getf hb :every)))
            (when every-str
              (multiple-value-bind (e minutes)
                  (parse-duration-string every-str)
                (declare (ignore e))
                (when (> minutes 0)
                  (setf (getf current :enabled)
                        (if (eq (json-getf hb :enabled) nil)
                            (getf current :enabled)
                            t))
                  (setf (getf current :interval-minutes) minutes)))))
          (setf (config-heartbeat cfg) current))))
    ;; Secrets
    (let ((sec (json-getf data :secrets)))
      (when sec
        (let ((current (config-secrets cfg)))
          (let ((enc (json-getf sec :encrypt)))
            (when (not (null enc)) (setf (getf current :encrypt) enc)))
          (setf (config-secrets cfg) current))))
    ;; Diagnostics
    (let ((diag (json-getf data :diagnostics)))
      (when diag
        (let ((current (config-diagnostics cfg)))
          (let ((v (json-getf diag :api--error--max--chars)))
            (when v (setf (getf current :api-error-max-chars) v)))
          (let ((v (json-getf diag :log--tool--calls)))
            (when (not (null v)) (setf (getf current :log-tool-calls) v)))
          (let ((v (json-getf diag :log--message--receipts)))
            (when (not (null v)) (setf (getf current :log-message-receipts) v)))
          (let ((v (json-getf diag :log--message--payloads)))
            (when (not (null v)) (setf (getf current :log-message-payloads) v)))
          (let ((v (json-getf diag :log--llm--io)))
            (when (not (null v)) (setf (getf current :log-llm-io) v)))
          (setf (config-diagnostics cfg) current))))
    ;; Scheduler
    (let ((sched (json-getf data :scheduler)))
      (when sched
        (let ((current (config-scheduler cfg)))
          (let ((v (json-getf sched :enabled)))
            (when (not (null v)) (setf (getf current :enabled) v)))
          (let ((v (json-getf sched :max--tasks)))
            (when v (setf (getf current :max-tasks) v)))
          (let ((v (json-getf sched :max--concurrent)))
            (when v (setf (getf current :max-concurrent) v)))
          (let ((v (json-getf sched :agent--timeout--secs)))
            (when v (setf (getf current :agent-timeout-secs) v)))
          (setf (config-scheduler cfg) current))))
    ;; Agent
    (let ((ag (json-getf data :agent)))
      (when ag
        (let ((current (config-agent cfg)))
          (let ((v (json-getf ag :compact--context)))
            (when (not (null v)) (setf (getf current :compact-context) v)))
          (let ((v (json-getf ag :max--tool--iterations)))
            (when v (setf (getf current :max-tool-iterations) v)))
          (let ((v (json-getf ag :max--history--messages)))
            (when v (setf (getf current :max-history-messages) v)))
          (let ((v (json-getf ag :token--limit)))
            (when v
              (setf (getf current :token-limit) v)
              (setf (config-token-limit-explicit cfg) t)))
          (let ((v (json-getf ag :vision--disabled--models)))
            (when v (setf (getf current :vision-disabled-models) v)))
          (let ((v (json-getf ag :status--show--emojis)))
            (when (not (null v)) (setf (getf current :status-show-emojis) v)))
          (setf (config-agent cfg) current))))
    ;; Security
    (let ((sec-data (json-getf data :security)))
      (when sec-data
        (let ((current (config-security cfg)))
          (let ((sb (json-getf sec-data :sandbox)))
            (when sb
              (let ((v (json-getf sb :enabled)))
                (when (not (null v)) (setf (getf current :sandbox-enabled) v)))
              (let ((v (json-getf sb :backend)))
                (when v (setf (getf current :sandbox-backend) v)))))
          (let ((res (json-getf sec-data :resources)))
            (when res
              (let ((v (json-getf res :max--memory--mb)))
                (when v (setf (getf current :max-memory-mb) v)))
              (let ((v (json-getf res :max--cpu--time--seconds)))
                (when v (setf (getf current :max-cpu-time-seconds) v)))))
          (let ((aud (json-getf sec-data :audit)))
            (when aud
              (let ((v (json-getf aud :enabled)))
                (when (not (null v)) (setf (getf current :audit-enabled) v)))
              (let ((v (json-getf aud :log--path)))
                (when v (setf (getf current :audit-log-path) v)))))
          (setf (config-security cfg) current))))
    ;; HTTP Request
    (let ((hr (json-getf data :http--request)))
      (when hr
        (let ((current (config-http-request cfg)))
          (let ((v (json-getf hr :enabled)))
            (when (not (null v)) (setf (getf current :enabled) v)))
          (let ((v (json-getf hr :search--base--url)))
            (when v (setf (getf current :search-base-url) v)))
          (let ((v (json-getf hr :search--provider)))
            (when v (setf (getf current :search-provider) v)))
          (let ((v (json-getf hr :proxy)))
            (when v (setf (getf current :proxy) v)))
          (setf (config-http-request cfg) current))))
    ;; Autonomy
    (let ((auto-data (json-getf data :autonomy)))
      (when auto-data
        (let ((current (config-autonomy cfg)))
          (let ((v (json-getf auto-data :allowed--commands)))
            (when v (setf (getf current :allowed-commands) v)))
          (let ((v (json-getf auto-data :allowed--paths)))
            (when v (setf (getf current :allowed-paths) v)))
          (let ((v (json-getf auto-data :allow--raw--url--chars)))
            (when (not (null v)) (setf (getf current :allow-raw-url-chars) v)))
          (setf (config-autonomy cfg) current))))
    ;; Composio
    (let ((comp (json-getf data :composio)))
      (when comp
        (let ((current (config-composio cfg)))
          (let ((v (json-getf comp :enabled)))
            (when (not (null v)) (setf (getf current :enabled) v)))
          (let ((v (json-getf comp :api--key)))
            (when v (setf (getf current :api-key) v)))
          (let ((v (json-getf comp :entity--id)))
            (when v (setf (getf current :entity-id) v)))
          (setf (config-composio cfg) current))))
    ;; Identity
    (let ((id-data (json-getf data :identity)))
      (when id-data
        (let ((current (config-identity cfg)))
          (let ((v (json-getf id-data :format)))
            (when v (setf (getf current :format) v)))
          (let ((v (json-getf id-data :aieos--path)))
            (when v (setf (getf current :aieos-path) v)))
          (setf (config-identity cfg) current))))
    ;; Hardware
    (let ((hw (json-getf data :hardware)))
      (when hw
        (let ((current (config-hardware cfg)))
          (let ((v (json-getf hw :enabled)))
            (when (not (null v)) (setf (getf current :enabled) v)))
          (let ((v (json-getf hw :transport)))
            (when v (setf (getf current :transport) v)))
          (let ((v (json-getf hw :serial--port)))
            (when v (setf (getf current :serial-port) v)))
          (let ((v (json-getf hw :baud--rate)))
            (when v (setf (getf current :baud-rate) v)))
          (setf (config-hardware cfg) current))))
    ;; Browser
    (let ((br (json-getf data :browser)))
      (when br
        (let ((current (config-browser cfg)))
          (let ((v (json-getf br :enabled)))
            (when (not (null v)) (setf (getf current :enabled) v)))
          (let ((v (json-getf br :backend)))
            (when v (setf (getf current :backend) v)))
          (let ((v (json-getf br :native--headless)))
            (when (not (null v)) (setf (getf current :native-headless) v)))
          (let ((v (json-getf br :allowed--domains)))
            (when v (setf (getf current :allowed-domains) v)))
          (setf (config-browser cfg) current))))
    ;; Providers
    (let ((models-data (json-getf data :models)))
      (when models-data
        (let ((providers-data (json-getf models-data :providers)))
          (when providers-data
            (setf (config-providers cfg)
                  (loop for (name . pdata) in providers-data
                        collect (list :name (string-downcase (symbol-name name))
                                      :api-key (let ((k (json-getf pdata :api--key)))
                                                 (if (and k (listp k))
                                                     (cl-json:encode-json-to-string k)
                                                     k))
                                      :base-url (json-getf pdata :base--url)
                                      :native-tools (let ((v (json-getf pdata :native--tools :unset)))
                                                      (if (eq v :unset) t v)))))))))
    ;; MCP servers
    (let ((mcp (json-getf data :mcp--servers)))
      (when mcp
        (setf (config-mcp-servers cfg)
              (loop for (name . sdata) in mcp
                    collect (list :name (string-downcase (symbol-name name))
                                  :command (json-getf sdata :command)
                                  :args (json-getf sdata :args)
                                  :env (json-getf sdata :env))))))
    ;; Session
    (let ((sess (json-getf data :session)))
      (when sess
        (let ((current (config-session cfg)))
          (let ((v (json-getf sess :dm--scope)))
            (when v
              (setf (getf current :dm-scope)
                    (cl-ppcre:regex-replace-all "-" v "_"))))
          (let ((v (json-getf sess :idle--minutes)))
            (when v (setf (getf current :idle-minutes) v)))
          (setf (config-session cfg) current))))
    cfg))

(declaim (ftype (function (config) config) apply-env-overrides))
(defun apply-env-overrides (cfg)
  "Apply NILCLAW_* environment variable overrides to config."
  (declare (type config cfg))
  (let ((provider (uiop:getenv "NILCLAW_PROVIDER")))
    (when provider
      (setf (config-default-provider cfg) provider)))
  (let ((model (uiop:getenv "NILCLAW_MODEL")))
    (when model
      (setf (config-default-model cfg) model)))
  (let ((temp-str (uiop:getenv "NILCLAW_TEMPERATURE")))
    (when temp-str
      (let ((temp (ignore-errors (read-from-string temp-str))))
        (when (numberp temp)
          (setf (config-default-temperature cfg) (coerce temp 'double-float))))))
  (let ((port-str (uiop:getenv "NILCLAW_GATEWAY_PORT")))
    (when port-str
      (let ((port (ignore-errors (parse-integer port-str))))
        (when port
          (let ((gw (config-gateway cfg)))
            (setf (getf gw :port) port)
            (setf (config-gateway cfg) gw))))))
  (let ((host (uiop:getenv "NILCLAW_GATEWAY_HOST")))
    (when host
      (let ((gw (config-gateway cfg)))
        (setf (getf gw :host) host)
        (setf (config-gateway cfg) gw))))
  (let ((url (uiop:getenv "NILCLAW_GATEWAY_URL")))
    (when url
      (let ((gw (config-gateway cfg)))
        (setf (getf gw :url) url)
        (setf (config-gateway cfg) gw))))
  (let ((token (uiop:getenv "NILCLAW_GATEWAY_TOKEN")))
    (when token
      (let ((gw (config-gateway cfg)))
        (setf (getf gw :token) token)
        (setf (config-gateway cfg) gw))))
  (let ((keepalive-str (uiop:getenv "NILCLAW_GATEWAY_KEEPALIVE_INTERVAL_MS")))
    (when keepalive-str
      (let ((keepalive (ignore-errors (parse-integer keepalive-str))))
        (when keepalive
          (let ((gw (config-gateway cfg)))
            (setf (getf gw :keepalive-interval-ms) keepalive)
            (setf (config-gateway cfg) gw))))))
  (let ((reconnect-initial-str (uiop:getenv "NILCLAW_GATEWAY_RECONNECT_INITIAL_BACKOFF_MS")))
    (when reconnect-initial-str
      (let ((backoff (ignore-errors (parse-integer reconnect-initial-str))))
        (when backoff
          (let ((gw (config-gateway cfg)))
            (setf (getf gw :reconnect-initial-backoff-ms) backoff)
            (setf (config-gateway cfg) gw))))))
  (let ((reconnect-max-str (uiop:getenv "NILCLAW_GATEWAY_RECONNECT_MAX_BACKOFF_MS")))
    (when reconnect-max-str
      (let ((backoff (ignore-errors (parse-integer reconnect-max-str))))
        (when backoff
          (let ((gw (config-gateway cfg)))
            (setf (getf gw :reconnect-max-backoff-ms) backoff)
            (setf (config-gateway cfg) gw))))))
  (let ((ws (uiop:getenv "NILCLAW_WORKSPACE")))
    (when ws
      (setf (config-workspace-dir cfg) ws)))
  (let ((apb (uiop:getenv "NILCLAW_ALLOW_PUBLIC_BIND")))
    (when apb
      (let ((gw (config-gateway cfg)))
        (setf (getf gw :allow-public-bind)
              (or (string= apb "1") (string-equal apb "true")))
        (setf (config-gateway cfg) gw))))
  cfg)

(declaim (ftype (function (config) config) sync-flat-fields))
(defun sync-flat-fields (cfg)
  "Synchronize nested config fields to flat convenience fields."
  (declare (type config cfg))
  ;; Nothing to do currently — flat fields are directly accessed
  cfg)
