(in-package #:nilclaw/dispatcher)

(declaim (optimize (safety 3) (debug 3)))

;;; Tool execution runtime — L2 capability closure
;;; Provides registration, dispatch, sandboxed execution, and result plumbing.

(defstruct tool-definition
  "A registered tool available for agent invocation."
  (name "" :type string)
  (description "" :type string)
  (parameters-schema nil :type list)
  (handler nil :type (or null function))
  (risk-level :low :type keyword))

(defstruct tool-execution-result
  "Result of executing a single tool call."
  (tool-call-id nil :type (or null string))
  (name "" :type string)
  (output "" :type string)
  (success-p t :type boolean)
  (error-code nil :type (or null keyword))
  (duration-ms 0 :type (integer 0 *)))

(defstruct tool-registry
  "Registry of available tools for an agent session."
  (tools (make-hash-table :test 'equal) :type hash-table)
  (max-iterations 1000 :type (integer 1 *))
  (current-iteration 0 :type (integer 0 *)))

(declaim (ftype (function () tool-registry) make-default-tool-registry))
(defun make-default-tool-registry ()
  (make-tool-registry))

(declaim (ftype (function (tool-registry tool-definition) tool-definition) register-tool))
(defun register-tool (registry definition)
  "Register a tool definition in the registry."
  (declare (type tool-registry registry)
           (type tool-definition definition))
  (setf (gethash (tool-definition-name definition)
                 (tool-registry-tools registry))
        definition)
  definition)

(declaim (ftype (function (tool-registry string) (or null tool-definition)) lookup-tool))
(defun lookup-tool (registry name)
  "Look up a tool by name. Returns nil if not registered."
  (declare (type tool-registry registry)
           (type string name))
  (gethash name (tool-registry-tools registry)))

(declaim (ftype (function (tool-registry) list) list-tools))
(defun list-tools (registry)
  "Return a list of all registered tool definitions."
  (declare (type tool-registry registry))
  (let ((result '()))
    (maphash (lambda (k v)
               (declare (ignore k))
               (push v result))
             (tool-registry-tools registry))
    (nreverse result)))

(declaim (ftype (function (tool-registry) (integer 0 *)) tool-count))
(defun tool-count (registry)
  "Return the number of registered tools."
  (declare (type tool-registry registry))
  (hash-table-count (tool-registry-tools registry)))

(declaim (ftype (function (tool-registry) boolean) iteration-limit-reached-p))
(defun iteration-limit-reached-p (registry)
  "Check if the tool iteration limit has been reached."
  (declare (type tool-registry registry))
  (>= (tool-registry-current-iteration registry)
      (tool-registry-max-iterations registry)))

(declaim (ftype (function (tool-registry tool-call) tool-execution-result) execute-tool-call))
(defun execute-tool-call (registry call)
  "Execute a single tool call against the registry.
Returns a tool-execution-result with success/failure status."
  (declare (type tool-registry registry)
           (type tool-call call))
  (let ((name (tool-call-name call))
        (id (tool-call-id call)))
    ;; Check iteration limit
    (when (iteration-limit-reached-p registry)
      (return-from execute-tool-call
        (make-tool-execution-result
         :tool-call-id id
         :name name
         :output "Tool iteration limit reached"
         :success-p nil
         :error-code :iteration-limit)))
    ;; Increment iteration counter
    (incf (tool-registry-current-iteration registry))
    ;; Look up tool
    (let ((definition (lookup-tool registry name)))
      (unless definition
        (return-from execute-tool-call
          (make-tool-execution-result
           :tool-call-id id
           :name name
           :output (format nil "Unknown tool: ~A" name)
           :success-p nil
           :error-code :unknown-tool)))
      ;; Execute handler
      (let ((handler (tool-definition-handler definition)))
        (unless handler
          (return-from execute-tool-call
            (make-tool-execution-result
             :tool-call-id id
             :name name
             :output (format nil "Tool ~A has no handler" name)
             :success-p nil
             :error-code :no-handler)))
        ;; Run with error protection
        (let ((start-time (get-internal-real-time)))
          (handler-case
              (let ((output (funcall handler (tool-call-arguments-json call))))
                (make-tool-execution-result
                 :tool-call-id id
                 :name name
                 :output (or output "")
                 :success-p t
                 :error-code nil
                 :duration-ms (round (* 1000
                                        (/ (- (get-internal-real-time) start-time)
                                           internal-time-units-per-second)))))
            (error (e)
              (make-tool-execution-result
               :tool-call-id id
               :name name
               :output (format nil "Tool error: ~A" e)
               :success-p nil
               :error-code :execution-error
               :duration-ms (round (* 1000
                                      (/ (- (get-internal-real-time) start-time)
                                         internal-time-units-per-second)))))))))))

(declaim (ftype (function (tool-registry list) list) execute-tool-calls))
(defun execute-tool-calls (registry calls)
  "Execute a list of tool calls sequentially. Returns list of results."
  (declare (type tool-registry registry)
           (type list calls))
  (mapcar (lambda (call) (execute-tool-call registry call)) calls))

(declaim (ftype (function (list) list) results-to-plumbing))
(defun results-to-plumbing (results)
  "Convert tool-execution-results to the format expected by format-tool-results."
  (declare (type list results))
  (mapcar (lambda (r)
            (list :name (tool-execution-result-name r)
                  :output (tool-execution-result-output r)
                  :success (tool-execution-result-success-p r)
                  :tool-call-id (tool-execution-result-tool-call-id r)))
          results))
