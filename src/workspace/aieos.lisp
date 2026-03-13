(in-package #:nilclaw/workspace)

(declaim (optimize (safety 3) (debug 3)))

;;; ---------------------------------------------------------------------------
;;; AIEOS Identity Format (v1.1) — structured identity specification
;;; ---------------------------------------------------------------------------
;;; Activated when identity.format = "aieos" and either identity.aieos_path
;;; or identity.aieos_inline is set. Produces markdown prompt sections from
;;; a structured JSON identity document.

(defun aieos-configured-p (identity-config)
  "Check whether AIEOS identity is configured.
   IDENTITY-CONFIG is a plist with :format, :aieos-path, :aieos-inline keys.
   Returns T when format is \"aieos\" (case-sensitive, lowercase) and either
   path or inline is set."
  (if (and (string= "aieos" (getf identity-config :format ""))
           (or (getf identity-config :aieos-path)
               (getf identity-config :aieos-inline)))
      t nil))

(declaim (ftype (function (string) list) parse-aieos))
(defun parse-aieos (json-string)
  "Parse an AIEOS JSON identity document into an alist.
   Returns the parsed JSON as a nested alist (cl-json format)."
  (declare (type string json-string))
  (json:decode-json-from-string json-string))

;;; ---------------------------------------------------------------------------
;;; AIEOS Rendering — convert structured identity to markdown prompt
;;; ---------------------------------------------------------------------------

(defun %alist-get (key alist &optional default)
  "Get value from alist by keyword KEY (case-insensitive symbol match)."
  (let ((pair (assoc key alist)))
    (if pair (cdr pair) default)))

(defun %render-name (identity-section)
  "Render the name portion of an AIEOS identity section."
  (let* ((names (%alist-get :names identity-section))
         (first-name (%alist-get :first names))
         (last-name (%alist-get :last names))
         (full (%alist-get :full names))
         (nickname (%alist-get :nickname names)))
    (with-output-to-string (s)
      (cond
        ;; first + last
        ((and first-name last-name)
         (format s "- **Name:** ~A~%" first-name)
         (format s "- **Full Name:** ~A ~A~%" first-name last-name))
        ;; first only
        (first-name
         (format s "- **Name:** ~A~%" first-name))
        ;; full only
        (full
         (format s "- **Name:** ~A~%" full)))
      (when nickname
        (format s "- **Nickname:** ~A~%" nickname)))))

(defun %render-identity-section (data)
  "Render the AIEOS identity section to markdown."
  (when data
    (with-output-to-string (s)
      (write-string (%render-name data) s)
      (let ((bio (%alist-get :bio data)))
        (when bio (format s "- **Bio:** ~A~%" bio)))
      (let ((origin (%alist-get :origin data)))
        (when origin (format s "- **Origin:** ~A~%" origin)))
      (let ((residence (%alist-get :residence data)))
        (when residence (format s "- **Residence:** ~A~%" residence))))))

(defun %render-psychology-section (data)
  "Render the AIEOS psychology section to markdown."
  (when data
    (with-output-to-string (s)
      (let ((mbti (%alist-get :mbti data)))
        (when mbti (format s "- **MBTI:** ~A~%" mbti)))
      (let ((ocean (%alist-get :ocean data)))
        (when ocean
          (format s "- **OCEAN Traits:**~%")
          (dolist (trait '(:openness :conscientiousness :extraversion
                          :agreeableness :neuroticism))
            (let ((val (%alist-get trait ocean)))
              (when val
                (format s "  - ~A: ~,2F~%"
                        (string-capitalize (symbol-name trait)) val))))))
      (let ((moral (%alist-get :moral--compass data)))
        (when (and moral (listp moral))
          (format s "- **Moral Compass:**~%")
          (dolist (item moral)
            (format s "  - ~A~%" item)))))))

(defun %render-linguistics-section (data)
  "Render the AIEOS linguistics section to markdown."
  (when data
    (with-output-to-string (s)
      (let ((style (%alist-get :style data)))
        (when style (format s "- **Style:** ~A~%" style)))
      (let ((formality (%alist-get :formality data)))
        (when formality (format s "- **Formality:** ~A~%" formality)))
      (let ((phrases (%alist-get :catchphrases data)))
        (when (and phrases (listp phrases))
          (format s "- **Catchphrases:** ~{\"~A\"~^, ~}~%" phrases)))
      (let ((forbidden (%alist-get :forbidden--words data)))
        (when (and forbidden (listp forbidden))
          (format s "- **Forbidden Words:** ~{~A~^, ~}~%" forbidden))))))

