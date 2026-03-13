(in-package #:nilclaw/tests)

(def-suite toolbox-suite :in nilclaw-suite)
(in-suite toolbox-suite)

;;; ---------------------------------------------------------------------------
;;; Identity & System Prompt
;;; ---------------------------------------------------------------------------

(test identity-contains-nilclaw-description
  "build-nilclaw-identity includes NilClaw description."
  (let ((identity (nilclaw/toolbox:build-nilclaw-identity)))
    (is (search "NilClaw" identity))
    (is (search "Common Lisp" identity))
    (is (search "Tool execution" identity))
    (is (search "Memory system" identity))))

(test identity-includes-workspace-dir
  "build-nilclaw-identity includes workspace directory when provided."
  (let ((identity (nilclaw/toolbox:build-nilclaw-identity :workspace-dir "/home/user/project")))
    (is (search "/home/user/project" identity))
    (is (search "Current Workspace" identity))))

(test identity-includes-model
  "build-nilclaw-identity includes model name when provided."
  (let ((identity (nilclaw/toolbox:build-nilclaw-identity :model "claude-sonnet-4-20250514")))
    (is (search "claude-sonnet-4-20250514" identity))
    (is (search "Runtime" identity))))

(test identity-includes-extra-context
  "build-nilclaw-identity appends extra context."
  (let ((identity (nilclaw/toolbox:build-nilclaw-identity :extra-context "Custom instructions here")))
    (is (search "Custom instructions here" identity))))

(test system-prompt-has-all-sections
  "build-system-prompt includes identity, tools, format, and safety."
  (let* ((toolbox (nilclaw/toolbox:make-toolbox :workspace-dir "/tmp/test"))
         (tools (nilclaw/toolbox:default-tools toolbox))
         (prompt (nilclaw/toolbox:build-system-prompt
                  :workspace-dir "/tmp/test"
                  :tools tools)))
    (is (search "NilClaw" prompt))
    (is (search "Available Tools" prompt))
    (is (search "shell" prompt))
    (is (search "file_read" prompt))
    (is (search "file_write" prompt))
    (is (search "file_edit" prompt))
    (is (search "Tool Call Format" prompt))
    (is (search "<tool_call>" prompt))
    (is (search "Safety Rules" prompt))))

(test system-prompt-native-format
  "build-system-prompt with :native format mentions native function calling."
  (let ((prompt (nilclaw/toolbox:build-system-prompt :tool-format :native)))
    (is (search "native function calling" prompt))
    (is (not (search "<tool_call>" prompt)))))

;;; ---------------------------------------------------------------------------
;;; Toolbox construction
;;; ---------------------------------------------------------------------------

(test toolbox-defaults
  "make-toolbox has sensible defaults."
  (let ((tb (nilclaw/toolbox:make-toolbox)))
    (is (string= "." (nilclaw/toolbox:toolbox-workspace-dir tb)))
    (is (null (nilclaw/toolbox:toolbox-allowed-paths tb)))
    (is (null (nilclaw/toolbox:toolbox-memory-backend tb)))
    (is (= 1048576 (nilclaw/toolbox:toolbox-max-output-bytes tb)))
    (is (= 10485760 (nilclaw/toolbox:toolbox-max-file-size tb)))
    (is (= 60 (nilclaw/toolbox:toolbox-shell-timeout-secs tb)))))

;;; ---------------------------------------------------------------------------
;;; Core tool definitions
;;; ---------------------------------------------------------------------------

(test core-tools-have-names-and-descriptions
  "All core tools have non-empty names and descriptions."
  (let* ((tb (nilclaw/toolbox:make-toolbox :workspace-dir "/tmp"))
         (tools (nilclaw/toolbox:default-tools tb)))
    (is (= 4 (length tools)))
    (dolist (tool tools)
      (is (> (length (nilclaw/dispatcher:tool-definition-name tool)) 0))
      (is (> (length (nilclaw/dispatcher:tool-definition-description tool)) 0))
      (is (not (null (nilclaw/dispatcher:tool-definition-handler tool)))))))

(test core-tool-names
  "Core tools are shell, file_read, file_write, file_edit."
  (let* ((tb (nilclaw/toolbox:make-toolbox))
         (names (mapcar #'nilclaw/dispatcher:tool-definition-name
                        (nilclaw/toolbox:default-tools tb))))
    (is (member "shell" names :test #'string=))
    (is (member "file_read" names :test #'string=))
    (is (member "file_write" names :test #'string=))
    (is (member "file_edit" names :test #'string=))))

(test shell-tool-risk-is-high
  "Shell tool has high risk level."
  (let* ((tb (nilclaw/toolbox:make-toolbox))
         (tool (nilclaw/toolbox:make-shell-tool tb)))
    (is (eq :high (nilclaw/dispatcher:tool-definition-risk-level tool)))))

(test file-tools-risk-levels
  "File read is low risk, write and edit are medium."
  (let ((tb (nilclaw/toolbox:make-toolbox)))
    (is (eq :low (nilclaw/dispatcher:tool-definition-risk-level
                  (nilclaw/toolbox:make-file-read-tool tb))))
    (is (eq :medium (nilclaw/dispatcher:tool-definition-risk-level
                     (nilclaw/toolbox:make-file-write-tool tb))))
    (is (eq :medium (nilclaw/dispatcher:tool-definition-risk-level
                     (nilclaw/toolbox:make-file-edit-tool tb))))))

;;; ---------------------------------------------------------------------------
;;; Shell tool execution
;;; ---------------------------------------------------------------------------

(test shell-tool-executes-command
  "Shell tool can execute a simple command."
  (let* ((tb (nilclaw/toolbox:make-toolbox :workspace-dir "/tmp"))
         (tool (nilclaw/toolbox:make-shell-tool tb))
         (handler (nilclaw/dispatcher:tool-definition-handler tool))
         (result (funcall handler "{\"command\":\"echo hello\"}")))
    (is (search "hello" result))))

(test shell-tool-missing-command
  "Shell tool returns error when command is missing."
  (let* ((tb (nilclaw/toolbox:make-toolbox))
         (tool (nilclaw/toolbox:make-shell-tool tb))
         (handler (nilclaw/dispatcher:tool-definition-handler tool))
         (result (funcall handler "{}")))
    (is (search "Error" result))))

;;; ---------------------------------------------------------------------------
;;; File tool execution
;;; ---------------------------------------------------------------------------

(test file-read-tool-reads-existing-file
  "file_read can read an existing file."
  (let* ((tb (nilclaw/toolbox:make-toolbox :workspace-dir "/tmp"))
         (tool (nilclaw/toolbox:make-file-read-tool tb))
         (handler (nilclaw/dispatcher:tool-definition-handler tool))
         (test-file "/tmp/nilclaw-test-read.txt"))
    ;; Write a test file
    (with-open-file (s test-file :direction :output :if-exists :supersede)
      (write-string "test content here" s))
    (unwind-protect
         (let ((result (funcall handler (format nil "{\"file_path\":\"~A\"}" test-file))))
           (is (search "test content here" result)))
      (ignore-errors (delete-file test-file)))))

(test file-write-tool-creates-file
  "file_write creates a new file."
  (let* ((tb (nilclaw/toolbox:make-toolbox :workspace-dir "/tmp"))
         (tool (nilclaw/toolbox:make-file-write-tool tb))
         (handler (nilclaw/dispatcher:tool-definition-handler tool))
         (test-file "/tmp/nilclaw-test-write.txt"))
    (unwind-protect
         (let ((result (funcall handler
                                (format nil "{\"file_path\":\"~A\",\"content\":\"written by test\"}"
                                        test-file))))
           (is (search "Wrote" result))
           (is (string= "written by test" (uiop:read-file-string test-file))))
      (ignore-errors (delete-file test-file)))))

(test file-edit-tool-replaces-text
  "file_edit finds and replaces text."
  (let* ((tb (nilclaw/toolbox:make-toolbox :workspace-dir "/tmp"))
         (tool (nilclaw/toolbox:make-file-edit-tool tb))
         (handler (nilclaw/dispatcher:tool-definition-handler tool))
         (test-file "/tmp/nilclaw-test-edit.txt"))
    ;; Create test file
    (with-open-file (s test-file :direction :output :if-exists :supersede)
      (write-string "hello world" s))
    (unwind-protect
         (let ((result (funcall handler
                                (format nil "{\"file_path\":\"~A\",\"old_string\":\"hello\",\"new_string\":\"goodbye\"}"
                                        test-file))))
           (is (search "Edited" result))
           (is (string= "goodbye world" (uiop:read-file-string test-file))))
      (ignore-errors (delete-file test-file)))))

(test file-edit-tool-rejects-ambiguous
  "file_edit errors when old_string matches multiple times without replace_all."
  (let* ((tb (nilclaw/toolbox:make-toolbox :workspace-dir "/tmp"))
         (tool (nilclaw/toolbox:make-file-edit-tool tb))
         (handler (nilclaw/dispatcher:tool-definition-handler tool))
         (test-file "/tmp/nilclaw-test-edit-multi.txt"))
    (with-open-file (s test-file :direction :output :if-exists :supersede)
      (write-string "foo bar foo" s))
    (unwind-protect
         (let ((result (funcall handler
                                (format nil "{\"file_path\":\"~A\",\"old_string\":\"foo\",\"new_string\":\"baz\"}"
                                        test-file))))
           (is (search "found 2 times" result)))
      (ignore-errors (delete-file test-file)))))

(test file-edit-tool-replace-all
  "file_edit with replace_all replaces all occurrences."
  (let* ((tb (nilclaw/toolbox:make-toolbox :workspace-dir "/tmp"))
         (tool (nilclaw/toolbox:make-file-edit-tool tb))
         (handler (nilclaw/dispatcher:tool-definition-handler tool))
         (test-file "/tmp/nilclaw-test-edit-all.txt"))
    (with-open-file (s test-file :direction :output :if-exists :supersede)
      (write-string "foo bar foo" s))
    (unwind-protect
         (let ((result (funcall handler
                                (format nil "{\"file_path\":\"~A\",\"old_string\":\"foo\",\"new_string\":\"baz\",\"replace_all\":true}"
                                        test-file))))
           (is (search "replaced 2" result))
           (is (string= "baz bar baz" (uiop:read-file-string test-file))))
      (ignore-errors (delete-file test-file)))))

;;; ---------------------------------------------------------------------------
;;; Memory tool definitions
;;; ---------------------------------------------------------------------------

(test memory-tools-require-backend
  "Memory tools return error when no backend configured."
  (let* ((tb (nilclaw/toolbox:make-toolbox))
         (store (nilclaw/toolbox:make-memory-store-tool tb))
         (handler (nilclaw/dispatcher:tool-definition-handler store))
         (result (funcall handler "{\"key\":\"test\",\"content\":\"data\"}")))
    (is (search "not configured" result))))

(test memory-tool-names
  "Memory tools have correct names."
  (let ((tb (nilclaw/toolbox:make-toolbox)))
    (is (string= "memory_store"
                  (nilclaw/dispatcher:tool-definition-name
                   (nilclaw/toolbox:make-memory-store-tool tb))))
    (is (string= "memory_recall"
                  (nilclaw/dispatcher:tool-definition-name
                   (nilclaw/toolbox:make-memory-recall-tool tb))))
    (is (string= "memory_list"
                  (nilclaw/dispatcher:tool-definition-name
                   (nilclaw/toolbox:make-memory-list-tool tb))))
    (is (string= "memory_forget"
                  (nilclaw/dispatcher:tool-definition-name
                   (nilclaw/toolbox:make-memory-forget-tool tb))))))

;;; ---------------------------------------------------------------------------
;;; Agent tool definitions
;;; ---------------------------------------------------------------------------

(test agent-tool-names
  "Agent lifecycle tools have correct names."
  (let ((tb (nilclaw/toolbox:make-toolbox)))
    (is (string= "git"
                  (nilclaw/dispatcher:tool-definition-name
                   (nilclaw/toolbox:make-git-tool tb))))
    (is (string= "delegate"
                  (nilclaw/dispatcher:tool-definition-name
                   (nilclaw/toolbox:make-delegate-tool tb))))
    (is (string= "spawn"
                  (nilclaw/dispatcher:tool-definition-name
                   (nilclaw/toolbox:make-spawn-tool tb))))
    (is (string= "schedule"
                  (nilclaw/dispatcher:tool-definition-name
                   (nilclaw/toolbox:make-schedule-tool tb))))))

(test delegate-spawn-schedule-unbound
  "Lifecycle tools return error when not bound to runtime."
  (let ((tb (nilclaw/toolbox:make-toolbox)))
    (dolist (tool (list (nilclaw/toolbox:make-delegate-tool tb)
                        (nilclaw/toolbox:make-spawn-tool tb)
                        (nilclaw/toolbox:make-schedule-tool tb)))
      (let ((result (funcall (nilclaw/dispatcher:tool-definition-handler tool) "{}")))
        (is (search "not bound" result))))))

(test git-tool-executes
  "Git tool can execute a basic git command."
  (let* ((tb (nilclaw/toolbox:make-toolbox :workspace-dir "/tmp"))
         (tool (nilclaw/toolbox:make-git-tool tb))
         (handler (nilclaw/dispatcher:tool-definition-handler tool))
         (result (funcall handler "{\"args\":\"--version\"}")))
    (is (search "git version" result))))

;;; ---------------------------------------------------------------------------
;;; Presets
;;; ---------------------------------------------------------------------------

(test default-tools-count
  "default-tools returns exactly 4 tools."
  (let* ((tb (nilclaw/toolbox:make-toolbox))
         (tools (nilclaw/toolbox:default-tools tb)))
    (is (= 4 (length tools)))))

(test all-tools-count-without-memory
  "all-tools without memory backend returns core + standard + lifecycle tools."
  (let* ((tb (nilclaw/toolbox:make-toolbox))
         (tools (nilclaw/toolbox:all-tools tb)))
    ;; 4 core + 2 standard (git, image_info) + 3 lifecycle (delegate, spawn, schedule)
    ;; No memory tools (no backend)
    (is (= 9 (length tools)))))

(test all-tools-count-with-memory
  "all-tools with memory backend includes memory tools."
  (let* ((backend (nilclaw/memory:make-none-memory))
         (tb (nilclaw/toolbox:make-toolbox :memory-backend backend))
         (tools (nilclaw/toolbox:all-tools tb)))
    ;; 4 core + 2 standard + 4 memory + 3 lifecycle
    (is (= 13 (length tools)))))

(test subagent-tools-count
  "subagent-tools returns exactly 5 tools (core + git)."
  (let* ((tb (nilclaw/toolbox:make-toolbox))
         (tools (nilclaw/toolbox:subagent-tools tb)))
    (is (= 5 (length tools)))))

(test subagent-tools-excludes-lifecycle
  "subagent-tools does NOT include delegate, spawn, schedule, or memory tools."
  (let* ((tb (nilclaw/toolbox:make-toolbox))
         (names (mapcar #'nilclaw/dispatcher:tool-definition-name
                        (nilclaw/toolbox:subagent-tools tb))))
    (is (not (member "delegate" names :test #'string=)))
    (is (not (member "spawn" names :test #'string=)))
    (is (not (member "schedule" names :test #'string=)))
    (is (not (member "memory_store" names :test #'string=)))
    (is (not (member "memory_recall" names :test #'string=)))))

;;; ---------------------------------------------------------------------------
;;; Registry population
;;; ---------------------------------------------------------------------------

(test populate-registry-registers-all
  "populate-registry adds all tools to a registry."
  (let* ((tb (nilclaw/toolbox:make-toolbox))
         (registry (nilclaw/dispatcher:make-default-tool-registry))
         (tools (nilclaw/toolbox:default-tools tb)))
    (nilclaw/toolbox:populate-registry registry tools)
    (is (= 4 (nilclaw/dispatcher:tool-count registry)))
    (is (not (null (nilclaw/dispatcher:lookup-tool registry "shell"))))
    (is (not (null (nilclaw/dispatcher:lookup-tool registry "file_read"))))
    (is (not (null (nilclaw/dispatcher:lookup-tool registry "file_write"))))
    (is (not (null (nilclaw/dispatcher:lookup-tool registry "file_edit"))))))

(test populate-registry-tools-are-executable
  "Tools registered via populate-registry can be executed."
  (let* ((tb (nilclaw/toolbox:make-toolbox :workspace-dir "/tmp"))
         (registry (nilclaw/dispatcher:make-default-tool-registry)))
    (nilclaw/toolbox:populate-registry registry (nilclaw/toolbox:default-tools tb))
    (let* ((call (nilclaw/dispatcher:make-tool-call
                  :name "shell"
                  :arguments-json "{\"command\":\"echo toolbox-test\"}"
                  :id "tc-tb-1"))
           (result (nilclaw/dispatcher:execute-tool-call registry call)))
      (is (nilclaw/dispatcher:tool-execution-result-success-p result))
      (is (search "toolbox-test" (nilclaw/dispatcher:tool-execution-result-output result))))))

(test all-tool-names-unique
  "All tools in all-tools have unique names."
  (let* ((backend (nilclaw/memory:make-none-memory))
         (tb (nilclaw/toolbox:make-toolbox :memory-backend backend))
         (tools (nilclaw/toolbox:all-tools tb))
         (names (mapcar #'nilclaw/dispatcher:tool-definition-name tools)))
    (is (= (length names) (length (remove-duplicates names :test #'string=))))))
