;;;; Auth module package — OAuth flows and token storage for nilclaw
(defpackage #:nilclaw/auth
  (:use #:cl)
  (:export
   ;; Auth profiles path
   #:nilclaw-auth-profiles-path
   #:ensure-nilclaw-dir
   ;; Auth profiles I/O
   #:read-auth-profiles
   #:write-auth-profiles
   #:make-empty-auth-profiles
   ;; PKCE
   #:generate-pkce
   ;; OAuth flow
   #:create-authorization-flow
   #:start-callback-server
   #:stop-callback-server
   #:exchange-authorization-code
   #:refresh-access-token
   ;; High-level
   #:run-oauth-login
   ;; Token retrieval (nilclaw-first, openclaw fallback)
   #:get-access-token
   ;; Constants
   #:+openai-codex-client-id+
   #:+openai-codex-token-url+
   #:+openai-codex-authorize-url+
   #:+openai-codex-redirect-uri+
   #:+openai-codex-scope+
   #:+callback-port+))
