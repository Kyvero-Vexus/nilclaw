(in-package #:nilclaw/tests)

(def-suite tool-executor-suite :in nilclaw-suite)
(in-suite tool-executor-suite)

(test tool-registry-basics
  "Registry supports registration, lookup, listing, and counting."
  (let ((registry (nilclaw/dispatcher:make-default-tool-registry)))
    (is (= 0 (nilclaw/dispatcher:tool-count registry)))
    ;; Register a tool
    (nilclaw/dispatcher:register-tool
     registry
     (nilclaw/dispatcher:make-tool-definition
      :name "read"
      :description "Read a file"
      :handler (lambda (args) (declare (ignore args)) "file contents")))
    (is (= 1 (nilclaw/dispatcher:tool-count registry)))
    ;; Lookup
    (let ((found (nilclaw/dispatcher:lookup-tool registry "read")))
      (is (not (null found)))
      (is (string= "read" (nilclaw/dispatcher:tool-definition-name found))))
    ;; Unknown lookup
    (is (null (nilclaw/dispatcher:lookup-tool registry "nonexistent")))
    ;; List
    (let ((all (nilclaw/dispatcher:list-tools registry)))
      (is (= 1 (length all))))))

(test tool-execution-success
  "Executing a registered tool with a handler returns success."
  (let ((registry (nilclaw/dispatcher:make-default-tool-registry)))
    (nilclaw/dispatcher:register-tool
     registry
     (nilclaw/dispatcher:make-tool-definition
      :name "echo"
      :handler (lambda (args) (format nil "echoed: ~A" args))))
    (let* ((call (nilclaw/dispatcher:make-tool-call :name "echo" :arguments-json "{\"text\":\"hello\"}" :id "tc-1"))
           (result (nilclaw/dispatcher:execute-tool-call registry call)))
      (is (nilclaw/dispatcher:tool-execution-result-success-p result))
      (is (string= "tc-1" (nilclaw/dispatcher:tool-execution-result-tool-call-id result)))
      (is (string= "echo" (nilclaw/dispatcher:tool-execution-result-name result)))
      (is (search "echoed:" (nilclaw/dispatcher:tool-execution-result-output result)))
      (is (null (nilclaw/dispatcher:tool-execution-result-error-code result)))
      (is (>= (nilclaw/dispatcher:tool-execution-result-duration-ms result) 0)))))

(test tool-execution-unknown-tool
  "Executing an unregistered tool returns :unknown-tool error."
  (let* ((registry (nilclaw/dispatcher:make-default-tool-registry))
         (call (nilclaw/dispatcher:make-tool-call :name "missing" :arguments-json "{}"))
         (result (nilclaw/dispatcher:execute-tool-call registry call)))
    (is (not (nilclaw/dispatcher:tool-execution-result-success-p result)))
    (is (eq :unknown-tool (nilclaw/dispatcher:tool-execution-result-error-code result)))))

(test tool-execution-no-handler
  "A tool with no handler returns :no-handler error."
  (let ((registry (nilclaw/dispatcher:make-default-tool-registry)))
    (nilclaw/dispatcher:register-tool
     registry
     (nilclaw/dispatcher:make-tool-definition :name "stub" :handler nil))
    (let* ((call (nilclaw/dispatcher:make-tool-call :name "stub" :arguments-json "{}"))
           (result (nilclaw/dispatcher:execute-tool-call registry call)))
      (is (not (nilclaw/dispatcher:tool-execution-result-success-p result)))
      (is (eq :no-handler (nilclaw/dispatcher:tool-execution-result-error-code result))))))

(test tool-execution-handler-error
  "A handler that signals an error returns :execution-error."
  (let ((registry (nilclaw/dispatcher:make-default-tool-registry)))
    (nilclaw/dispatcher:register-tool
     registry
     (nilclaw/dispatcher:make-tool-definition
      :name "boom"
      :handler (lambda (args) (declare (ignore args)) (error "kaboom"))))
    (let* ((call (nilclaw/dispatcher:make-tool-call :name "boom" :arguments-json "{}"))
           (result (nilclaw/dispatcher:execute-tool-call registry call)))
      (is (not (nilclaw/dispatcher:tool-execution-result-success-p result)))
      (is (eq :execution-error (nilclaw/dispatcher:tool-execution-result-error-code result)))
      (is (search "kaboom" (nilclaw/dispatcher:tool-execution-result-output result))))))

(test tool-execution-iteration-limit
  "Execution stops after iteration limit is reached."
  (let ((registry (nilclaw/dispatcher:make-tool-registry :max-iterations 2)))
    (nilclaw/dispatcher:register-tool
     registry
     (nilclaw/dispatcher:make-tool-definition
      :name "tick"
      :handler (lambda (args) (declare (ignore args)) "ok")))
    (let ((call (nilclaw/dispatcher:make-tool-call :name "tick" :arguments-json "{}")))
      ;; First two should succeed
      (is (nilclaw/dispatcher:tool-execution-result-success-p
           (nilclaw/dispatcher:execute-tool-call registry call)))
      (is (nilclaw/dispatcher:tool-execution-result-success-p
           (nilclaw/dispatcher:execute-tool-call registry call)))
      ;; Third should hit limit
      (let ((result (nilclaw/dispatcher:execute-tool-call registry call)))
        (is (not (nilclaw/dispatcher:tool-execution-result-success-p result)))
        (is (eq :iteration-limit (nilclaw/dispatcher:tool-execution-result-error-code result)))))))

(test tool-execute-batch-and-plumbing
  "execute-tool-calls processes a list and results-to-plumbing formats them."
  (let ((registry (nilclaw/dispatcher:make-default-tool-registry)))
    (nilclaw/dispatcher:register-tool
     registry
     (nilclaw/dispatcher:make-tool-definition
      :name "greet"
      :handler (lambda (args) (declare (ignore args)) "hi")))
    (let* ((calls (list (nilclaw/dispatcher:make-tool-call :name "greet" :arguments-json "{}" :id "c1")
                        (nilclaw/dispatcher:make-tool-call :name "missing" :arguments-json "{}" :id "c2")))
           (results (nilclaw/dispatcher:execute-tool-calls registry calls))
           (plumbing (nilclaw/dispatcher:results-to-plumbing results)))
      (is (= 2 (length results)))
      (is (nilclaw/dispatcher:tool-execution-result-success-p (first results)))
      (is (not (nilclaw/dispatcher:tool-execution-result-success-p (second results))))
      (is (= 2 (length plumbing)))
      (is (string= "greet" (getf (first plumbing) :name)))
      (is (string= "hi" (getf (first plumbing) :output))))))
