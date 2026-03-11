(in-package #:nilclaw/tests)

(def-suite subagent-suite :in nilclaw-suite)
(in-suite subagent-suite)

(test subagent-manager-creation
  "Manager can be created with default config."
  (let ((mgr (nilclaw/subagent:make-default-subagent-manager)))
    (is (typep mgr 'nilclaw/subagent:subagent-manager))
    (is (= 0 (nilclaw/subagent:running-count mgr)))
    (is (nilclaw/subagent:concurrency-available-p mgr))))

(test spawn-task-creates-state
  "Spawning a task creates and stores task state."
  (let ((mgr (nilclaw/subagent:make-default-subagent-manager)))
    (multiple-value-bind (task-id state)
        (nilclaw/subagent:spawn-task mgr "test task" :label "test" :session-key "sess-1")
      (is (>= task-id 1))
      (is (typep state 'nilclaw/subagent:task-state))
      (is (eq :running (nilclaw/subagent:task-state-status state)))
      (is (string= "test" (nilclaw/subagent:task-state-label state)))
      (is (string= "sess-1" (nilclaw/subagent:task-state-session-key state)))
      (is (> (nilclaw/subagent:task-state-started-at state) 0)))))

(test get-task-retrieves-state
  "get-task returns the task state by ID."
  (let ((mgr (nilclaw/subagent:make-default-subagent-manager)))
    (multiple-value-bind (task-id state)
        (nilclaw/subagent:spawn-task mgr "task")
      (let ((retrieved (nilclaw/subagent:get-task mgr task-id)))
        (is (eq state retrieved))))))

(test complete-task-updates-state
  "complete-task sets status and result."
  (let ((mgr (nilclaw/subagent:make-default-subagent-manager)))
    (multiple-value-bind (task-id state)
        (nilclaw/subagent:spawn-task mgr "task")
      (declare (ignore state))
      (let ((completed (nilclaw/subagent:complete-task mgr task-id "done")))
        (is (eq :completed (nilclaw/subagent:task-state-status completed)))
        (is (string= "done" (nilclaw/subagent:task-state-result completed)))
        (is (not (null (nilclaw/subagent:task-state-completed-at completed))))))))

(test fail-task-updates-state
  "fail-task sets status and error message."
  (let ((mgr (nilclaw/subagent:make-default-subagent-manager)))
    (multiple-value-bind (task-id state)
        (nilclaw/subagent:spawn-task mgr "task")
      (declare (ignore state))
      (let ((failed (nilclaw/subagent:fail-task mgr task-id "oops")))
        (is (eq :failed (nilclaw/subagent:task-state-status failed)))
        (is (string= "oops" (nilclaw/subagent:task-state-error-msg failed)))
        (is (not (null (nilclaw/subagent:task-state-completed-at failed))))))))

(test concurrency-limit-enforced
  "Spawn fails when concurrency limit is reached."
  (let ((mgr (nilclaw/subagent:make-subagent-manager
              :config (nilclaw/subagent:make-subagent-config :max-concurrent 2))))
    ;; Spawn up to limit
    (nilclaw/subagent:spawn-task mgr "task 1")
    (nilclaw/subagent:spawn-task mgr "task 2")
    (is (= 2 (nilclaw/subagent:running-count mgr)))
    (is (not (nilclaw/subagent:concurrency-available-p mgr)))
    ;; Third spawn should fail
    (handler-case
        (progn
          (nilclaw/subagent:spawn-task mgr "task 3")
          (fail "expected concurrency-limit-exceeded"))
      (nilclaw/subagent:concurrency-limit-exceeded (e)
        (is (= 2 (nilclaw/subagent:concurrency-limit-max e)))))))

(test complete-reduces-running-count
  "Completing a task reduces running count."
  (let ((mgr (nilclaw/subagent:make-subagent-manager
              :config (nilclaw/subagent:make-subagent-config :max-concurrent 2))))
    (multiple-value-bind (id1 state1)
        (nilclaw/subagent:spawn-task mgr "task 1")
      (declare (ignore state1))
      (nilclaw/subagent:spawn-task mgr "task 2")
      (is (= 2 (nilclaw/subagent:running-count mgr)))
      (nilclaw/subagent:complete-task mgr id1 "done")
      (is (= 1 (nilclaw/subagent:running-count mgr)))
      (is (nilclaw/subagent:concurrency-available-p mgr)))))

(test list-tasks-returns-all
  "list-tasks returns all task states."
  (let ((mgr (nilclaw/subagent:make-default-subagent-manager)))
    (nilclaw/subagent:spawn-task mgr "task 1")
    (nilclaw/subagent:spawn-task mgr "task 2")
    (let ((tasks (nilclaw/subagent:list-tasks mgr)))
      (is (= 2 (length tasks)))
      (dolist (tstate tasks)
        (is (typep tstate 'nilclaw/subagent:task-state))))))

(test unknown-task-error
  "complete-task/fail-task error on unknown ID."
  (let ((mgr (nilclaw/subagent:make-default-subagent-manager)))
    (handler-case
        (progn
          (nilclaw/subagent:complete-task mgr 999 "result")
          (fail "expected unknown-task"))
      (nilclaw/subagent:unknown-task (e)
        (is (= 999 (nilclaw/subagent:unknown-task-id e)))))))
