;;;; Test channel system
;;;; Tests CLI channel, permissions, and auto-reply

(in-package #:cl-user)

(require :asdf)
(push (truename ".") asdf:*central-registry*)
(asdf:load-system "nilclaw")

(format t "~&[test] Testing channel system...~%")

;; Test 1: Create channel manager
(format t "~&[test] Test 1: Creating channel manager...~%")
(let ((manager (nilclaw/channel:make-channel-manager)))
  (if manager
      (format t "[test] ✓ Channel manager created~%")
      (format t "[test] ✗ Failed to create channel manager~%")))

;; Test 2: Register and start CLI channel
(format t "~&[test] Test 2: Registering and starting CLI channel...~%")
(let ((manager (nilclaw/channel:make-channel-manager)))
  (nilclaw/channel:register-channel manager "cli" (nilclaw/channel:make-cli-channel))
  (nilclaw/channel:start-all-channels manager)
  (let ((cli (nilclaw/channel:find-channel manager "cli")))
    (if (and cli (nilclaw/channel:channel-health-check cli))
        (format t "[test] ✓ CLI channel started and healthy~%")
        (format t "[test] ✗ CLI channel not healthy~%"))))

;; Test 3: Test channel send
(format t "~&[test] Test 3: Testing channel send...~%")
(let ((manager (nilclaw/channel:make-channel-manager)))
  (nilclaw/channel:register-channel manager "cli" (nilclaw/channel:make-cli-channel))
  (nilclaw/channel:start-all-channels manager)
  (let ((result (nilclaw/channel:channel-send
                 (nilclaw/channel:find-channel manager "cli")
                 "test"
                 "[test] Message from channel test")))
    (if result
        (format t "[test] ✓ Channel send succeeded~%")
        (format t "[test] ✗ Channel send failed~%"))))

;; Test 4: Test web channel creation
(format t "~&[test] Test 4: Testing web channel creation...~%")
(let ((web (nilclaw/channel:make-web-channel
            :path "/test"
            :auth-token "test-token"
            :allowed-origins '("https://example.com")
            :transport :relay
            :relay-url "wss://relay.example.com/ws")))
  (if (and web
           (string= (nilclaw/channel:web-channel-path web) "/test")
           (string= (nilclaw/channel:web-channel-auth-token web) "test-token"))
      (format t "[test] ✓ Web channel created with correct config~%")
      (format t "[test] ✗ Web channel config incorrect~%")))

;; Test 5: Test permission system
(format t "~&[test] Test 5: Testing permission system...~%")
(let ((allowed (nilclaw/channel:check-dm-permission :allowlist "user1" '("user1" "user2")))
      (denied (nilclaw/channel:check-dm-permission :allowlist "user3" '("user1" "user2"))))
  (if (and allowed (not denied))
      (format t "[test] ✓ Permission system works correctly~%")
      (format t "[test] ✗ Permission system failed (allowed: ~A, denied: ~A)~%" allowed denied)))

;; Test 6: Test auto-reply system
(format t "~&[test] Test 6: Testing auto-reply system...~%")
(let* ((config (nilclaw/channel:make-auto-reply-config
                :rules (list (nilclaw/channel:make-auto-reply-rule
                              :name "ping-pong"
                              :trigger-type :exact
                              :trigger-pattern "ping"
                              :response "pong"
                              :enabled t
                              :priority 0))
                :enabled t
                :fallback-response "I don't understand"))
       (runtime (nilclaw/channel:make-auto-reply-runtime :config config)))
  (let ((reply (nilclaw/channel:compute-auto-reply runtime "ping" "test-session")))
    (if (and reply (string= reply "pong"))
        (format t "[test] ✓ Auto-reply works correctly~%")
        (format t "[test] ✗ Auto-reply failed (got: ~A)~%" reply))))

;; Test 7: Test auto-reply rate limiting
(format t "~&[test] Test 7: Testing auto-reply rate limiting...~%")
(let* ((config (nilclaw/channel:make-auto-reply-config
                :rules (list (nilclaw/channel:make-auto-reply-rule
                              :name "ping-pong"
                              :trigger-type :exact
                              :trigger-pattern "ping"
                              :response "pong"
                              :enabled t
                              :priority 0))
                :enabled t
                :max-replies-per-hour 2))
       (runtime (nilclaw/channel:make-auto-reply-runtime :config config)))
  ;; Should allow first two
  (let ((reply1 (nilclaw/channel:compute-auto-reply runtime "ping" "session1"))
        (reply2 (nilclaw/channel:compute-auto-reply runtime "ping" "session1"))
        (reply3 (nilclaw/channel:compute-auto-reply runtime "ping" "session1")))
    (if (and reply1 reply2 (not reply3))
        (format t "[test] ✓ Rate limiting works correctly~%")
        (format t "[test] ✗ Rate limiting failed (r1: ~A, r2: ~A, r3: ~A)~%"
                (and reply1 t) (and reply2 t) (and reply3 t)))))

(format t "~&[test] Channel system tests complete.~%")
(uiop:quit 0)
