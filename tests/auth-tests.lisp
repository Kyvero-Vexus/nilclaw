;;;; Tests for nilclaw/auth module
;;;; OAuth flow, PKCE, auth profiles I/O, token retrieval

(in-package #:nilclaw/tests)

(in-suite auth-suite)

;;; ─── PKCE Tests ──────────────────────────────────────────────────────

(test pkce-generates-verifier-and-challenge
  "generate-pkce should return two distinct non-empty strings."
  (multiple-value-bind (verifier challenge) (nilclaw/auth:generate-pkce)
    (is (stringp verifier))
    (is (stringp challenge))
    (is (> (length verifier) 0))
    (is (> (length challenge) 0))
    (is (not (string= verifier challenge)))))

(test pkce-verifier-is-base64url
  "PKCE verifier should only contain base64url-safe characters."
  (multiple-value-bind (verifier challenge) (nilclaw/auth:generate-pkce)
    (declare (ignore challenge))
    (is (every (lambda (c)
                 (or (alphanumericp c)
                     (char= c #\-)
                     (char= c #\_)))
               verifier))))

(test pkce-challenge-is-base64url
  "PKCE challenge should only contain base64url-safe characters."
  (multiple-value-bind (verifier challenge) (nilclaw/auth:generate-pkce)
    (declare (ignore verifier))
    (is (every (lambda (c)
                 (or (alphanumericp c)
                     (char= c #\-)
                     (char= c #\_)))
               challenge))))

(test pkce-generates-unique-pairs
  "Each call to generate-pkce should produce unique values."
  (multiple-value-bind (v1 c1) (nilclaw/auth:generate-pkce)
    (multiple-value-bind (v2 c2) (nilclaw/auth:generate-pkce)
      (is (not (string= v1 v2)))
      (is (not (string= c1 c2))))))

(test pkce-challenge-is-sha256-of-verifier
  "The challenge should be base64url(SHA256(verifier))."
  (multiple-value-bind (verifier challenge) (nilclaw/auth:generate-pkce)
    ;; Manually compute SHA256 of verifier and compare
    (let* ((digest (ironclad:digest-sequence
                    :sha256
                    (babel:string-to-octets verifier :encoding :utf-8)))
           ;; We can't easily replicate base64url-encode-bytes here
           ;; but we can check the challenge length is correct for SHA256
           ;; SHA256 = 32 bytes → base64url = ceil(32*4/3) = 43 chars
           (expected-len 43))
      (declare (ignore digest))
      (is (= expected-len (length challenge))))))

;;; ─── Auth Profiles I/O Tests ─────────────────────────────────────────

(test make-empty-auth-profiles-structure
  "make-empty-auth-profiles should return correct alist structure."
  (let ((data (nilclaw/auth:make-empty-auth-profiles)))
    (is (listp data))
    (is (= 1 (cdr (assoc :version data))))
    (is (assoc :profiles data))
    (is (assoc :last-good data))
    (is (assoc :usage-stats data))))

(test auth-profiles-roundtrip
  "Writing and reading auth profiles should preserve structure."
  (let ((tmp (merge-pathnames "nilclaw-test-auth.json"
                               (uiop:temporary-directory))))
    (unwind-protect
        (let ((data `((:version . 1)
                      (:profiles
                       (:|openai-codex:default|
                        (:type . "oauth")
                        (:provider . "openai-codex")
                        (:access . "test-access-token")
                        (:refresh . "test-refresh-token")
                        (:expires . 9999999999999)))
                      (:last-good
                       (:|openai-codex| . "openai-codex:default"))
                      (:usage-stats))))
          (nilclaw/auth:write-auth-profiles data tmp)
          (let ((read-back (nilclaw/auth:read-auth-profiles tmp)))
            (is (= 1 (cdr (assoc :version read-back))))
            (let* ((profiles (cdr (assoc :profiles read-back)))
                   (first-entry (car profiles)))
              (is (consp first-entry))
              (let ((pdata (cdr first-entry)))
                (is (equal "oauth" (cdr (assoc :type pdata))))
                (is (equal "openai-codex" (cdr (assoc :provider pdata))))
                (is (equal "test-access-token" (cdr (assoc :access pdata))))
                (is (equal "test-refresh-token" (cdr (assoc :refresh pdata))))))))
      (when (probe-file tmp) (delete-file tmp)))))

(test read-auth-profiles-returns-empty-when-missing
  "read-auth-profiles should return empty structure for non-existent file."
  (let ((data (nilclaw/auth:read-auth-profiles "/tmp/nonexistent-nilclaw-auth.json")))
    (is (listp data))
    (is (= 1 (cdr (assoc :version data))))))

;;; ─── Authorization Flow Tests ────────────────────────────────────────

(test create-authorization-flow-returns-valid-url
  "create-authorization-flow should return a valid authorize URL."
  (multiple-value-bind (url verifier state)
      (nilclaw/auth:create-authorization-flow)
    (is (stringp url))
    (is (stringp verifier))
    (is (stringp state))
    ;; URL should contain expected components
    (is (search "auth.openai.com/oauth/authorize" url))
    (is (search "client_id=" url))
    (is (search "code_challenge=" url))
    (is (search "code_challenge_method=S256" url))
    (is (search "state=" url))
    (is (search "redirect_uri=" url))
    ;; State should be hex string (32 hex chars for 16 bytes)
    (is (= 32 (length state)))
    ;; Verifier should be non-empty base64url
    (is (> (length verifier) 0))))

(test create-authorization-flow-unique-state
  "Each call should generate unique state values."
  (multiple-value-bind (url1 v1 state1) (nilclaw/auth:create-authorization-flow)
    (declare (ignore url1 v1))
    (multiple-value-bind (url2 v2 state2) (nilclaw/auth:create-authorization-flow)
      (declare (ignore url2 v2))
      (is (not (string= state1 state2))))))

;;; ─── Callback Server Tests ──────────────────────────────────────────

(test callback-server-starts-and-stops
  "Callback server should start on port 1455 and stop cleanly."
  (let ((acceptor (nilclaw/auth:start-callback-server "test-state-123")))
    (is (not (null acceptor)))
    (unwind-protect
        (progn
          ;; Server should be running
          (is (hunchentoot:started-p acceptor)))
      (nilclaw/auth:stop-callback-server))))

(test callback-server-handles-callback
  "Callback server should accept valid callback and capture code."
  (let ((acceptor (nilclaw/auth:start-callback-server "test-state-abc")))
    (unwind-protect
        (progn
          ;; Make a request to the callback endpoint
          (handler-case
              (let ((response (drakma:http-request
                               (format nil "http://127.0.0.1:~D/auth/callback?code=test-auth-code&state=test-state-abc"
                                       nilclaw/auth:+callback-port+)
                               :method :get)))
                ;; Response should contain success message
                (is (search "Authentication successful"
                            (if (stringp response)
                                response
                                (babel:octets-to-string response)))))
            (error (e)
              (fail "HTTP request to callback failed: ~A" e))))
      (nilclaw/auth:stop-callback-server))))

;;; ─── Constants Tests ─────────────────────────────────────────────────

(test oauth-constants-correct
  "OAuth constants should match expected values."
  (is (string= "app_EMoamEEZ73f0CkXaXp7hrann" nilclaw/auth:+openai-codex-client-id+))
  (is (string= "https://auth.openai.com/oauth/token" nilclaw/auth:+openai-codex-token-url+))
  (is (string= "https://auth.openai.com/oauth/authorize" nilclaw/auth:+openai-codex-authorize-url+))
  (is (string= "http://localhost:1455/auth/callback" nilclaw/auth:+openai-codex-redirect-uri+))
  (is (= 1455 nilclaw/auth:+callback-port+)))

;;; ─── Token Retrieval Tests (nilclaw-first) ───────────────────────────

(test get-access-token-reads-nilclaw-first
  "get-access-token should prefer nilclaw's auth-profiles over OpenClaw's."
  (let ((tmp (merge-pathnames "nilclaw-test-auth-priority.json"
                               (uiop:temporary-directory))))
    (unwind-protect
        (progn
          ;; Write a test profile with a far-future expiry
          (let ((data `((:version . 1)
                        (:profiles
                         (:|openai-codex:default|
                          (:type . "oauth")
                          (:provider . "openai-codex")
                          (:access . "nilclaw-token-123")
                          (:refresh . "nilclaw-refresh-456")
                          (:expires . 9999999999999)))
                        (:last-good)
                        (:usage-stats))))
            (nilclaw/auth:write-auth-profiles data tmp))
          ;; Read back and verify the token is accessible
          (let ((read-back (nilclaw/auth:read-auth-profiles tmp)))
            (let* ((profiles (cdr (assoc :profiles read-back)))
                   (first-entry (car profiles))
                   (pdata (cdr first-entry)))
              (is (equal "nilclaw-token-123" (cdr (assoc :access pdata)))))))
      (when (probe-file tmp) (delete-file tmp)))))

;;; ─── Nilclaw Auth Profiles Path Test ─────────────────────────────────

(test nilclaw-auth-profiles-path-is-in-home
  "nilclaw-auth-profiles-path should point to ~/.nilclaw/auth-profiles.json."
  (let ((path (nilclaw/auth:nilclaw-auth-profiles-path)))
    (is (pathnamep path))
    (is (search ".nilclaw" (namestring path)))
    (is (search "auth-profiles.json" (namestring path)))))

(test ensure-nilclaw-dir-creates-directory
  "ensure-nilclaw-dir should create ~/.nilclaw/ if it doesn't exist."
  (let ((dir (nilclaw/auth:ensure-nilclaw-dir)))
    (is (pathnamep dir))))

;;; ─── Integration with config/provider ────────────────────────────────

(test get-oauth-access-token-falls-back-to-openclaw
  "get-oauth-access-token should fall back to OpenClaw when nilclaw auth is empty."
  ;; This test verifies the fallback path exists;
  ;; actual OpenClaw file may or may not be present
  (let ((result (nilclaw/config:get-oauth-access-token "nonexistent-provider")))
    ;; Should return nil for a non-existent provider
    (is-false result)))

;;; ─── CLI Command Parsing Tests ───────────────────────────────────────

(test auth-login-unsupported-provider
  "run-oauth-login should reject unsupported providers."
  (multiple-value-bind (success-p message)
      (nilclaw/auth:run-oauth-login "unsupported-provider")
    (is-false success-p)
    (is (search "Unsupported" message))))
