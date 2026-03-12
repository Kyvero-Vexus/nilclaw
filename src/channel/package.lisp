;;;; package.lisp - Channel system package definition
;;;; NilClaw - Statically typed Common Lisp agent harness

(defpackage #:nilclaw/channel
  (:use #:common-lisp)
  (:export
   ;; Channel protocol
   #:channel
   #:channel-start
   #:channel-stop
   #:channel-send
   #:channel-name
   #:channel-health-check
   #:channel-send-event
   #:channel-start-typing
   #:channel-stop-typing

   ;; Channel message
   #:channel-message
   #:make-channel-message
   #:channel-message-id
   #:channel-message-sender
   #:channel-message-content
   #:channel-message-channel
   #:channel-message-timestamp
   #:channel-message-reply-target
   #:channel-message-message-id
   #:channel-message-first-name
   #:channel-message-is-group
   #:channel-message-sender-uuid
   #:channel-message-group-id

   ;; Outbound stage
   #:outbound-stage
   #:stage-chunk
   #:stage-final

   ;; Permission system
   #:dm-policy
   #:dm-policy-allow
   #:dm-policy-deny
   #:dm-policy-allowlist
   #:group-policy
   #:group-policy-open
   #:group-policy-mention-only
   #:group-policy-allowlist
   #:check-permission
   #:check-dm-permission
   #:check-group-permission

   ;; Channel implementations
   #:make-cli-channel
   #:make-web-channel
   #:web-channel-path
   #:web-channel-auth-token
   #:web-channel-allowed-origins
   #:web-channel-transport
   #:web-channel-relay-url
   #:web-channel-message-auth-mode
   #:web-channel-running

   ;; Channel manager
   #:channel-manager
   #:make-channel-manager
   #:register-channel
   #:unregister-channel
   #:find-channel
   #:start-all-channels
   #:stop-all-channels
   #:health-check-all

   ;; Auto-reply system
   #:auto-reply-rule
   #:make-auto-reply-rule
   #:auto-reply-rule-name
   #:auto-reply-rule-trigger-type
   #:auto-reply-rule-trigger-pattern
   #:auto-reply-rule-response
   #:auto-reply-rule-enabled
   #:auto-reply-rule-priority
   #:auto-reply-config
   #:make-auto-reply-config
   #:auto-reply-config-enabled
   #:auto-reply-config-max-replies-per-hour
   #:auto-reply-config-rules
   #:auto-reply-config-fallback-response
   #:auto-reply-runtime
   #:make-auto-reply-runtime
   #:auto-reply-runtime-config
   #:auto-reply-runtime-reply-counters
   #:make-default-auto-reply-runtime
   #:rule-matches-p
   #:can-reply-p
   #:compute-auto-reply
   #:channel-receive-with-auto-reply))