(defun %render-motivations-section (data)
  "Render the AIEOS motivations section to markdown."
  (when data
    (with-output-to-string (s)
      (let ((drive (%alist-get :core--drive data)))
        (when drive (format s "- **Core Drive:** ~A~%" drive)))
      (let ((short-goals (%alist-get :short--term--goals data)))
        (when (and short-goals (listp short-goals))
          (format s "- **Short-term Goals:**~%")
          (dolist (g short-goals) (format s "  - ~A~%" g))))
      (let ((long-goals (%alist-get :long--term--goals data)))
        (when (and long-goals (listp long-goals))
          (format s "- **Long-term Goals:**~%")
          (dolist (g long-goals) (format s "  - ~A~%" g))))
      (let ((fears (%alist-get :fears data)))
        (when (and fears (listp fears))
          (format s "- **Fears:**~%")
          (dolist (f fears) (format s "  - ~A~%" f)))))))

(defun %render-capabilities-section (data)
  "Render the AIEOS capabilities section to markdown."
  (when data
    (with-output-to-string (s)
      (let ((skills (%alist-get :skills data)))
        (when (and skills (listp skills))
          (format s "- **Skills:** ~{~A~^, ~}~%" skills)))
      (let ((tools (%alist-get :tools data)))
        (when (and tools (listp tools))
          (format s "- **Tools:** ~{~A~^, ~}~%" tools))))))

(defun %render-history-section (data)
  "Render the AIEOS history section to markdown."
  (when data
    (with-output-to-string (s)
      (let ((origin (%alist-get :origin--story data)))
        (when origin (format s "- **Origin Story:** ~A~%" origin)))
      (let ((edu (%alist-get :education data)))
        (when (and edu (listp edu))
          (format s "- **Education:** ~{~A~^, ~}~%" edu)))
      (let ((occ (%alist-get :occupation data)))
        (when occ (format s "- **Occupation:** ~A~%" occ))))))

(defun %render-physicality-section (data)
  "Render the AIEOS physicality section to markdown."
  (when data
    (with-output-to-string (s)
      (let ((appearance (%alist-get :appearance data)))
        (when appearance (format s "- **Appearance:** ~A~%" appearance)))
      (let ((avatar (%alist-get :avatar--description data)))
        (when avatar (format s "- **Avatar:** ~A~%" avatar))))))

(defun %render-interests-section (data)
  "Render the AIEOS interests section to markdown."
  (when data
    (with-output-to-string (s)
      (let ((hobbies (%alist-get :hobbies data)))
        (when (and hobbies (listp hobbies))
          (format s "- **Hobbies:** ~{~A~^, ~}~%" hobbies)))
      (let ((lifestyle (%alist-get :lifestyle data)))
        (when lifestyle (format s "- **Lifestyle:** ~A~%" lifestyle))))))

(defun %non-empty-string-p (s)
  "Return T if S is a non-empty string."
  (and (stringp s) (> (length s) 0)))

(declaim (ftype (function (list) string) render-aieos))
(defun render-aieos (aieos-alist)
  "Render a parsed AIEOS identity to a markdown prompt string.
   AIEOS-ALIST is the parsed JSON (alist from parse-aieos).
   Returns a trimmed markdown string. An empty identity produces an empty string."
  (let ((sections '()))
    ;; Collect non-empty sections in display order
    (flet ((maybe-add (header data renderer)
             (let ((rendered (when data (funcall renderer data))))
               (when (%non-empty-string-p rendered)
                 (push (cons header rendered) sections)))))
      (maybe-add "Identity"           (%alist-get :identity aieos-alist)     #'%render-identity-section)
      (maybe-add "Personality"        (%alist-get :psychology aieos-alist)   #'%render-psychology-section)
      (maybe-add "Communication Style" (%alist-get :linguistics aieos-alist) #'%render-linguistics-section)
      (maybe-add "Motivations"        (%alist-get :motivations aieos-alist)  #'%render-motivations-section)
      (maybe-add "Capabilities"       (%alist-get :capabilities aieos-alist) #'%render-capabilities-section)
      (maybe-add "Background"         (%alist-get :history aieos-alist)      #'%render-history-section)
      (maybe-add "Appearance"         (%alist-get :physicality aieos-alist)  #'%render-physicality-section)
      (maybe-add "Interests"          (%alist-get :interests aieos-alist)    #'%render-interests-section))
    ;; Build output
    (if (null sections)
        ""
        (string-right-trim
         '(#\Space #\Tab #\Newline #\Return)
         (with-output-to-string (s)
           (dolist (section (nreverse sections))
             (format s "## ~A~%~%~A~%" (car section) (cdr section))))))))
