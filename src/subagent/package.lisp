(defpackage #:nilclaw/subagent
  (:use #:cl)
  (:export
   ;; Types
   #:task-state
   #:make-task-state
   #:task-state-status
   #:task-state-label
   #:task-state-session-key
   #:task-state-result
   #:task-state-error-msg
   #:task-state-started-at
   #:task-state-completed-at
   #:task-state-thread
   #:task-status
   #:subagent-config
   #:make-subagent-config
   #:subagent-config-max-iterations
   #:subagent-config-max-concurrent
   #:subagent-manager
   #:make-subagent-manager
   ;; API
   #:make-default-subagent-manager
   #:spawn-task
   #:get-task
   #:list-tasks
   #:complete-task
   #:fail-task
   #:running-count
   #:concurrency-available-p
   ;; Conditions
   #:concurrency-limit-exceeded
   #:concurrency-limit-max
   #:unknown-task
   #:unknown-task-id))
