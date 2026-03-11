(in-package :asdf-user)

(defsystem "nilclaw"
  :description "Common Lisp agent harness — clean-room rewrite inspired by NullClaw"
  :version "0.1.0"
  :author "Chrysolambda"
  :license "AGPL-3.0-or-later"
  :depends-on ("alexandria" "cl-json" "cl-ppcre" "uiop")
  :serial t
  :components
  ((:module "src"
    :components
    ((:module "config"
     :components
     ((:file "package")
      (:file "types")
      (:file "parse")
      (:file "validate")
      (:file "serialize")))
     (:module "security"
      :components
      ((:file "package")
       (:file "types")
       (:file "policy")
       (:file "commands")))
     (:module "memory"
      :components
      ((:file "package")
       (:file "contract")
       (:file "none-backend")
       (:file "markdown-backend")
       (:file "lru-backend")))
     (:module "dispatcher"
      :components
      ((:file "package")
       (:file "types")
       (:file "xml-parser")
       (:file "native-parser")
       (:file "function-tag-parser")
       (:file "json-repair")
       (:file "json-extract")
       (:file "format-results")
       (:file "dispatcher")
       (:file "executor")))
     (:module "provider"
      :components
      ((:file "package")
       (:file "types")
       (:file "compatible")))
     (:module "skills"
      :components
      ((:file "package")
       (:file "types")
       (:file "registry")))
     (:module "bootstrap"
      :components
      ((:file "package")
       (:file "bootstrap")))
     (:module "cron"
      :components
      ((:file "package")
       (:file "types")
       (:file "scheduler")))
     (:module "gateway"
      :components
      ((:file "package")
       (:file "types")
       (:file "gateway")))
     (:module "agent"
      :components
      ((:file "package")
       (:file "types")
       (:file "agent")))))))

(defsystem "nilclaw/tests"
  :description "NilClaw test suite"
  :depends-on ("nilclaw" "fiveam")
  :serial t
  :components
  ((:module "tests"
    :components
    ((:file "package")
     (:file "config-tests")
     (:file "security-policy-tests")
     (:file "memory-contract-tests")
     (:file "agent-dispatcher-tests")
     (:file "memory-sqlite-tests")
     (:file "providers-compatible-tests")
     (:file "skills-tests")
     (:file "bootstrap-tests")
     (:file "cron-tests")
     (:file "gateway-tests")
     (:file "agent-root-tests")
     (:file "traceability-linkage-tests")
     (:file "e2e-smoke-tests")
     (:file "tool-executor-tests")))))
