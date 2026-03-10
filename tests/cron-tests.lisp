(in-package #:nilclaw/tests)
(in-suite cron-suite)

(test cron-runtime-ready
  (is (nilclaw/cron:cron-runtime-ready-p))
  (is (not (nilclaw/cron:cron-runtime-ready-p
            (nilclaw/cron:make-cron-runtime :name "" :enabled t :max-tasks 64))))
  (is (not (nilclaw/cron:cron-runtime-ready-p
            (nilclaw/cron:make-cron-runtime :name "cron" :enabled nil :max-tasks 64)))))
