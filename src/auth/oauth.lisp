;;;; OAuth flow implementation for nilclaw
;;;; Implements PKCE-based OpenAI Codex OAuth with local callback server

(in-package #:nilclaw/auth)

(declaim (optimize (safety 3) (debug 3)))

;;; ─── Constants ───────────────────────────────────────────────────────

(defconstant +openai-codex-client-id+ "app_EMoamEEZ73f0CkXaXp7hrann")
(defconstant +openai-codex-token-url+ "https://auth.openai.com/oauth/token")
(defconstant +openai-codex-authorize-url+ "https://auth.openai.com/oauth/authorize")
(defconstant +openai-codex-redirect-uri+ "http://localhost:1455/auth/callback")
(defconstant +openai-codex-scope+ "openid profile email offline_access")
(defconstant +callback-port+ 1455)

;;; ─── Paths ───────────────────────────────────────────────────────────

(declaim (ftype (function () pathname) nilclaw-auth-profiles-path))
(defun nilclaw-auth-profiles-path ()
  "Return the path to nilclaw's own auth-profiles.json."
  (merge-pathnames ".nilclaw/auth-profiles.json" (user-homedir-pathname)))

(declaim (ftype (function () pathname) ensure-nilclaw-dir))
(defun ensure-nilclaw-dir ()
  "Ensure ~/.nilclaw/ directory exists. Returns directory pathname."
  (let ((dir (merge-pathnames ".nilclaw/" (user-homedir-pathname))))
    (ensure-directories-exist dir)
    dir))

;;; ─── Auth profiles I/O ──────────────────────────────────────────────

(declaim (ftype (function () list) make-empty-auth-profiles))
(defun make-empty-auth-profiles ()
  "Return an empty auth-profiles alist structure."
  `((:version . 1)
    (:profiles)
    (:last-good)
    (:usage-stats)))

(declaim (ftype (function (&optional (or null pathname string)) list) read-auth-profiles))
(defun read-auth-profiles (&optional path)
  "Read auth-profiles.json from PATH (defaults to nilclaw's path).
   Returns parsed alist or empty structure if file doesn't exist."
  (declare (type (or null pathname string) path))
  (let ((p (or path (nilclaw-auth-profiles-path))))
    (if (probe-file p)
        (handler-case
            (with-open-file (stream p :direction :input :external-format :utf-8)
              (let* ((len (file-length stream))
                     (json-string (make-string len)))
                (read-sequence json-string stream)
                ;; Trim any trailing nulls from file-length overestimate
                (let ((actual-end (position #\Nul json-string)))
                  (when actual-end
                    (setf json-string (subseq json-string 0 actual-end))))
                (cl-json:decode-json-from-string json-string)))
          (error () (make-empty-auth-profiles)))
        (make-empty-auth-profiles))))

(declaim (ftype (function (list &optional (or null pathname string)) null)
                write-auth-profiles))
(defun write-auth-profiles (data &optional path)
  "Write auth-profiles DATA to PATH (defaults to nilclaw's path)."
  (declare (type list data)
           (type (or null pathname string) path))
  (ensure-nilclaw-dir)
  (let ((p (or path (nilclaw-auth-profiles-path))))
    (with-open-file (out p :direction :output
                           :if-exists :supersede
                           :if-does-not-exist :create
                           :external-format :utf-8)
      (cl-json:encode-json data out))
    nil))

(defun alist-get (key alist)
  "Get value from alist by key (symbol or string)."
  (let ((key-name (if (symbolp key)
                      (string-downcase (symbol-name key))
                      (string-downcase key))))
    (dolist (entry alist)
      (when (consp entry)
        (let ((entry-key (if (symbolp (car entry))
                             (string-downcase (symbol-name (car entry)))
                             (string-downcase (string (car entry))))))
          (when (string= key-name entry-key)
            (return-from alist-get (cdr entry))))))))

(defun unix-epoch-ms ()
  "Return current time as milliseconds since Unix epoch."
  (* 1000 (- (get-universal-time) 2208988800)))

;;; ─── PKCE ────────────────────────────────────────────────────────────

(declaim (ftype (function ((simple-array (unsigned-byte 8) (*))) string)
                base64url-encode-bytes))
(defun base64url-encode-bytes (bytes)
  "Encode a byte array as base64url (no padding)."
  (declare (type (simple-array (unsigned-byte 8) (*)) bytes))
  (let* (;; Proper base64 encoding
         (raw (with-output-to-string (s)
                (let ((table "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"))
                  (declare (type string table))
                  (let ((len (length bytes))
                        (i 0))
                    (declare (type fixnum len i))
                    (loop while (< i len)
                          do (let* ((b0 (aref bytes i))
                                    (b1 (if (< (1+ i) len) (aref bytes (1+ i)) 0))
                                    (b2 (if (< (+ i 2) len) (aref bytes (+ i 2)) 0))
                                    (remaining (- len i)))
                               (declare (type (unsigned-byte 8) b0 b1 b2)
                                        (type fixnum remaining))
                               (write-char (char table (ash b0 -2)) s)
                               (write-char (char table (logior (ash (logand b0 3) 4)
                                                               (ash b1 -4))) s)
                               (if (>= remaining 2)
                                   (write-char (char table (logior (ash (logand b1 15) 2)
                                                                   (ash b2 -6))) s)
                                   (write-char #\= s))
                               (if (>= remaining 3)
                                   (write-char (char table (logand b2 63)) s)
                                   (write-char #\= s))
                               (incf i 3))))))))
    (declare (type string raw))
    ;; Convert to base64url: replace + with -, / with _, strip =
    (let ((result (make-array (length raw) :element-type 'character :fill-pointer 0)))
      (loop for c across raw
            do (case c
                 (#\+ (vector-push-extend #\- result))
                 (#\/ (vector-push-extend #\_ result))
                 (#\= ) ; skip padding
                 (otherwise (vector-push-extend c result))))
      (coerce result 'string))))

(declaim (ftype (function () (values string string)) generate-pkce))
(defun generate-pkce ()
  "Generate PKCE code verifier and S256 challenge.
   Returns (values verifier challenge)."
  (let* ((verifier-bytes (ironclad:random-data 32))
         (verifier (base64url-encode-bytes verifier-bytes))
         ;; SHA-256 of the verifier string
         (digest (ironclad:digest-sequence
                  :sha256
                  (babel:string-to-octets verifier :encoding :utf-8)))
         (challenge (base64url-encode-bytes digest)))
    (values verifier challenge)))

;;; ─── Authorization URL ───────────────────────────────────────────────

(defun url-encode (string)
  "URL-encode a string."
  (declare (type string string))
  (with-output-to-string (s)
    (loop for c across string
          do (cond
               ((or (alphanumericp c)
                    (member c '(#\- #\_ #\. #\~)))
                (write-char c s))
               ((char= c #\Space)
                (write-char #\+ s))
               (t
                (format s "%~2,'0X" (char-code c)))))))

(declaim (ftype (function (&key (:originator string))
                          (values string string string))
                create-authorization-flow))
(defun create-authorization-flow (&key (originator "nilclaw"))
  "Create an OAuth authorization flow.
   Returns (values auth-url verifier state)."
  (declare (type string originator))
  (multiple-value-bind (verifier challenge) (generate-pkce)
    (let* ((state-bytes (ironclad:random-data 16))
           (state (ironclad:byte-array-to-hex-string state-bytes))
           (url (format nil "~A?response_type=code&client_id=~A&redirect_uri=~A&scope=~A&code_challenge=~A&code_challenge_method=S256&state=~A&id_token_add_organizations=true&codex_cli_simplified_flow=true&originator=~A"
                        +openai-codex-authorize-url+
                        (url-encode +openai-codex-client-id+)
                        (url-encode +openai-codex-redirect-uri+)
                        (url-encode +openai-codex-scope+)
                        (url-encode challenge)
                        (url-encode state)
                        (url-encode originator))))
      (values url verifier state))))

;;; ─── Callback Server ─────────────────────────────────────────────────

(defvar *callback-acceptor* nil "Active Hunchentoot acceptor for OAuth callback.")
(defvar *callback-code* nil "Authorization code received from callback.")
(defvar *callback-state* nil "State parameter received from callback.")
(defvar *expected-state* nil "Expected state parameter for validation.")

(defconstant +success-html+
  "<!doctype html>
<html lang=\"en\">
<head>
  <meta charset=\"utf-8\" />
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
  <title>Authentication successful</title>
</head>
<body>
  <p>Authentication successful. Return to your terminal to continue.</p>
</body>
</html>")

(defun callback-handler ()
  "Handle the OAuth callback request."
  (let ((path (hunchentoot:script-name*)))
    (unless (string= path "/auth/callback")
      (setf (hunchentoot:return-code*) 404)
      (return-from callback-handler "Not found"))
    (let ((state (hunchentoot:parameter "state"))
          (code (hunchentoot:parameter "code")))
      (when (and state (not (string= state *expected-state*)))
        (setf (hunchentoot:return-code*) 400)
        (return-from callback-handler "State mismatch"))
      (unless code
        (setf (hunchentoot:return-code*) 400)
        (return-from callback-handler "Missing authorization code"))
      ;; Store the code and state
      (setf *callback-code* code
            *callback-state* state)
      (setf (hunchentoot:content-type*) "text/html; charset=utf-8")
      +success-html+)))

(declaim (ftype (function (string) t) start-callback-server))
(defun start-callback-server (expected-state)
  "Start the localhost callback server on port 1455.
   EXPECTED-STATE is used to validate the OAuth state parameter."
  (declare (type string expected-state))
  (setf *callback-code* nil
        *callback-state* nil
        *expected-state* expected-state)
  (let ((acceptor (make-instance 'hunchentoot:easy-acceptor
                                 :port +callback-port+
                                 :address "127.0.0.1")))
    ;; Suppress Hunchentoot's default logging
    (setf (hunchentoot:acceptor-message-log-destination acceptor) nil
          (hunchentoot:acceptor-access-log-destination acceptor) nil)
    ;; Set up the dispatch
    (setf hunchentoot:*dispatch-table*
          (list (hunchentoot:create-prefix-dispatcher "/auth/callback"
                                                      #'callback-handler)))
    (hunchentoot:start acceptor)
    (setf *callback-acceptor* acceptor)
    acceptor))

(declaim (ftype (function () null) stop-callback-server))
(defun stop-callback-server ()
  "Stop the callback server."
  (when *callback-acceptor*
    (handler-case (hunchentoot:stop *callback-acceptor*)
      (error () nil))
    (setf *callback-acceptor* nil))
  nil)

(declaim (ftype (function (&key (:timeout-seconds fixnum)) (or null string))
                wait-for-callback))
(defun wait-for-callback (&key (timeout-seconds 300))
  "Wait for the OAuth callback to deliver a code. Returns code or nil on timeout."
  (declare (type fixnum timeout-seconds))
  (let ((deadline (+ (get-universal-time) timeout-seconds)))
    (loop while (and (null *callback-code*)
                     (< (get-universal-time) deadline))
          do (sleep 0.5))
    *callback-code*))

;;; ─── Token Exchange ──────────────────────────────────────────────────

(declaim (ftype (function (string string &key (:redirect-uri string))
                          (values (or null string) (or null string) (or null integer)))
                exchange-authorization-code))
(defun exchange-authorization-code (code verifier &key (redirect-uri +openai-codex-redirect-uri+))
  "Exchange authorization code for tokens.
   Returns (values access-token refresh-token expires-ms) or (values nil nil nil) on failure."
  (declare (type string code verifier redirect-uri))
  (let ((dex-post (let ((pkg (find-package :dexador)))
                    (when pkg (find-symbol "POST" pkg)))))
    (unless dex-post
      (return-from exchange-authorization-code (values nil nil nil)))
    (handler-case
        (let* ((body (format nil "grant_type=authorization_code&client_id=~A&code=~A&code_verifier=~A&redirect_uri=~A"
                             +openai-codex-client-id+
                             (url-encode code)
                             (url-encode verifier)
                             (url-encode redirect-uri)))
               (response (funcall (symbol-function dex-post)
                                  +openai-codex-token-url+
                                  :content body
                                  :headers '(("Content-Type" . "application/x-www-form-urlencoded")))))
          (when (stringp response)
            (let* ((parsed (cl-json:decode-json-from-string response))
                   (access (alist-get :access--token parsed))
                   (refresh (alist-get :refresh--token parsed))
                   (expires-in (alist-get :expires--in parsed)))
              (if (and (stringp access) (stringp refresh) (numberp expires-in))
                  (values access refresh (+ (unix-epoch-ms) (* 1000 (truncate expires-in))))
                  (values nil nil nil)))))
      (error ()
        (values nil nil nil)))))

(declaim (ftype (function (string)
                          (values (or null string) (or null string) (or null integer)))
                refresh-access-token))
(defun refresh-access-token (refresh-token)
  "Refresh an OAuth access token.
   Returns (values access-token refresh-token expires-ms) or (values nil nil nil)."
  (declare (type string refresh-token))
  (let ((dex-post (let ((pkg (find-package :dexador)))
                    (when pkg (find-symbol "POST" pkg)))))
    (unless dex-post
      (return-from refresh-access-token (values nil nil nil)))
    (handler-case
        (let* ((body (format nil "grant_type=refresh_token&refresh_token=~A&client_id=~A"
                             (url-encode refresh-token) +openai-codex-client-id+))
               (response (funcall (symbol-function dex-post)
                                  +openai-codex-token-url+
                                  :content body
                                  :headers '(("Content-Type" . "application/x-www-form-urlencoded")))))
          (when (stringp response)
            (let* ((parsed (cl-json:decode-json-from-string response))
                   (access (alist-get :access--token parsed))
                   (new-refresh (alist-get :refresh--token parsed))
                   (expires-in (alist-get :expires--in parsed)))
              (if (and (stringp access) (numberp expires-in))
                  (values access
                          (if (stringp new-refresh) new-refresh refresh-token)
                          (+ (unix-epoch-ms) (* 1000 (truncate expires-in))))
                  (values nil nil nil)))))
      (error ()
        (values nil nil nil)))))

;;; ─── Profile Storage ─────────────────────────────────────────────────

(defun store-oauth-tokens (provider-name access-token refresh-token expires-ms
                           &optional path)
  "Store OAuth tokens in nilclaw's auth-profiles.json."
  (declare (type string provider-name access-token refresh-token)
           (type integer expires-ms))
  (let* ((data (read-auth-profiles path))
         (profiles (alist-get :profiles data))
         (profile-key (format nil "~A:default" provider-name))
         (profile-entry `((:type . "oauth")
                          (:provider . ,provider-name)
                          (:access . ,access-token)
                          (:refresh . ,refresh-token)
                          (:expires . ,expires-ms)))
         ;; Update or add the profile
         (new-profiles (if (listp profiles)
                           (mapcar (lambda (entry)
                                     (if (and (consp entry)
                                              (string= (string (car entry)) profile-key))
                                         (cons (car entry) profile-entry)
                                         entry))
                                   profiles)
                           nil)))
    ;; If not found, add new entry
    (unless (and (listp profiles)
                 (find profile-key profiles
                       :key (lambda (e) (when (consp e) (string (car e))))
                       :test #'string=))
      (push (cons (intern (string-upcase profile-key) :keyword) profile-entry)
            new-profiles))
    ;; Rebuild data with updated profiles
    (let ((updated-data `((:version . 1)
                          (:profiles . ,new-profiles)
                          (:last-good . ((,(intern (string-upcase provider-name) :keyword) . ,profile-key)))
                          (:usage-stats . ,(or (alist-get :usage-stats data) nil)))))
      (write-auth-profiles updated-data path))))

;;; ─── Token Retrieval (nilclaw-first) ─────────────────────────────────

(declaim (ftype (function (string &optional (or null string)) (or null string))
                get-access-token))
(defun get-access-token (provider-name &optional agent-dir)
  "Get OAuth access token for PROVIDER-NAME.
   Checks nilclaw's auth-profiles.json ONLY (no OpenClaw fallback here
   to avoid circular calls — the fallback is in config/provider.lisp)."
  (declare (type string provider-name)
           (type (or null string) agent-dir))
  (declare (ignore agent-dir))
  ;; Only check nilclaw's own auth-profiles.json
  (let ((nilclaw-path (nilclaw-auth-profiles-path)))
    (when (probe-file nilclaw-path)
      (get-token-from-profiles nilclaw-path provider-name))))

(defun get-token-from-profiles (path provider-name)
  "Get a valid access token from an auth-profiles file.
   Handles auto-refresh of expired tokens."
  (declare (type (or pathname string) path)
           (type string provider-name))
  (let* ((data (read-auth-profiles path))
         (profiles (alist-get :profiles data)))
    (when (listp profiles)
      (dolist (entry profiles)
        (when (consp entry)
          (let ((pdata (cdr entry)))
            (when (and (listp pdata)
                       (equal (alist-get :provider pdata) provider-name)
                       (equal (alist-get :type pdata) "oauth"))
              (let ((access (alist-get :access pdata))
                    (refresh (alist-get :refresh pdata))
                    (expires (alist-get :expires pdata))
                    (now-ms (unix-epoch-ms)))
                ;; Token still valid
                (when (and (stringp access) (numberp expires) (> expires now-ms))
                  (return-from get-token-from-profiles access))
                ;; Try refresh
                (when (and (stringp refresh)
                           (string= provider-name "openai-codex"))
                  (multiple-value-bind (new-access new-refresh new-expires)
                      (refresh-access-token refresh)
                    (when new-access
                      (store-oauth-tokens provider-name new-access
                                          (or new-refresh refresh)
                                          (or new-expires (+ now-ms (* 1000 3600)))
                                          path)
                      (return-from get-token-from-profiles new-access))))
                ;; Fallback: return expired token
                (when (stringp access)
                  (return-from get-token-from-profiles access))))))))))

;;; ─── High-level login flow ───────────────────────────────────────────

(declaim (ftype (function (string &key (:timeout-seconds fixnum)) (values boolean string))
                run-oauth-login))
(defun run-oauth-login (provider-name &key (timeout-seconds 300))
  "Run the full OAuth login flow for PROVIDER-NAME.
   Returns (values success-p message)."
  (declare (type string provider-name)
           (type fixnum timeout-seconds))
  (unless (string= provider-name "openai-codex")
    (return-from run-oauth-login
      (values nil (format nil "Unsupported OAuth provider: ~A" provider-name))))
  (format t "[nilclaw] Starting OAuth login for ~A...~%" provider-name)
  ;; Generate flow
  (multiple-value-bind (auth-url verifier state)
      (create-authorization-flow)
    ;; Start callback server
    (handler-case
        (start-callback-server state)
      (error (e)
        (return-from run-oauth-login
          (values nil (format nil "Failed to start callback server: ~A" e)))))
    (unwind-protect
        (progn
          (format t "~%Open this URL in your browser to authenticate:~%~%  ~A~%~%" auth-url)
          (format t "Waiting for callback (timeout: ~D seconds)...~%" timeout-seconds)
          (finish-output)
          ;; Wait for callback
          (let ((code (wait-for-callback :timeout-seconds timeout-seconds)))
            (unless code
              (return-from run-oauth-login
                (values nil "Timed out waiting for OAuth callback")))
            (format t "[nilclaw] Received authorization code, exchanging for tokens...~%")
            ;; Need dexador for HTTP
            (let ((enable-fn (let ((pkg (find-package :nilclaw/provider)))
                               (when pkg
                                 (let ((sym (find-symbol "ENABLE-DEXADOR-BACKEND" pkg)))
                                   (when (and sym (fboundp sym))
                                     (symbol-function sym)))))))
              (when enable-fn (funcall enable-fn)))
            ;; Exchange code for tokens
            (multiple-value-bind (access refresh expires)
                (exchange-authorization-code code verifier)
              (unless access
                (return-from run-oauth-login
                  (values nil "Failed to exchange authorization code for tokens")))
              ;; Store tokens
              (store-oauth-tokens provider-name access refresh expires)
              (format t "[nilclaw] Authentication successful! Tokens stored in ~~/.nilclaw/auth-profiles.json~%")
              (values t "Authentication successful"))))
      ;; Always stop the server
      (stop-callback-server))))
