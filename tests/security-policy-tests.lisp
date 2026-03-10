(in-package #:nilclaw/tests)
(in-suite security-policy-suite)

(defun %policy (&key (autonomy :supervised) (allowed '("ls" "cat" "git" "echo" "grep" "touch" "rm"))
                    (approval t) (block-high t) (raw nil))
  (nilclaw/security::make-security-policy
   :autonomy autonomy
   :allowed-commands allowed
   :require-approval-for-medium-risk approval
   :block-high-risk-commands block-high
   :allow-raw-url-chars raw))

(test security-autonomy-roundtrip
  (is (eq :supervised (nilclaw/security:autonomy-default)))
  (is (string= "full" (nilclaw/security:autonomy-to-string :full)))
  (is (eq :read-only (nilclaw/security:autonomy-from-string "readonly")))
  (is (eq :yolo (nilclaw/security:autonomy-from-string "yolo"))))

(test security-can-act
  (is (not (nilclaw/security:can-act :read-only)))
  (is (nilclaw/security:can-act :supervised))
  (is (nilclaw/security:can-act :full)))

(test security-command-allowlist-basic
  (let ((p (%policy)))
    (is (nilclaw/security:is-command-allowed p "ls -la"))
    (is (nilclaw/security:is-command-allowed p "/bin/ls -la"))
    (is (not (nilclaw/security:is-command-allowed p "curl http://evil.com")))
    (is (not (nilclaw/security:is-command-allowed (%policy :autonomy :read-only) "ls")))
    (is (not (nilclaw/security:is-command-allowed p "   ")))))

(test security-single-ampersand
  (is (nilclaw/security:contains-single-ampersand "ls & ls"))
  (is (not (nilclaw/security:contains-single-ampersand "ls && echo ok")))
  (is (not (nilclaw/security:contains-single-ampersand "curl \"https://x?a=1&b=2\"")))
  (is (nilclaw/security:contains-single-ampersand "curl https://x?a=1&b=2"))
  (is (not (nilclaw/security:contains-single-ampersand "echo \\& literal"))))

(test security-risk-classification
  (is (eq :low (nilclaw/security:classify-command-risk "git status")))
  (is (eq :medium (nilclaw/security:classify-command-risk "touch file.txt")))
  (is (eq :high (nilclaw/security:classify-command-risk "rm -rf /tmp"))))

(test security-validation-flow
  (multiple-value-bind (risk err)
      (nilclaw/security:validate-command-execution (%policy) "python3 exploit.py")
    (declare (ignore risk))
    (is (eq :command-not-allowed err)))
  (multiple-value-bind (risk err)
      (nilclaw/security:validate-command-execution (%policy) "ls -la")
    (is (eq :low risk))
    (is (null err)))
  (multiple-value-bind (risk err)
      (nilclaw/security:validate-command-execution (%policy) "touch test.txt")
    (declare (ignore risk))
    (is (eq :approval-required err)))
  (multiple-value-bind (risk err)
      (nilclaw/security:validate-command-execution (%policy) "touch test.txt" :approved t)
    (is (eq :medium risk))
    (is (null err)))
  (multiple-value-bind (risk err)
      (nilclaw/security:validate-command-execution (%policy) "rm -rf /tmp")
    (declare (ignore risk))
    (is (eq :high-risk-blocked err))))

(test security-wildcards
  (let ((p (%policy :allowed '("*"))))
    (is (nilclaw/security:is-command-allowed p "python3 --version")))
  (let ((p (%policy :allowed '("  *  "))))
    (is (nilclaw/security:is-command-allowed p "node -e '1'")))
  (let ((p (%policy :allowed '("curl *"))))
    (is (nilclaw/security:is-command-allowed p "curl https://example.com"))))

(test security-rate-limiter
  (let ((tr (nilclaw/security:make-rate-tracker :limit 2)))
    (is (nilclaw/security:record-action tr :supervised))
    (is (nilclaw/security:record-action tr :supervised))
    (is (not (nilclaw/security:record-action tr :supervised)))
    (is (nilclaw/security:is-rate-limited tr :supervised))
    (is (nilclaw/security:record-action tr :yolo))
    (is (not (nilclaw/security:is-rate-limited tr :yolo)))))

(test security-default-policy
  (let ((p (nilclaw/security:make-default-policy)))
    (is (eq :supervised (nilclaw/security::policy-autonomy p)))
    (is (nilclaw/security::policy-require-approval-for-medium-risk p))
    (is (nilclaw/security::policy-block-high-risk-commands p))
    (is (member "git" (nilclaw/security::policy-allowed-commands p) :test #'string=))))

(test security-resolve-allowed
  (is (equal '("*") (nilclaw/security:resolve-allowed-commands :full nil)))
  (is (member "git" (nilclaw/security:resolve-allowed-commands :supervised nil) :test #'string=))
  (is (equal '("foo") (nilclaw/security:resolve-allowed-commands :supervised '("foo")))))

(test security-windows-percent-var
  (is (nilclaw/security:has-percent-var "%PATH%"))
  (is (not (nilclaw/security:has-percent-var "100%%"))))

(test security-oversized-command
  (let* ((big (concatenate 'string "ls " (make-string 9000 :initial-element #\a)))
         (p (%policy)))
    (is (not (nilclaw/security:is-command-allowed p big)))
    (is (eq :high (nilclaw/security:classify-command-risk big)))
    (multiple-value-bind (risk err)
        (nilclaw/security:validate-command-execution p big)
      (declare (ignore risk))
      (is (eq :command-not-allowed err)))))
