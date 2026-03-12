;;;; Provider runtime construction from config
;;;; Bridges nilclaw/config with nilclaw/provider

(in-package #:nilclaw/config)

(declaim (optimize (safety 3) (debug 3)))

;;; OpenClaw auth-profiles.json reading for OAuth

(declaim (ftype (function (&optional (or null string)) (or null string))
                read-openclaw-auth-profiles-path))
(defun read-openclaw-auth-profiles-path (&optional agent-dir)
  "Find the auth-profiles.json file. Checks agent-dir first, then main."
  (declare (type (or null string) agent-dir))
  (let ((paths (list
                (when agent-dir
                  (merge-pathnames "agent/auth-profiles.json"
                                   (pathname-as-directory agent-dir)))
                (merge-pathnames ".openclaw/agents/main/agent/auth-profiles.json"
                                 (user-homedir-pathname)))))
    (dolist (p paths)
      (when (and p (probe-file p))
        (return-from read-openclaw-auth-profiles-path (namestring p))))))

(declaim (ftype (function ((or string symbol) list) t) alist-get))
(defun alist-get (key alist)
  "Get value from alist by key (symbol or string)."
  (declare (type (or string symbol) key)
           (type list alist))
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

(declaim (ftype (function (string) list) parse-json-file))
(defun parse-json-file (path)
  "Parse a JSON file into an alist. Returns nil on error."
  (declare (type string path))
  (handler-case
      (with-open-file (stream path :direction :input :external-format :utf-8)
        (let ((json-string (make-string (file-length stream))))
          (read-sequence json-string stream)
          (cl-json:decode-json-from-string json-string)))
    (error () nil)))

;;; OAuth constants for OpenAI Codex
(defparameter *openai-codex-token-url* "https://auth.openai.com/oauth/token")
(defparameter *openai-codex-client-id* "app_EMoamEEZ73f0CkXaXp7hrann")

(defun unix-epoch-ms ()
  "Return current time as milliseconds since Unix epoch."
  (* 1000 (- (get-universal-time) 2208988800)))

(declaim (ftype (function (string string) (or null string)) refresh-openai-codex-token))
(defun refresh-openai-codex-token (refresh-token auth-path)
  "Refresh an OpenAI Codex OAuth token. Returns new access token or nil."
  (declare (type string refresh-token auth-path))
  (let ((dex-post (let ((pkg (find-package :dexador)))
                    (when pkg (find-symbol "POST" pkg)))))
    (unless dex-post
      (return-from refresh-openai-codex-token nil))
    (handler-case
        (let* ((body (format nil "grant_type=refresh_token&refresh_token=~A&client_id=~A"
                             refresh-token *openai-codex-client-id*))
               (response (funcall (symbol-function dex-post)
                                  *openai-codex-token-url*
                                  :content body
                                  :headers '(("Content-Type" . "application/x-www-form-urlencoded")))))
          (when (stringp response)
            (let* ((parsed (cl-json:decode-json-from-string response))
                   (access (alist-get :access--token parsed))
                   (new-refresh (alist-get :refresh--token parsed))
                   (expires-in (alist-get :expires--in parsed)))
              (when (and (stringp access) (numberp expires-in))
                (update-auth-profiles-file auth-path access new-refresh expires-in)
                access))))
      (error () nil))))

(defun update-auth-profiles-file (auth-path access new-refresh expires-in)
  "Update auth-profiles.json with refreshed OAuth tokens."
  (declare (type string auth-path access)
           (type (or null string) new-refresh)
           (type number expires-in))
  (handler-case
      (let ((data (parse-json-file auth-path)))
        (when data
          (let ((profiles (alist-get :profiles data)))
            (dolist (entry profiles)
              (when (consp entry)
                (let ((pdata (cdr entry)))
                  (when (and (listp pdata)
                             (equal (alist-get :provider pdata) "openai-codex")
                             (equal (alist-get :type pdata) "oauth"))
                    (let ((ac (assoc :access pdata :test #'eq)))
                      (when ac (setf (cdr ac) access)))
                    (when (stringp new-refresh)
                      (let ((rc (assoc :refresh pdata :test #'eq)))
                        (when rc (setf (cdr rc) new-refresh))))
                    (let ((ec (assoc :expires pdata :test #'eq)))
                      (when ec
                        (setf (cdr ec) (+ (unix-epoch-ms) (* 1000 (truncate expires-in))))))))))
            (with-open-file (out auth-path :direction :output
                                           :if-exists :supersede
                                           :external-format :utf-8)
              (cl-json:encode-json data out)))))
    (error () nil)))

(defun find-oauth-profile-data (profiles provider-name)
  "Find OAuth profile data for PROVIDER-NAME in PROFILES alist.
   Returns pdata (the profile's alist) or nil."
  (dolist (entry profiles)
    (when (consp entry)
      (let ((pdata (cdr entry)))
        (when (and (listp pdata)
                   (equal (alist-get :provider pdata) provider-name)
                   (equal (alist-get :type pdata) "oauth"))
          (return pdata))))))

(declaim (ftype (function (string &optional (or null string)) (or null string))
                get-oauth-access-token))
(defun get-oauth-access-token (provider-name &optional agent-dir)
  "Get OAuth access token for PROVIDER-NAME from OpenClaw auth-profiles.json.
   Refreshes expired tokens automatically for supported providers."
  (declare (type string provider-name)
           (type (or null string) agent-dir))
  (let ((auth-path (read-openclaw-auth-profiles-path agent-dir)))
    (unless auth-path (return-from get-oauth-access-token nil))
    (let* ((data (parse-json-file auth-path))
           (profiles (when data (alist-get :profiles data)))
           (pdata (when (listp profiles) (find-oauth-profile-data profiles provider-name))))
      (unless pdata (return-from get-oauth-access-token nil))
      (let ((access (alist-get :access pdata))
            (refresh (alist-get :refresh pdata))
            (expires (alist-get :expires pdata))
            (now-ms (unix-epoch-ms)))
        ;; Token still valid — return it
        (when (and (stringp access) (numberp expires) (> expires now-ms))
          (return-from get-oauth-access-token access))
        ;; Token expired — try refresh
        (when (and (stringp refresh) (string= provider-name "openai-codex"))
          (let ((new-access (refresh-openai-codex-token refresh auth-path)))
            (when new-access
              (return-from get-oauth-access-token new-access))))
        ;; Fallback: return expired token
        (when (stringp access) access)))))

(defun pathname-as-directory (path)
  "Ensure path is treated as a directory."
  (let ((p (pathname path)))
    (make-pathname :directory (append (or (pathname-directory p) '(:relative))
                                      (list (pathname-name p)))
                   :name nil :type nil :defaults p)))

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
   For OAuth providers, reads access token from OpenClaw's auth-profiles.json."
  (declare (type config cfg)
           (type string provider-name))
  (let* ((pconfig (get-provider-config cfg provider-name))
         (auth-profiles (config-auth-profiles cfg))
         (oauth-profile (find provider-name auth-profiles
                              :key (lambda (p) (getf p :provider))
                              :test #'string=))
         (uses-oauth (and oauth-profile (string= (getf oauth-profile :mode) "oauth")))
         (api-key (if uses-oauth
                      (get-oauth-access-token provider-name)
                      (when pconfig (getf pconfig :api-key))))
         (base-url (when pconfig (getf pconfig :base-url)))
         (reliability (config-reliability cfg))
         (max-retries (getf reliability :provider-retries 2)))
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
  "Resolve the default provider and model from config."
  (declare (type config cfg))
  (let* ((default-provider (config-default-provider cfg))
         (default-model (config-default-model cfg)))
    (if default-model
        (multiple-value-bind (provider model)
            (parse-model-string default-model)
          (values (if (> (length provider) 0) provider default-provider)
                  model))
        (values default-provider nil))))
