(in-package #:nilclaw/config)

(declaim (optimize (safety 3) (debug 3)))

;;; Validation error kinds
(defconstant +no-default-model+ :no-default-model)
(defconstant +legacy-default-provider-field+ :legacy-default-provider-field)
(defconstant +legacy-default-model-field+ :legacy-default-model-field)
(defconstant +invalid-default-model-primary+ :invalid-default-model-primary)
(defconstant +temperature-out-of-range+ :temperature-out-of-range)
(defconstant +invalid-port+ :invalid-port)
(defconstant +invalid-gateway-url+ :invalid-gateway-url)
(defconstant +invalid-gateway-token+ :invalid-gateway-token)
(defconstant +invalid-keepalive-interval-ms+ :invalid-keepalive-interval-ms)
(defconstant +invalid-reconnect-initial-backoff-ms+ :invalid-reconnect-initial-backoff-ms)
(defconstant +invalid-reconnect-max-backoff-ms+ :invalid-reconnect-max-backoff-ms)
(defconstant +invalid-retry-count+ :invalid-retry-count)
(defconstant +invalid-backoff-ms+ :invalid-backoff-ms)
(defconstant +invalid-http-proxy-url+ :invalid-http-proxy-url)
(defconstant +invalid-api-error-max-chars+ :invalid-api-error-max-chars)
(defconstant +invalid-http-search-base-url+ :invalid-http-search-base-url)
(defconstant +invalid-http-search-provider+ :invalid-http-search-provider)
(defconstant +invalid-http-search-fallback-provider+ :invalid-http-search-fallback-provider)
(defconstant +invalid-web-transport+ :invalid-web-transport)
(defconstant +invalid-web-path+ :invalid-web-path)
(defconstant +invalid-web-auth-token+ :invalid-web-auth-token)
(defconstant +invalid-web-message-auth-mode+ :invalid-web-message-auth-mode)
(defconstant +invalid-web-message-auth-transport+ :invalid-web-message-auth-transport)
(defconstant +invalid-web-origin+ :invalid-web-origin)
(defconstant +missing-web-relay-url+ :missing-web-relay-url)
(defconstant +invalid-web-relay-url+ :invalid-web-relay-url)
(defconstant +invalid-web-relay-agent-id+ :invalid-web-relay-agent-id)
(defconstant +invalid-web-relay-pairing-code-ttl+ :invalid-web-relay-pairing-code-ttl)
(defconstant +invalid-web-relay-ui-token-ttl+ :invalid-web-relay-ui-token-ttl)
(defconstant +invalid-web-relay-token-ttl+ :invalid-web-relay-token-ttl)

(defstruct validation-error
  "A config validation error."
  (kind nil :type keyword)
  (message "" :type string))

(defstruct config
  "Application configuration."
  ;; Global
  (default-provider "openrouter" :type string)
  (default-model nil :type (or null string))
  (default-temperature 0.7d0 :type double-float)
  (workspace-dir nil :type (or null string))
  (workspace-dir-override nil :type (or null string))
  (reasoning-effort nil :type (or null string))
  ;; Flags
  (legacy-default-provider-detected nil :type boolean)
  (legacy-default-model-detected nil :type boolean)
  (token-limit-explicit nil :type boolean)
  ;; Sub-configs as plists for simplicity
  (gateway (list :port 3000
                 :host "127.0.0.1"
                 :url nil
                 :token nil
                 :require-pairing t
                 :allow-public-bind nil
                 :keepalive-interval-ms 30000
                 :reconnect-initial-backoff-ms 500
                 :reconnect-max-backoff-ms 30000
                 :pair-rate-limit-per-minute 10
                 :webhook-rate-limit-per-minute 60
                 :idempotency-ttl-secs 300
                 :paired-tokens nil)
           :type list)
  (memory (list :profile "hybrid_keyword"
                :backend "hybrid"
                :instance-id ""
                :auto-save t
                :citations "auto")
          :type list)
  (heartbeat (list :enabled nil :interval-minutes 30) :type list)
  (autonomy (list :level "supervised"
                  :workspace-only t
                  :max-actions-per-hour 20
                  :require-approval-for-medium-risk t
                  :block-high-risk-commands t
                  :allowed-commands nil
                  :allow-raw-url-chars nil
                  :allowed-paths nil)
            :type list)
  (diagnostics (list :backend "none"
                     :log-tool-calls nil
                     :log-message-receipts nil
                     :log-message-payloads nil
                     :log-llm-io nil
                     :api-error-max-chars nil
                     :token-usage-ledger-enabled t
                     :token-usage-ledger-window-hours 24
                     :otel-endpoint nil
                     :otel-service-name nil)
               :type list)
  (reliability (list :provider-retries 2
                     :provider-backoff-ms 500
                     :fallback-providers nil
                     :api-keys nil
                     :model-fallbacks nil)
               :type list)
  (scheduler (list :enabled t :max-tasks 64 :max-concurrent 4 :agent-timeout-secs 0)
             :type list)
  (agent (list :compact-context nil
               :max-tool-iterations 1000
               :max-history-messages 100
               :parallel-tools nil
               :tool-dispatcher "auto"
               :token-limit 200000
               :status-show-emojis t
               :vision-disabled-models nil
               :auto-disable-vision-on-error t)
         :type list)
  (secrets (list :encrypt t) :type list)
  (identity (list :format "nilclaw" :aieos-path nil) :type list)
  (hardware (list :enabled nil :transport "none" :serial-port nil :baud-rate 115200) :type list)
  (security (list :sandbox-enabled nil :sandbox-backend "auto"
                  :max-memory-mb 512 :max-cpu-time-seconds 60
                  :audit-enabled t :audit-log-path "audit.log")
            :type list)
  (browser (list :enabled nil :backend "agent_browser" :native-headless t :allowed-domains nil) :type list)
  (http-request (list :enabled nil :search-base-url nil :search-provider "auto"
                      :search-fallback-providers nil :proxy nil :api-error-max-chars nil)
                :type list)
  (channels nil :type list)
  (providers nil :type list)
  (agents-list nil :type list)
  (bindings nil :type list)
  (mcp-servers nil :type list)
  (model-routes nil :type list)
  (session (list :dm-scope "per_channel_peer" :idle-minutes 60 :identity-links nil) :type list)
  (runtime (list :kind "native") :type list)
  (cost (list :enabled nil :daily-limit-usd 10.0d0 :monthly-limit-usd 100.0d0) :type list)
  (composio (list :enabled nil :api-key nil :entity-id "default") :type list)
  (tunnel (list :provider "none") :type list)
  ;; Auth profiles for OAuth providers (maps profile-id -> plist with :provider, :mode, :access-token)
  (auth-profiles nil :type list)
  (audio-media (list :enabled t :provider "groq" :model "whisper-large-v3"
                     :base-url nil :language nil)
               :type list))

(declaim (ftype (function () config) make-default-config))
(defun make-default-config ()
  "Construct a fresh config with secure defaults."
  (make-config))
