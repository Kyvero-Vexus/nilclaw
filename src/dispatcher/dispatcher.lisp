(in-package #:nilclaw/dispatcher)

(declaim (optimize (safety 3) (debug 3)))

(defun %trim (s) (string-trim '(#\Space #\Tab #\Newline #\Return) s))

(defun %json-decode-safe (s)
  (handler-case (json:decode-json-from-string s)
    (error () nil)))

(defun %jget (obj key)
  (cond
    ((hash-table-p obj)
     (or (gethash key obj)
         (gethash (intern (string-upcase (string key)) :keyword) obj)
         (gethash (string-downcase (string key)) obj)
         (gethash (string-upcase (string key)) obj)))
    ((listp obj)
     (or (cdr (assoc key obj))
         (cdr (assoc (intern (string-upcase (string key)) :keyword) obj))
         (cdr (assoc (string-downcase (string key)) obj :test #'string=))
         (cdr (assoc (string-upcase (string key)) obj :test #'string=))))
    (t nil)))

(defun extract-json-object (text)
  (let* ((obj-pos (position #\{ text))
         (arr-pos (position #\[ text))
         (start (cond ((and obj-pos arr-pos) (min obj-pos arr-pos))
                      (obj-pos obj-pos)
                      (arr-pos arr-pos)
                      (t nil))))
    (when start
      (let ((open (char text start))
            (close (if (char= (char text start) #\{) #\} #\]))
            (depth 0)
            (in-string nil)
            (escape nil))
        (loop for i from start below (length text)
              for ch = (char text i)
              do (cond
                   (escape (setf escape nil))
                   ((char= ch #\\) (setf escape t))
                   ((char= ch #\") (setf in-string (not in-string)))
                   ((not in-string)
                    (when (char= ch open) (incf depth))
                    (when (char= ch close)
                      (decf depth)
                      (when (= depth 0)
                        (return (subseq text start (1+ i))))))))))))

(defun parse-function-tag (s)
  (let ((fname (nth-value 1 (cl-ppcre:scan-to-strings "<function=([^>]+)>" s))))
    (unless fname (error "NoFunctionTag"))
    (let ((name (aref fname 0)))
      (when (or (search " " name) (search "\"" name) (search "<" name))
        (error "InvalidFunctionName"))
      (let ((pairs '()))
        (cl-ppcre:do-register-groups (k v)
            ("<parameter=([^>]+)>(.*?)</parameter>" s)
          (push (cons k v) pairs))
        (let ((json-parts
                (mapcar (lambda (pair)
                          (format nil "\"~A\":~A" (car pair) (json:encode-json-to-string (cdr pair))))
                        (nreverse pairs))))
          (make-tool-call :name name
                          :arguments-json (format nil "{~{~A~^,~}}" json-parts)))))))

(defun %parse-tool-call-payload (payload)
  (let* ((clean (%trim payload))
         (fenced (nth-value 1 (cl-ppcre:scan-to-strings "```json\\s*(.*?)\\s*```" clean))))
    (when fenced (setf clean (aref fenced 0)))
    (let ((obj (extract-json-object clean)))
      (cond
        ((and obj (%json-decode-safe obj))
         (let* ((decoded (%json-decode-safe obj))
                (name (%jget decoded :name))
                (arguments (or (%jget decoded :arguments) (make-hash-table)))
                (arg-json (if (hash-table-p arguments)
                              (json:encode-json-to-string arguments)
                              (json:encode-json-to-string arguments))))
           (when name
             (make-tool-call :name name :arguments-json arg-json))))
        ((cl-ppcre:scan "<function=" clean)
         (parse-function-tag clean))
        ((cl-ppcre:scan "^[a-zA-Z0-9_.-]+\\s*\\{" clean)
         (let* ((p (position #\{ clean))
                (name (%trim (subseq clean 0 p)))
                (args (subseq clean p)))
           (when (%json-decode-safe args)
             (make-tool-call :name name :arguments-json args))))
        (t nil)))))

(defun parse-xml-tool-calls (text)
  (let ((calls '())
        (remaining text))
    (cl-ppcre:do-register-groups (body)
        ("<tool_call>([\\s\\S]*?)</tool_call>" text)
      (let ((call (%parse-tool-call-payload body)))
        (when call (push call calls))))
    ;; compact malformed close or unclosed fallback
    (unless calls
      (let ((idx (search "<tool_call>" text)))
        (when idx
          (let* ((payload (subseq text (+ idx (length "<tool_call>"))))
                 (end (or (search "</arg_value>" payload)
                          (search "</tool_call>" payload)
                          (length payload)))
                 (snippet (subseq payload 0 end))
                 (call (%parse-tool-call-payload snippet)))
            (when call (push call calls))))))
    (values (nreverse calls)
            (cl-ppcre:regex-replace-all "<tool_call>[\\s\\S]*?</tool_call>" remaining ""))))

(defun parse-tool-calls (text)
  (parse-xml-tool-calls text))

(defun is-native-json-format (text)
  (let ((t1 (%trim text)))
    (and (> (length t1) 1)
         (char= (char t1 0) #\{)
         (not (null (%json-decode-safe t1))))))

(defun is-native-format (text)
  (and (is-native-json-format text)
       (search "\"tool_calls\"" text)))

(defun contains-tool-call-markup (text)
  (or (search "<tool_call>" text)
      (cl-ppcre:scan "(?i)\\[/?tool_call\\]" text)))

(defun parse-native-tool-calls (text)
  (if (not (is-native-json-format text))
      (values '() text)
      (let* ((decoded (%json-decode-safe text))
             (content (or (%jget decoded :content) ""))
             (tool-calls (%jget decoded :tool_calls))
             (calls '()))
        (dolist (entry (if (vectorp tool-calls) (coerce tool-calls 'list) tool-calls))
          (let* ((id (%jget entry :id))
                 (function (%jget entry :function))
                 (name (and function (%jget function :name)))
                 (args (and function (%jget function :arguments))))
            (when (and name (> (length name) 0))
              (push (make-tool-call :name name
                                    :arguments-json (if (stringp args) args (json:encode-json-to-string args))
                                    :id id)
                    calls))))
        (values (nreverse calls) (if (null content) "" content)))))

(defun format-tool-results (results)
  (if (null results)
      "<tool_results>Tool results: none</tool_results>"
      (with-output-to-string (s)
        (dolist (r results)
          (destructuring-bind (&key name output success tool-call-id) r
            (format s "<tool_result><name>~A</name><tool_call_id>~A</tool_call_id><status>~A</status><output>~A</output></tool_result>"
                    name (or tool-call-id "") (if success "ok" "error") output))))))

(defun format-native-tool-results (results)
  (if (null results)
      "[]"
      (json:encode-json-to-string
       (mapcar (lambda (r)
                 (destructuring-bind (&key output tool-call-id) r
                   `((:role . "tool")
                     (:tool_call_id . ,(or tool-call-id "unknown"))
                     (:content . ,(or output "")))))
               results))))

(defun repair-json (s)
  (or (extract-json-object s) s))

(defun build-tool-instructions ()
  "Respond with <tool_call>{\"name\":...,\"arguments\":{...}}</tool_call> when calling tools.")

(defun build-assistant-history-with-tool-calls (messages tool-results)
  (append messages
          (mapcar (lambda (r)
                    `((:role . "tool") (:content . ,r)))
                  tool-results)))
