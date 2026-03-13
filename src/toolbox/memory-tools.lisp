(in-package #:nilclaw/toolbox)

(declaim (optimize (safety 3) (debug 3)))

;;; ---------------------------------------------------------------------------
;;; Memory Tools — persistent key-value storage with recall
;;; ---------------------------------------------------------------------------

(defun %memory-store-handler (args-json backend)
  "Handler implementation for the memory_store tool."
  (unless backend
    (return-from %memory-store-handler "Error: memory backend not configured"))
  (let* ((args (%json-args args-json))
         (key (%arg args :key))
         (content (%arg args :content))
         (category (or (%arg args :category) "core")))
    (unless key
      (return-from %memory-store-handler "Error: missing required parameter 'key'"))
    (unless content
      (return-from %memory-store-handler "Error: missing required parameter 'content'"))
    (handler-case
        (progn
          (nilclaw/memory:memory-store backend key content category)
          (format nil "Stored memory: ~A (category: ~A)" key category))
      (error (e)
        (format nil "Error storing memory: ~A" e)))))

(declaim (ftype (function (toolbox) nilclaw/dispatcher:tool-definition) make-memory-store-tool))
(defun make-memory-store-tool (toolbox)
  "Create the memory_store tool definition."
  (declare (type toolbox toolbox))
  (let ((backend (toolbox-memory-backend toolbox)))
    (nilclaw/dispatcher:make-tool-definition
     :name "memory_store"
     :description "Store a key-value pair in persistent memory.
Use this to remember important context, user preferences, decisions, and facts
that should persist across conversations. Choose descriptive keys.
Categories help organize memories: 'core' (default), 'user', 'project', 'decision'."
     :parameters-schema
     '((:type . "object")
       (:properties
        . ((:key . ((:type . "string")
                    (:description . "A descriptive key for the memory entry")))
           (:content . ((:type . "string")
                        (:description . "The content to store")))
           (:category . ((:type . "string")
                         (:description . "Category: core, user, project, decision (default: core)")))))
       (:required . ("key" "content")))
     :handler (lambda (args-json)
                (%memory-store-handler args-json backend))
     :risk-level :low)))

(defun %memory-recall-handler (args-json backend)
  "Handler implementation for the memory_recall tool."
  (unless backend
    (return-from %memory-recall-handler "Error: memory backend not configured"))
  (let* ((args (%json-args args-json))
         (query (%arg args :query))
         (limit (or (%arg args :limit) 10)))
    (unless query
      (return-from %memory-recall-handler "Error: missing required parameter 'query'"))
    (handler-case
        (let ((entries (nilclaw/memory:memory-recall backend query limit)))
          (if (null entries)
              "No matching memories found."
              (with-output-to-string (s)
                (format s "Found ~D memor~:@P:~%" (length entries))
                (dolist (entry entries)
                  (format s "~%- **~A** (~A): ~A"
                          (nilclaw/memory:memory-entry-key entry)
                          (nilclaw/memory:memory-entry-category entry)
                          (nilclaw/memory:memory-entry-content entry))))))
      (error (e)
        (format nil "Error recalling memory: ~A" e)))))

(declaim (ftype (function (toolbox) nilclaw/dispatcher:tool-definition) make-memory-recall-tool))
(defun make-memory-recall-tool (toolbox)
  "Create the memory_recall tool definition."
  (declare (type toolbox toolbox))
  (let ((backend (toolbox-memory-backend toolbox)))
    (nilclaw/dispatcher:make-tool-definition
     :name "memory_recall"
     :description "Search persistent memory by query. Returns matching entries ranked by relevance.
Use this before asking the user to repeat information — check memory first."
     :parameters-schema
     '((:type . "object")
       (:properties
        . ((:query . ((:type . "string")
                      (:description . "Search query to find relevant memories")))
           (:limit . ((:type . "number")
                      (:description . "Maximum number of results (default: 10)")))))
       (:required . ("query")))
     :handler (lambda (args-json)
                (%memory-recall-handler args-json backend))
     :risk-level :low)))

(defun %memory-list-handler (args-json backend)
  "Handler implementation for the memory_list tool."
  (unless backend
    (return-from %memory-list-handler "Error: memory backend not configured"))
  (let* ((args (%json-args args-json))
         (category (%arg args :category)))
    (handler-case
        (let ((entries (nilclaw/memory:memory-list backend category)))
          (if (null entries)
              (if category
                  (format nil "No memories in category '~A'." category)
                  "No memories stored yet.")
              (with-output-to-string (s)
                (format s "~D memor~:@P stored:~%" (length entries))
                (dolist (entry entries)
                  (format s "~%- **~A** (~A): ~A"
                          (nilclaw/memory:memory-entry-key entry)
                          (nilclaw/memory:memory-entry-category entry)
                          (nilclaw/memory:memory-entry-content entry))))))
      (error (e)
        (format nil "Error listing memory: ~A" e)))))

(declaim (ftype (function (toolbox) nilclaw/dispatcher:tool-definition) make-memory-list-tool))
(defun make-memory-list-tool (toolbox)
  "Create the memory_list tool definition."
  (declare (type toolbox toolbox))
  (let ((backend (toolbox-memory-backend toolbox)))
    (nilclaw/dispatcher:make-tool-definition
     :name "memory_list"
     :description "List all stored memory entries, optionally filtered by category.
Use this to see what you've remembered."
     :parameters-schema
     '((:type . "object")
       (:properties
        . ((:category . ((:type . "string")
                         (:description . "Optional category filter"))))))
     :handler (lambda (args-json)
                (%memory-list-handler args-json backend))
     :risk-level :low)))

(defun %memory-forget-handler (args-json backend)
  "Handler implementation for the memory_forget tool."
  (unless backend
    (return-from %memory-forget-handler "Error: memory backend not configured"))
  (let* ((args (%json-args args-json))
         (key (%arg args :key)))
    (unless key
      (return-from %memory-forget-handler "Error: missing required parameter 'key'"))
    (handler-case
        (progn
          (nilclaw/memory:memory-forget backend key)
          (format nil "Forgot memory: ~A" key))
      (error (e)
        (format nil "Error forgetting memory: ~A" e)))))

(declaim (ftype (function (toolbox) nilclaw/dispatcher:tool-definition) make-memory-forget-tool))
(defun make-memory-forget-tool (toolbox)
  "Create the memory_forget tool definition."
  (declare (type toolbox toolbox))
  (let ((backend (toolbox-memory-backend toolbox)))
    (nilclaw/dispatcher:make-tool-definition
     :name "memory_forget"
     :description "Delete a memory entry by key.
Use this to remove outdated or incorrect memories."
     :parameters-schema
     '((:type . "object")
       (:properties
        . ((:key . ((:type . "string")
                    (:description . "The key of the memory entry to delete")))))
       (:required . ("key")))
     :handler (lambda (args-json)
                (%memory-forget-handler args-json backend))
     :risk-level :low)))
