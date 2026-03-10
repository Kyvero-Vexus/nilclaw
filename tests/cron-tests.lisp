(in-package #:nilclaw/tests)
(in-suite cron-suite)

(test cron-runtime-ready
  (is (nilclaw/cron:cron-runtime-ready-p))
  (is (not (nilclaw/cron:cron-runtime-ready-p
            (nilclaw/cron:make-cron-runtime :name "" :enabled t :max-tasks 64))))
  (is (not (nilclaw/cron:cron-runtime-ready-p
            (nilclaw/cron:make-cron-runtime :name "cron" :enabled nil :max-tasks 64)))))

(test cron-run-due-tasks-behavior
  (let* ((runtime (nilclaw/cron:make-cron-runtime :max-retries 1))
         (tasks (list (nilclaw/cron:make-cron-task :id "done" :due-at 5 :payload :a)
                      (nilclaw/cron:make-cron-task :id "retry" :due-at 5 :payload :b)
                      (nilclaw/cron:make-cron-task :id "future" :due-at 50 :payload :c)))
         (pass1 (nilclaw/cron:cron-run-due-tasks
                 runtime
                 tasks
                 10
                 (lambda (task)
                   (cond
                     ((string= "done" (nilclaw/cron:cron-task-id task)) (values t nil))
                     ((string= "retry" (nilclaw/cron:cron-task-id task)) (values nil :timeout))
                     (t (values t nil))))))
         (retry-task (second pass1))
         (pass2 (nilclaw/cron:cron-run-due-tasks
                 runtime
                 pass1
                 10
                 (lambda (task)
                   (if (string= "retry" (nilclaw/cron:cron-task-id task))
                       (values nil :network-fault)
                     (values t nil)))))
         (failed-retry (second pass2)))
    (is (eq :completed (nilclaw/cron:cron-task-status (first pass1))))
    (is (eq :pending (nilclaw/cron:cron-task-status retry-task)))
    (is (= 1 (nilclaw/cron:cron-task-attempts retry-task)))
    (is (eq :failed (nilclaw/cron:cron-task-status failed-retry)))
    (is (= 2 (nilclaw/cron:cron-task-attempts failed-retry)))
    (is (eq :network-fault (nilclaw/cron:cron-task-last-error failed-retry)))
    (is (eq :pending (nilclaw/cron:cron-task-status (third pass2))))))