;;;; Test provider HTTP layer with actual API calls
;;;; Requires valid API keys in ~/.nilclaw/init.lisp

(in-package #:cl-user)

(require :asdf)
(push (truename ".") asdf:*central-registry*)

;; Load quicklisp for dependencies
(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (when (probe-file quicklisp-init)
    (load quicklisp-init)))

(ql:quickload "alexandria" :silent t)
(asdf:load-system "nilclaw")

(format t "~&[test] Testing provider HTTP layer...~%")

;; Enable HTTP backend
(nilclaw/provider:enable-dexador-backend)
(format t "[test] HTTP backend enabled~%")

;; Load config
(defvar *config* (nilclaw/config:load-config nil))
(format t "[test] Config loaded~%")

;; Test 1: Create provider runtime for zai/glm-5
(format t "~&[test] Test 1: Creating provider runtime for zai/glm-5...~%")
(multiple-value-bind (runtime found-p)
    (nilclaw/config:make-provider-runtime-from-config *config* "zai" :model "zai/glm-5")
  (if runtime
      (format t "[test] ✓ Provider runtime created: ~A~%" runtime)
      (format t "[test] ✗ Failed to create provider runtime (found-p: ~A)~%" found-p)))

;; Test 2: Create provider runtime for openrouter
(format t "~&[test] Test 2: Creating provider runtime for openrouter...~%")
(multiple-value-bind (runtime found-p)
    (nilclaw/config:make-provider-runtime-from-config *config* "openrouter" :model "openrouter/auto")
  (if runtime
      (format t "[test] ✓ Provider runtime created: ~A~%" runtime)
      (format t "[test] ✗ Failed to create provider runtime (found-p: ~A)~%" found-p)))

;; Test 3: Make a simple chat request (using zai/glm-5 as default)
(format t "~&[test] Test 3: Making chat request to zai/glm-5...~%")
(let ((input "Say 'test ok' in exactly those words."))
  (multiple-value-bind (runtime found-p)
      (nilclaw/config:make-provider-runtime-from-config *config* "zai" :model "zai/glm-5")
    (if runtime
        (multiple-value-bind (response success-p)
            (nilclaw/agent:agent-chat input runtime)
          (if success-p
              (format t "[test] ✓ Chat response: ~A~%" response)
              (format t "[test] ✗ Chat failed: ~A~%" response)))
        (format t "[test] ✗ No runtime available (found-p: ~A)~%" found-p))))

(format t "~&[test] Provider HTTP layer tests complete.~%")
(uiop:quit 0)
