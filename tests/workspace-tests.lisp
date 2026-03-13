(in-package #:nilclaw/tests)

(def-suite workspace-suite :in nilclaw-suite)
(in-suite workspace-suite)

;;; ---------------------------------------------------------------------------
;;; Constants
;;; ---------------------------------------------------------------------------

(test bootstrap-constants-have-expected-values
  "Bootstrap constants match the OpenClaw specification."
  (is (= 20000 nilclaw/workspace:+bootstrap-max-chars+))
  (is (= 24000 nilclaw/workspace:+bootstrap-total-max-chars+))
  (is (= (* 2 1024 1024) nilclaw/workspace:+max-workspace-bootstrap-file-bytes+)))

(test bootstrap-files-canonical-order
  "Bootstrap files are in canonical loading order."
  (let ((files (nilclaw/workspace:+bootstrap-files+)))
    (is (= 8 (length files)))
    (is (string= "AGENTS.md" (first files)))
    (is (string= "SOUL.md" (second files)))
    (is (string= "TOOLS.md" (third files)))
    (is (string= "IDENTITY.md" (fourth files)))
    (is (string= "USER.md" (fifth files)))
    (is (string= "HEARTBEAT.md" (sixth files)))
    (is (string= "BOOTSTRAP.md" (seventh files)))
    (is (string= "MEMORY.md" (eighth files)))))

(test tracked-files-include-lowercase-memory
  "Tracked fingerprint files include both MEMORY.md and memory.md."
  (let ((tracked (nilclaw/workspace:+tracked-fingerprint-files+)))
    (is (= 9 (length tracked)))
    (is (member "MEMORY.md" tracked :test #'string=))
    (is (member "memory.md" tracked :test #'string=))))

;;; ---------------------------------------------------------------------------
;;; Filename Security Validation
;;; ---------------------------------------------------------------------------

(test validate-filename-accepts-valid-names
  "Valid bootstrap filenames are accepted."
  (is (nilclaw/workspace:validate-bootstrap-filename "SOUL.md"))
  (is (nilclaw/workspace:validate-bootstrap-filename "AGENTS.md"))
  (is (nilclaw/workspace:validate-bootstrap-filename "memory.md"))
  (is (nilclaw/workspace:validate-bootstrap-filename "subdir/file.md")))

(test validate-filename-rejects-empty
  "Empty filenames are rejected."
  (multiple-value-bind (ok reason) (nilclaw/workspace:validate-bootstrap-filename "")
    (is (not ok))
    (is (search "empty" reason))))

(test validate-filename-rejects-absolute-path
  "Absolute paths are rejected."
  (multiple-value-bind (ok reason) (nilclaw/workspace:validate-bootstrap-filename "/etc/passwd")
    (is (not ok))
    (is (search "absolute" reason))))

(test validate-filename-rejects-null-bytes
  "Filenames with null bytes are rejected."
  (multiple-value-bind (ok reason)
      (nilclaw/workspace:validate-bootstrap-filename (format nil "file~Cname" #\Nul))
    (is (not ok))
    (is (search "null" reason))))

(test validate-filename-rejects-path-traversal
  "Path traversal via .. is rejected."
  (multiple-value-bind (ok reason) (nilclaw/workspace:validate-bootstrap-filename "../etc/passwd")
    (is (not ok))
    (is (search "traversal" reason)))
  (is (not (nilclaw/workspace:validate-bootstrap-filename "foo/../../bar")))
  (is (not (nilclaw/workspace:validate-bootstrap-filename ".."))))

;;; ---------------------------------------------------------------------------
;;; Safe Workspace Path
;;; ---------------------------------------------------------------------------

(test safe-workspace-path-resolves-existing-file
  "safe-workspace-path resolves existing files within workspace."
  (let ((ws-dir "/tmp/nilclaw-ws-test"))
    (ensure-directories-exist (format nil "~A/" ws-dir))
    (let ((test-file (format nil "~A/SOUL.md" ws-dir)))
      (with-open-file (s test-file :direction :output :if-exists :supersede)
        (write-string "test soul" s))
      (unwind-protect
           (multiple-value-bind (path status)
               (nilclaw/workspace:safe-workspace-path ws-dir "SOUL.md")
             (is (string= "ok" status))
             (is (stringp path))
             (is (search "SOUL.md" path)))
        (ignore-errors (delete-file test-file))))))

(test safe-workspace-path-returns-not-found
  "safe-workspace-path returns not-found for missing files."
  (multiple-value-bind (path status)
      (nilclaw/workspace:safe-workspace-path "/tmp" "NONEXISTENT-FILE-12345.md")
    (is (null path))
    (is (string= "not-found" status))))

(test safe-workspace-path-rejects-invalid-filename
  "safe-workspace-path rejects invalid filenames."
  (multiple-value-bind (path status)
      (nilclaw/workspace:safe-workspace-path "/tmp" "../etc/passwd")
    (is (null path))
    (is (string= "invalid-filename" status))))

;;; ---------------------------------------------------------------------------
;;; FNV-1a Fingerprinting
;;; ---------------------------------------------------------------------------

(test fnv1a-64-deterministic
  "FNV-1a 64-bit is deterministic for same input."
  (let ((bytes (babel:string-to-octets "hello world" :encoding :utf-8)))
    (is (= (nilclaw/workspace:fnv1a-64 bytes)
            (nilclaw/workspace:fnv1a-64 bytes)))))

(test fnv1a-64-different-for-different-input
  "FNV-1a 64-bit produces different hashes for different inputs."
  (is (/= (nilclaw/workspace:fnv1a-64-string "hello")
           (nilclaw/workspace:fnv1a-64-string "world"))))

(test fnv1a-64-string-works
  "FNV-1a 64-bit string hashing works."
  (is (typep (nilclaw/workspace:fnv1a-64-string "test") '(unsigned-byte 64))))

(test file-fingerprint-deterministic
  "file-fingerprint is deterministic for same workspace."
  (is (= (nilclaw/workspace:file-fingerprint "/tmp")
          (nilclaw/workspace:file-fingerprint "/tmp"))))

;;; ---------------------------------------------------------------------------
;;; Null Bootstrap Provider
;;; ---------------------------------------------------------------------------

(test null-provider-load-returns-nil
  "Null bootstrap provider load returns NIL."
  (let ((p (nilclaw/workspace:make-null-bootstrap-provider)))
    (is (null (nilclaw/workspace:bootstrap-load p "SOUL.md")))))

(test null-provider-exists-returns-nil
  "Null bootstrap provider exists returns NIL."
  (let ((p (nilclaw/workspace:make-null-bootstrap-provider)))
    (is (null (nilclaw/workspace:bootstrap-exists p "SOUL.md")))))

(test null-provider-list-returns-empty
  "Null bootstrap provider list returns empty list."
  (let ((p (nilclaw/workspace:make-null-bootstrap-provider)))
    (is (null (nilclaw/workspace:bootstrap-list-files p)))))

(test null-provider-fingerprint-returns-zero
  "Null bootstrap provider fingerprint returns 0."
  (let ((p (nilclaw/workspace:make-null-bootstrap-provider)))
    (is (= 0 (nilclaw/workspace:bootstrap-fingerprint p)))))

(test null-provider-store-is-noop
  "Null bootstrap provider store is a no-op."
  (let ((p (nilclaw/workspace:make-null-bootstrap-provider)))
    (is (null (nilclaw/workspace:bootstrap-store p "SOUL.md" "test content")))
    (is (null (nilclaw/workspace:bootstrap-load p "SOUL.md")))))

;;; ---------------------------------------------------------------------------
;;; File Bootstrap Provider
;;; ---------------------------------------------------------------------------

(defmacro with-temp-workspace ((ws-var) &body body)
  "Create a temporary workspace directory, bind it to WS-VAR, and clean up."
  (let ((dir-sym (gensym "DIR")))
    `(let* ((,dir-sym (format nil "/tmp/nilclaw-ws-~A/" (random 1000000)))
            (,ws-var ,dir-sym))
       (ensure-directories-exist ,dir-sym)
       (unwind-protect (progn ,@body)
         (ignore-errors (uiop:delete-directory-tree
                         (pathname ,dir-sym) :validate t))))))

(test file-provider-store-and-load
  "File bootstrap provider can store and load files."
  (with-temp-workspace (ws)
    (let ((p (nilclaw/workspace:make-file-bootstrap-provider :workspace-dir ws)))
      (nilclaw/workspace:bootstrap-store p "SOUL.md" "Be creative and helpful.")
      (is (string= "Be creative and helpful."
                    (nilclaw/workspace:bootstrap-load p "SOUL.md"))))))

(test file-provider-exists
  "File bootstrap provider exists check works."
  (with-temp-workspace (ws)
    (let ((p (nilclaw/workspace:make-file-bootstrap-provider :workspace-dir ws)))
      (is (not (nilclaw/workspace:bootstrap-exists p "SOUL.md")))
      (nilclaw/workspace:bootstrap-store p "SOUL.md" "test")
      (is (nilclaw/workspace:bootstrap-exists p "SOUL.md")))))

(test file-provider-remove
  "File bootstrap provider can remove files."
  (with-temp-workspace (ws)
    (let ((p (nilclaw/workspace:make-file-bootstrap-provider :workspace-dir ws)))
      (nilclaw/workspace:bootstrap-store p "SOUL.md" "test")
      (is (nilclaw/workspace:bootstrap-exists p "SOUL.md"))
      (nilclaw/workspace:bootstrap-remove p "SOUL.md")
      (is (not (nilclaw/workspace:bootstrap-exists p "SOUL.md"))))))

(test file-provider-list-files
  "File bootstrap provider lists stored files."
  (with-temp-workspace (ws)
    (let ((p (nilclaw/workspace:make-file-bootstrap-provider :workspace-dir ws)))
      (nilclaw/workspace:bootstrap-store p "SOUL.md" "soul")
      (nilclaw/workspace:bootstrap-store p "AGENTS.md" "agents")
      (let ((files (nilclaw/workspace:bootstrap-list-files p)))
        (is (= 2 (length files)))
        (is (member "SOUL.md" files :test #'string=))
        (is (member "AGENTS.md" files :test #'string=))))))

(test file-provider-load-excerpt
  "File bootstrap provider load-excerpt respects byte limit."
  (with-temp-workspace (ws)
    (let ((p (nilclaw/workspace:make-file-bootstrap-provider :workspace-dir ws)))
      (nilclaw/workspace:bootstrap-store p "SOUL.md" "Hello, this is a long content string.")
      (let ((excerpt (nilclaw/workspace:bootstrap-load-excerpt p "SOUL.md" 5)))
        (is (= 5 (length excerpt)))
        (is (string= "Hello" excerpt))))))

(test file-provider-fingerprint-changes-with-content
  "File bootstrap provider fingerprint changes when file content changes."
  (with-temp-workspace (ws)
    (let ((p (nilclaw/workspace:make-file-bootstrap-provider :workspace-dir ws)))
      (nilclaw/workspace:bootstrap-store p "SOUL.md" "version 1")
      (let ((fp1 (nilclaw/workspace:bootstrap-fingerprint p)))
        ;; Give filesystem a moment for mtime change
        (sleep 1.1)
        (nilclaw/workspace:bootstrap-store p "SOUL.md" "version 2")
        (let ((fp2 (nilclaw/workspace:bootstrap-fingerprint p)))
          (is (/= fp1 fp2)))))))

;;; ---------------------------------------------------------------------------
;;; Memory Bootstrap Provider
;;; ---------------------------------------------------------------------------

(test memory-provider-store-and-load
  "Memory bootstrap provider stores via memory backend."
  (let* ((backend (nilclaw/memory:make-markdown-memory
                   :root (format nil "/tmp/nilclaw-mem-~A/" (random 1000000))))
         (p (nilclaw/workspace:make-memory-bootstrap-provider :memory-backend backend)))
    (nilclaw/workspace:bootstrap-store p "SOUL.md" "Be kind and thoughtful.")
    (is (string= "Be kind and thoughtful."
                  ;; memory-get returns entry with __bootstrap.prompt.SOUL.md key
                  ;; but bootstrap-load should return the raw content
                  (nilclaw/workspace:bootstrap-load p "SOUL.md")))))

(test memory-provider-exists
  "Memory bootstrap provider exists check works."
  (let* ((backend (nilclaw/memory:make-markdown-memory
                   :root (format nil "/tmp/nilclaw-mem-~A/" (random 1000000))))
         (p (nilclaw/workspace:make-memory-bootstrap-provider :memory-backend backend)))
    (is (not (nilclaw/workspace:bootstrap-exists p "SOUL.md")))
    (nilclaw/workspace:bootstrap-store p "SOUL.md" "test")
    (is (nilclaw/workspace:bootstrap-exists p "SOUL.md"))))

;;; ---------------------------------------------------------------------------
;;; Provider Factory
;;; ---------------------------------------------------------------------------

(test factory-none-backend-gives-null-provider
  "Factory returns null provider for none backend."
  (let* ((backend (nilclaw/memory:make-none-memory))
         (provider (nilclaw/workspace:make-bootstrap-provider :memory-backend backend)))
    (is (typep provider 'nilclaw/workspace:null-bootstrap-provider))))

(test factory-markdown-backend-gives-file-provider
  "Factory returns file provider for markdown backend."
  (let* ((backend (nilclaw/memory:make-markdown-memory
                   :root (format nil "/tmp/nilclaw-fac-~A/" (random 1000000))))
         (provider (nilclaw/workspace:make-bootstrap-provider
                    :memory-backend backend :workspace-dir "/tmp")))
    (is (typep provider 'nilclaw/workspace:file-bootstrap-provider))))

(test factory-no-backend-gives-null-provider
  "Factory returns null provider when no backend is provided."
  (let ((provider (nilclaw/workspace:make-bootstrap-provider)))
    (is (typep provider 'nilclaw/workspace:null-bootstrap-provider))))

;;; ---------------------------------------------------------------------------
;;; Workspace Struct
;;; ---------------------------------------------------------------------------

(test workspace-defaults
  "Workspace struct has sensible defaults."
  (let ((ws (nilclaw/workspace:make-workspace)))
    (is (string= "." (nilclaw/workspace:workspace-dir ws)))
    (is (null (nilclaw/workspace:workspace-bootstrap-provider ws)))))

;;; ---------------------------------------------------------------------------
;;; Workspace Boot — integration tests
;;; ---------------------------------------------------------------------------

(test boot-empty-workspace-returns-empty-result
  "Booting an empty workspace returns empty boot result."
  (with-temp-workspace (ws)
    (let* ((provider (nilclaw/workspace:make-file-bootstrap-provider :workspace-dir ws))
           (workspace (nilclaw/workspace:make-workspace :dir ws :bootstrap-provider provider))
           (result (nilclaw/workspace:workspace-boot workspace)))
      (is (null (nilclaw/workspace:boot-result-sections result)))
      (is (= 0 (nilclaw/workspace:boot-result-total-chars result)))
      (is (not (nilclaw/workspace:boot-result-truncated-p result)))
      (is (null (nilclaw/workspace:boot-result-files-loaded result))))))

(test boot-nil-provider-returns-empty-result
  "Booting with nil provider returns empty boot result."
  (let* ((workspace (nilclaw/workspace:make-workspace :dir "/tmp"))
         (result (nilclaw/workspace:workspace-boot workspace)))
    (is (null (nilclaw/workspace:boot-result-sections result)))
    (is (= 0 (nilclaw/workspace:boot-result-fingerprint result)))))

(test boot-loads-files-in-order
  "Boot loads files in canonical order."
  (with-temp-workspace (ws)
    (let ((provider (nilclaw/workspace:make-file-bootstrap-provider :workspace-dir ws)))
      ;; Create files in reverse order to verify loading order
      (nilclaw/workspace:bootstrap-store provider "IDENTITY.md" "I am NilClaw.")
      (nilclaw/workspace:bootstrap-store provider "SOUL.md" "Be creative.")
      (nilclaw/workspace:bootstrap-store provider "AGENTS.md" "Follow these rules.")
      (let* ((workspace (nilclaw/workspace:make-workspace :dir ws :bootstrap-provider provider))
             (result (nilclaw/workspace:workspace-boot workspace)))
        ;; All three should be loaded
        (is (= 3 (length (nilclaw/workspace:boot-result-sections result))))
        (is (= 3 (length (nilclaw/workspace:boot-result-files-loaded result))))
        ;; Order should be canonical: AGENTS, SOUL, IDENTITY
        (let ((loaded (nilclaw/workspace:boot-result-files-loaded result)))
          (is (string= "AGENTS.md" (first loaded)))
          (is (string= "SOUL.md" (second loaded)))
          (is (string= "IDENTITY.md" (third loaded))))))))

(test boot-respects-per-file-limit
  "Boot truncates files exceeding per-file character limit."
  (with-temp-workspace (ws)
    (let ((provider (nilclaw/workspace:make-file-bootstrap-provider :workspace-dir ws)))
      ;; Create a file larger than BOOTSTRAP_MAX_CHARS (20000)
      (let ((big-content (make-string 25000 :initial-element #\X)))
        (nilclaw/workspace:bootstrap-store provider "AGENTS.md" big-content))
      (let* ((workspace (nilclaw/workspace:make-workspace :dir ws :bootstrap-provider provider))
             (result (nilclaw/workspace:workspace-boot workspace)))
        ;; File should be loaded but truncated
        (is (= 1 (length (nilclaw/workspace:boot-result-sections result))))
        ;; Content should contain truncation marker
        (let ((content (cdr (first (nilclaw/workspace:boot-result-sections result)))))
          (is (search "truncated" content)))))))

(test boot-respects-total-limit
  "Boot stops loading when total character limit is reached."
  (with-temp-workspace (ws)
    (let ((provider (nilclaw/workspace:make-file-bootstrap-provider :workspace-dir ws)))
      ;; Create files that together exceed BOOTSTRAP_TOTAL_MAX_CHARS (24000)
      (nilclaw/workspace:bootstrap-store provider "AGENTS.md"
                                          (make-string 15000 :initial-element #\A))
      (nilclaw/workspace:bootstrap-store provider "SOUL.md"
                                          (make-string 15000 :initial-element #\B))
      (nilclaw/workspace:bootstrap-store provider "TOOLS.md"
                                          (make-string 5000 :initial-element #\C))
      (let* ((workspace (nilclaw/workspace:make-workspace :dir ws :bootstrap-provider provider))
             (result (nilclaw/workspace:workspace-boot workspace)))
        ;; Should have loaded AGENTS and SOUL (truncated) but not TOOLS
        (is (nilclaw/workspace:boot-result-truncated-p result))
        ;; Total chars should not exceed limit
        (is (<= (nilclaw/workspace:boot-result-total-chars result)
                nilclaw/workspace:+bootstrap-total-max-chars+))))))

(test boot-memory-md-fallback
  "Boot falls back to memory.md when MEMORY.md is missing."
  (with-temp-workspace (ws)
    (let ((provider (nilclaw/workspace:make-file-bootstrap-provider :workspace-dir ws)))
      ;; Only create lowercase memory.md
      (nilclaw/workspace:bootstrap-store provider "memory.md" "remembered things")
      (let* ((workspace (nilclaw/workspace:make-workspace :dir ws :bootstrap-provider provider))
             (result (nilclaw/workspace:workspace-boot workspace)))
        (is (= 1 (length (nilclaw/workspace:boot-result-sections result))))
        (is (member "memory.md" (nilclaw/workspace:boot-result-files-loaded result)
                    :test #'string=))))))

(test boot-fingerprint-is-set
  "Boot result has a non-zero fingerprint when files exist."
  (with-temp-workspace (ws)
    (let ((provider (nilclaw/workspace:make-file-bootstrap-provider :workspace-dir ws)))
      (nilclaw/workspace:bootstrap-store provider "SOUL.md" "hello")
      (let* ((workspace (nilclaw/workspace:make-workspace :dir ws :bootstrap-provider provider))
             (result (nilclaw/workspace:workspace-boot workspace)))
        (is (/= 0 (nilclaw/workspace:boot-result-fingerprint result)))))))

;;; ---------------------------------------------------------------------------
;;; Project Context Builder
;;; ---------------------------------------------------------------------------

(test project-context-empty-for-no-sections
  "build-project-context returns empty string when no files loaded."
  (let ((result (nilclaw/workspace:make-boot-result)))
    (is (string= "" (nilclaw/workspace:build-project-context result)))))

(test project-context-contains-preamble
  "build-project-context includes the workspace preamble."
  (with-temp-workspace (ws)
    (let ((provider (nilclaw/workspace:make-file-bootstrap-provider :workspace-dir ws)))
      (nilclaw/workspace:bootstrap-store provider "SOUL.md" "Be creative.")
      (let* ((workspace (nilclaw/workspace:make-workspace :dir ws :bootstrap-provider provider))
             (result (nilclaw/workspace:workspace-boot workspace))
             (context (nilclaw/workspace:build-project-context result)))
        (is (search "Project Context" context))
        (is (search "workspace files" context))))))

(test project-context-includes-file-content
  "build-project-context includes loaded file content."
  (with-temp-workspace (ws)
    (let ((provider (nilclaw/workspace:make-file-bootstrap-provider :workspace-dir ws)))
      (nilclaw/workspace:bootstrap-store provider "SOUL.md" "Be creative and bold.")
      (let* ((workspace (nilclaw/workspace:make-workspace :dir ws :bootstrap-provider provider))
             (result (nilclaw/workspace:workspace-boot workspace))
             (context (nilclaw/workspace:build-project-context result)))
        (is (search "Be creative and bold." context))
        (is (search "SOUL.md" context))))))

(test project-context-includes-guidance
  "build-project-context includes guidance annotations for AGENTS/SOUL/TOOLS."
  (with-temp-workspace (ws)
    (let ((provider (nilclaw/workspace:make-file-bootstrap-provider :workspace-dir ws)))
      (nilclaw/workspace:bootstrap-store provider "AGENTS.md" "Start by greeting.")
      (nilclaw/workspace:bootstrap-store provider "SOUL.md" "Be warm.")
      (nilclaw/workspace:bootstrap-store provider "TOOLS.md" "Use shell carefully.")
      (let* ((workspace (nilclaw/workspace:make-workspace :dir ws :bootstrap-provider provider))
             (result (nilclaw/workspace:workspace-boot workspace))
             (context (nilclaw/workspace:build-project-context result)))
        ;; AGENTS.md guidance
        (is (search "operational guidance" context))
        ;; SOUL.md guidance
        (is (search "embody its persona" context))
        ;; TOOLS.md guidance
        (is (search "Does not control tool availability" context))))))

(test project-context-shows-workspace-dir-in-paths
  "build-project-context shows workspace dir in file path annotations."
  (with-temp-workspace (ws)
    (let ((provider (nilclaw/workspace:make-file-bootstrap-provider :workspace-dir ws)))
      (nilclaw/workspace:bootstrap-store provider "SOUL.md" "test")
      (let* ((workspace (nilclaw/workspace:make-workspace :dir ws :bootstrap-provider provider))
             (result (nilclaw/workspace:workspace-boot workspace))
             (context (nilclaw/workspace:build-project-context result :workspace-dir "/home/user/project")))
        (is (search "/home/user/project/SOUL.md" context))))))

(test project-context-truncation-notice
  "build-project-context shows truncation notice when total limit hit."
  (let ((result (nilclaw/workspace:make-boot-result :truncated-p t)))
    ;; Inject a fake section to avoid empty result
    (setf (nilclaw/workspace:boot-result-sections result)
          (list (cons "AGENTS.md" "test")))
    (let ((context (nilclaw/workspace:build-project-context result)))
      (is (search "truncated" context))
      (is (search "24000" context)))))

;;; ---------------------------------------------------------------------------
;;; AIEOS Identity Format
;;; ---------------------------------------------------------------------------

(test aieos-configured-requires-format-and-path
  "AIEOS is only configured when format is 'aieos' and path/inline is set."
  ;; Not configured: wrong format
  (is (not (nilclaw/workspace:aieos-configured-p '(:format "nilclaw"))))
  ;; Not configured: no path or inline
  (is (not (nilclaw/workspace:aieos-configured-p '(:format "aieos"))))
  ;; Configured: with path
  (is (nilclaw/workspace:aieos-configured-p '(:format "aieos" :aieos-path "/path/to/id.json")))
  ;; Configured: with inline
  (is (nilclaw/workspace:aieos-configured-p '(:format "aieos" :aieos-inline "{}"))))

(test aieos-parse-returns-alist
  "parse-aieos returns a valid alist from JSON."
  (let ((result (nilclaw/workspace:parse-aieos
                 "{\"identity\":{\"names\":{\"first\":\"Nova\"}}}")))
    (is (listp result))
    (is (assoc :identity result))))

(test aieos-render-identity-section
  "render-aieos renders identity section with name."
  (let* ((json "{\"identity\":{\"names\":{\"first\":\"Nova\",\"last\":\"Star\"},\"bio\":\"An AI agent.\"}}")
         (parsed (nilclaw/workspace:parse-aieos json))
         (rendered (nilclaw/workspace:render-aieos parsed)))
    (is (search "## Identity" rendered))
    (is (search "Nova" rendered))
    (is (search "Full Name:" rendered))
    (is (search "Nova Star" rendered))
    (is (search "An AI agent." rendered))))

(test aieos-render-psychology-section
  "render-aieos renders psychology with MBTI and OCEAN."
  (let* ((json "{\"psychology\":{\"mbti\":\"INTJ\",\"ocean\":{\"openness\":0.85,\"conscientiousness\":0.9}}}")
         (parsed (nilclaw/workspace:parse-aieos json))
         (rendered (nilclaw/workspace:render-aieos parsed)))
    (is (search "## Personality" rendered))
    (is (search "INTJ" rendered))
    (is (search "0.85" rendered))
    (is (search "Openness" rendered))))

(test aieos-render-empty-identity
  "render-aieos produces empty string for empty identity."
  (let* ((parsed (nilclaw/workspace:parse-aieos "{}"))
         (rendered (nilclaw/workspace:render-aieos parsed)))
    (is (string= "" rendered))))

(test aieos-render-linguistics-section
  "render-aieos renders linguistics section."
  (let* ((json "{\"linguistics\":{\"style\":\"casual\",\"formality\":\"low\",\"catchphrases\":[\"yo\",\"nice\"]}}")
         (parsed (nilclaw/workspace:parse-aieos json))
         (rendered (nilclaw/workspace:render-aieos parsed)))
    (is (search "## Communication Style" rendered))
    (is (search "casual" rendered))
    (is (search "yo" rendered))))

(test aieos-render-motivations-section
  "render-aieos renders motivations with goals and fears."
  (let* ((json "{\"motivations\":{\"core_drive\":\"Help humans\",\"fears\":[\"irrelevance\"]}}")
         (parsed (nilclaw/workspace:parse-aieos json))
         (rendered (nilclaw/workspace:render-aieos parsed)))
    (is (search "## Motivations" rendered))
    (is (search "Help humans" rendered))
    (is (search "irrelevance" rendered))))

(test aieos-render-full-identity
  "render-aieos handles a complete AIEOS identity document."
  (let* ((json "{
  \"identity\": {\"names\": {\"first\": \"Nova\", \"nickname\": \"N\"}, \"bio\": \"A helpful agent\"},
  \"psychology\": {\"mbti\": \"ENFP\"},
  \"linguistics\": {\"style\": \"friendly\"},
  \"capabilities\": {\"skills\": [\"coding\", \"research\"]},
  \"history\": {\"occupation\": \"AI Assistant\"},
  \"interests\": {\"hobbies\": [\"learning\", \"creating\"]}
}")
         (parsed (nilclaw/workspace:parse-aieos json))
         (rendered (nilclaw/workspace:render-aieos parsed)))
    ;; All sections present
    (is (search "## Identity" rendered))
    (is (search "## Personality" rendered))
    (is (search "## Communication Style" rendered))
    (is (search "## Capabilities" rendered))
    (is (search "## Background" rendered))
    (is (search "## Interests" rendered))
    ;; Content present
    (is (search "Nova" rendered))
    (is (search "Nickname" rendered))
    (is (search "coding" rendered))
    (is (search "AI Assistant" rendered))))

;;; ---------------------------------------------------------------------------
;;; System Prompt Integration
;;; ---------------------------------------------------------------------------

(test system-prompt-with-boot-result
  "build-system-prompt integrates workspace boot result."
  (with-temp-workspace (ws)
    (let ((provider (nilclaw/workspace:make-file-bootstrap-provider :workspace-dir ws)))
      (nilclaw/workspace:bootstrap-store provider "SOUL.md" "Be creative and bold.")
      (nilclaw/workspace:bootstrap-store provider "AGENTS.md" "Always greet the user first.")
      (let* ((workspace (nilclaw/workspace:make-workspace :dir ws :bootstrap-provider provider))
             (result (nilclaw/workspace:workspace-boot workspace))
             (prompt (nilclaw/toolbox:build-system-prompt
                      :workspace-dir ws
                      :boot-result result)))
        ;; Project context should appear before NilClaw identity
        (let ((context-pos (search "Project Context" prompt))
              (identity-pos (search "About NilClaw" prompt)))
          (is (not (null context-pos)))
          (is (not (null identity-pos)))
          (is (< context-pos identity-pos)))
        ;; Boot file content should be present
        (is (search "Be creative and bold." prompt))
        (is (search "Always greet the user first." prompt))))))

(test system-prompt-with-aieos
  "build-system-prompt integrates AIEOS identity."
  (let* ((json "{\"identity\":{\"names\":{\"first\":\"Nova\"},\"bio\":\"An AI.\"}}")
         (parsed (nilclaw/workspace:parse-aieos json))
         (aieos-md (nilclaw/workspace:render-aieos parsed))
         (prompt (nilclaw/toolbox:build-system-prompt
                  :aieos-identity aieos-md)))
    (is (search "Nova" prompt))
    (is (search "An AI." prompt))))

(test system-prompt-has-datetime
  "build-system-prompt includes DateTime section."
  (let ((prompt (nilclaw/toolbox:build-system-prompt)))
    (is (search "## DateTime" prompt))
    (is (search "UTC" prompt))))

(test system-prompt-has-runtime-with-model
  "build-system-prompt includes Runtime section with model and OS."
  (let ((prompt (nilclaw/toolbox:build-system-prompt :model "claude-sonnet-4-20250514")))
    (is (search "## Runtime" prompt))
    (is (search "claude-sonnet-4-20250514" prompt))
    (is (search "OS:" prompt))))

(test system-prompt-workspace-section
  "build-system-prompt includes Workspace section with directory."
  (let ((prompt (nilclaw/toolbox:build-system-prompt :workspace-dir "/home/user/project")))
    (is (search "## Workspace" prompt))
    (is (search "/home/user/project" prompt))))

(test system-prompt-group-chat-behavior
  "build-system-prompt includes group chat behavior when enabled."
  (let ((prompt-no (nilclaw/toolbox:build-system-prompt))
        (prompt-yes (nilclaw/toolbox:build-system-prompt :group-chat-p t)))
    (is (not (search "[NO_REPLY]" prompt-no)))
    (is (search "[NO_REPLY]" prompt-yes))
    (is (search "Group Chat" prompt-yes))))

(test system-prompt-scheduled-tasks
  "build-system-prompt includes scheduled tasks section."
  (let ((prompt (nilclaw/toolbox:build-system-prompt
                 :scheduled-tasks "Run daily backup at 02:00 UTC.")))
    (is (search "Scheduled Tasks" prompt))
    (is (search "daily backup" prompt))))

(test system-prompt-skills-context
  "build-system-prompt includes skills context section."
  (let ((prompt (nilclaw/toolbox:build-system-prompt
                 :skills-context "- web_search: Search the internet")))
    (is (search "## Skills" prompt))
    (is (search "web_search" prompt))))

(test system-prompt-capabilities
  "build-system-prompt includes capabilities section."
  (let ((prompt (nilclaw/toolbox:build-system-prompt
                 :capabilities "Can browse the web and analyze images.")))
    (is (search "## Capabilities" prompt))
    (is (search "browse the web" prompt))))

(test system-prompt-all-sections-order
  "build-system-prompt sections appear in correct order."
  (with-temp-workspace (ws)
    (let ((provider (nilclaw/workspace:make-file-bootstrap-provider :workspace-dir ws)))
      (nilclaw/workspace:bootstrap-store provider "SOUL.md" "Be helpful.")
      (let* ((workspace (nilclaw/workspace:make-workspace :dir ws :bootstrap-provider provider))
             (result (nilclaw/workspace:workspace-boot workspace))
             (tb (nilclaw/toolbox:make-toolbox :workspace-dir ws))
             (tools (nilclaw/toolbox:default-tools tb))
             (prompt (nilclaw/toolbox:build-system-prompt
                      :workspace-dir ws
                      :model "test-model"
                      :boot-result result
                      :tools tools
                      :group-chat-p t
                      :scheduled-tasks "Run backup."
                      :skills-context "- skill1"
                      :capabilities "Can code.")))
        ;; Verify ordering of key sections (use unique strings to avoid
        ;; false matches within NilClaw identity text)
        (let ((project (search "## Project Context" prompt))
              (about (search "## About NilClaw" prompt))
              (avail-tools (search "## Available Tools" prompt))
              (capabilities (search "Can code." prompt))  ; unique content
              (safety (search "## Safety Rules" prompt))
              (group (search "[NO_REPLY]" prompt))  ; unique to group chat
              (sched (search "Run backup." prompt))  ; unique content
              (skills (search "- skill1" prompt))  ; unique content
              (ws-section (search "Working directory:" prompt :from-end t)) ; last occurrence
              (dt (search "## DateTime" prompt))
              (runtime (search "test-model" prompt :from-end t)))  ; last occurrence
          (is (< project about))
          (is (< about avail-tools))
          (is (< avail-tools safety))
          (is (< safety group))
          (is (< group sched))
          (is (< sched skills))
          (is (< ws-section dt))
          (is (< dt runtime)))))))
