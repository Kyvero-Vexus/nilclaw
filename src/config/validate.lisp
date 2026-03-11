(in-package #:nilclaw/config)

(declaim (optimize (safety 3) (debug 3)))

(declaim (ftype (function (config) list) validate-config))
(defun validate-config (cfg)
  "Validate configuration struct and return list of validation-error structs."
  (declare (type config cfg))
  (let ((errors nil))
    
    (when (config-legacy-default-model-detected cfg)
      (push (make-validation-error :kind +legacy-default-model-field+
                                   :message "Legacy default_model field used")
            errors))
            
    (when (config-legacy-default-provider-detected cfg)
      (push (make-validation-error :kind +legacy-default-provider-field+
                                   :message "Legacy default_provider field used")
            errors))
            
    (unless (config-default-model cfg)
      (push (make-validation-error :kind +no-default-model+
                                   :message "No default_model configured")
            errors))
            
    (when (and (config-default-provider cfg)
               (= 0 (length (config-default-provider cfg))))
      (push (make-validation-error :kind +invalid-default-model-primary+
                                   :message "Provider prefix missing or empty")
            errors))
            
    (let ((temp (config-default-temperature cfg)))
      (when (or (< temp 0.0d0) (> temp 2.0d0))
        (push (make-validation-error :kind +temperature-out-of-range+
                                     :message "Temperature must be between 0.0 and 2.0")
              errors)))
              
    (let ((gw (config-gateway cfg)))
      (when (zerop (getf gw :port 0))
        (push (make-validation-error :kind +invalid-port+
                                     :message "Gateway port cannot be 0")
              errors))
      (let ((url (getf gw :url)))
        (when (and url
                   (not (or (cl-ppcre:scan "^wss?://" url)
                            (cl-ppcre:scan "^https?://" url))))
          (push (make-validation-error :kind +invalid-gateway-url+
                                       :message "Gateway URL must use ws(s) or http(s) scheme")
                errors)))
      (let ((token (getf gw :token)))
        (when (and token (find #\Space token))
          (push (make-validation-error :kind +invalid-gateway-token+
                                       :message "Gateway token cannot contain spaces")
                errors)))
      (let ((keepalive (getf gw :keepalive-interval-ms)))
        (when (and keepalive (<= keepalive 0))
          (push (make-validation-error :kind +invalid-keepalive-interval-ms+
                                       :message "Gateway keepalive interval must be > 0")
                errors)))
      (let ((reconnect-initial (getf gw :reconnect-initial-backoff-ms)))
        (when (and reconnect-initial (< reconnect-initial 0))
          (push (make-validation-error :kind +invalid-reconnect-initial-backoff-ms+
                                       :message "Gateway reconnect initial backoff must be >= 0")
                errors)))
      (let ((reconnect-max (getf gw :reconnect-max-backoff-ms)))
        (when (and reconnect-max (< reconnect-max 0))
          (push (make-validation-error :kind +invalid-reconnect-max-backoff-ms+
                                       :message "Gateway reconnect max backoff must be >= 0")
                errors)))
      (let ((reconnect-initial (getf gw :reconnect-initial-backoff-ms))
            (reconnect-max (getf gw :reconnect-max-backoff-ms)))
        (when (and reconnect-initial reconnect-max (> reconnect-initial reconnect-max))
          (push (make-validation-error :kind +invalid-reconnect-max-backoff-ms+
                                       :message "Gateway reconnect max backoff must be >= initial backoff")
                errors))))
              
    (let ((rel (config-reliability cfg)))
      (let ((retries (getf rel :provider-retries)))
        (when (and retries (> retries 100))
          (push (make-validation-error :kind +invalid-retry-count+
                                       :message "Provider retries too high")
                errors)))
      (let ((backoff (getf rel :provider-backoff-ms)))
        (when (and backoff (> backoff 600000))
          (push (make-validation-error :kind +invalid-backoff-ms+
                                       :message "Provider backoff > 600,000 ms")
                errors))))
                
    ;; HTTP Request validation
    (let ((hr (config-http-request cfg)))
      (let ((sbu (getf hr :search-base-url)))
        (when (and sbu (find #\? sbu))
          (push (make-validation-error :kind +invalid-http-search-base-url+
                                       :message "Search base URL cannot contain query string")
                errors)))
      (let ((sp (getf hr :search-provider)))
        (when (and sp (string= sp "google"))
          (push (make-validation-error :kind +invalid-http-search-provider+
                                       :message "Unknown search provider")
                errors)))
      (let ((fps (getf hr :search-fallback-providers)))
        (when (and fps (member "auto" fps :test #'string=))
          (push (make-validation-error :kind +invalid-http-search-fallback-provider+
                                       :message "Fallback providers cannot be auto")
                errors)))
      (let ((pxy (getf hr :proxy)))
        (when (and pxy (> (length pxy) 4) (string= (subseq pxy 0 4) "ftp:"))
          (push (make-validation-error :kind +invalid-http-proxy-url+
                                       :message "Proxy cannot use FTP scheme")
                errors))))
                
    (let ((diag (config-diagnostics cfg)))
      (let ((amc (getf diag :api-error-max-chars)))
        (when (and amc (< amc 200))
          (push (make-validation-error :kind +invalid-api-error-max-chars+
                                       :message "API error max chars too short")
                errors))))
                
    (let ((chans (config-channels cfg)))
      (let ((web (json-getf chans :web)))
        (let ((accounts (json-getf web :accounts)))
          (loop for (acct-name . acct-data) in accounts do
            (let ((path (json-getf acct-data :path)))
              (when (and path (not (char= #\/ (char path 0))))
                (push (make-validation-error :kind +invalid-web-path+ :message "Web path must start with /") errors)))
            (let ((token (json-getf acct-data :auth--token)))
              (when (and token (find #\Space token))
                (push (make-validation-error :kind +invalid-web-auth-token+ :message "Auth token cannot contain spaces") errors)))
            (let ((origins (json-getf acct-data :allowed--origins)))
              (dolist (o origins)
                (when (and (stringp o) (not (find #\: o)))
                  (push (make-validation-error :kind +invalid-web-origin+ :message "Origin must have a scheme") errors))))
            (let ((transport (json-getf acct-data :transport)))
              (when (and transport (string= transport "direct"))
                (push (make-validation-error :kind +invalid-web-transport+ :message "Unknown transport") errors)))
            (let ((mam (json-getf acct-data :message--auth--mode)))
              (when (and mam (string= mam "jwt"))
                (push (make-validation-error :kind +invalid-web-message-auth-mode+ :message "Unknown message auth mode") errors)))
            (let ((mam (json-getf acct-data :message--auth--mode))
                  (transport (json-getf acct-data :transport)))
              (when (and (string= mam "token") (string= transport "relay"))
                (push (make-validation-error :kind +invalid-web-message-auth-transport+ :message "Token auth incompatible with relay") errors)))
            (let ((transport (json-getf acct-data :transport))
                  (url (json-getf acct-data :relay--url)))
              (when (string= transport "relay")
                (unless url
                  (push (make-validation-error :kind +missing-web-relay-url+ :message "Relay transport requires relay_url") errors))
                (when (and url (>= (length url) 5) (string= (subseq url 0 5) "https"))
                  (push (make-validation-error :kind +invalid-web-relay-url+ :message "Relay URL must use wss scheme") errors))))
            (let ((agent-id (json-getf acct-data :relay--agent--id)))
              (when (and agent-id (find #\Space agent-id))
                (push (make-validation-error :kind +invalid-web-relay-agent-id+ :message "Agent ID cannot contain spaces") errors)))
            (let ((pcttl (json-getf acct-data :relay--pairing--code--ttl--secs)))
              (when (and pcttl (< pcttl 60))
                (push (make-validation-error :kind +invalid-web-relay-pairing-code-ttl+ :message "Pairing code TTL too low") errors)))
            (let ((uitlt (json-getf acct-data :relay--ui--token--ttl--secs)))
              (when (and uitlt (< uitlt 300))
                (push (make-validation-error :kind +invalid-web-relay-ui-token-ttl+ :message "UI token TTL too low") errors)))
            (let ((ttls (json-getf acct-data :relay--token--ttl--secs)))
              (when (and ttls (< ttls 3600))
                (push (make-validation-error :kind +invalid-web-relay-token-ttl+ :message "Token TTL too low") errors)))))))
                
    ;; Return in stable order
    (reverse errors)))
