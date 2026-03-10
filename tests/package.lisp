(defpackage #:nilclaw/tests
  (:use #:cl #:fiveam)
  (:export #:run-nilclaw-tests))

(in-package #:nilclaw/tests)

(def-suite nilclaw-suite
  :description "NilClaw test suite")

(def-suite config-suite
  :description "Config module tests"
  :in nilclaw-suite)

(def-suite security-policy-suite
  :description "Security policy module tests"
  :in nilclaw-suite)

(def-suite memory-contract-suite
  :description "Memory contract module tests"
  :in nilclaw-suite)

(def-suite agent-dispatcher-suite
  :description "Agent dispatcher module tests"
  :in nilclaw-suite)

(def-suite memory-sqlite-suite
  :description "Memory SQLite module tests"
  :in nilclaw-suite)

(def-suite providers-compatible-suite
  :description "Providers compatible module tests"
  :in nilclaw-suite)

(def-suite skills-suite
  :description "Skills module tests"
  :in nilclaw-suite)

(def-suite bootstrap-suite
  :description "Bootstrap module tests"
  :in nilclaw-suite)

(def-suite cron-suite
  :description "Cron module tests"
  :in nilclaw-suite)

(def-suite gateway-suite
  :description "Gateway module tests"
  :in nilclaw-suite)

(def-suite agent-root-suite
  :description "Agent root module tests"
  :in nilclaw-suite)

(def-suite traceability-linkage-suite
  :description "Traceability linkage tests"
  :in nilclaw-suite)

(defun run-nilclaw-tests ()
  "Run all NilClaw tests and return results."
  (run! 'nilclaw-suite))
