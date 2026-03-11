(in-package #:nilclaw/gateway)

;;; --- Protocol frame types ---

(defstruct gateway-event
  "An outbound event frame from gateway to client."
  (event "" :type string)
  (payload nil :type list)
  (seq 0 :type (integer 0 *)))

(defstruct gateway-method-event
  "A method-style event frame (e.g., chat.message, sessions.update)."
  (method "" :type string)
  (params nil :type list)
  (seq 0 :type (integer 0 *)))

;;; --- Session store (in-memory) ---

(defstruct gateway-session
  "A session record in the gateway."
  (key "" :type string)
  (label "" :type string)
  (agent-id "" :type string)
  (created-at 0 :type integer)
  (messages nil :type list))

(defstruct gateway-message
  "A message within a session."
  (role "user" :type string)
  (content "" :type string)
  (timestamp 0 :type integer))

;;; --- Agent registry ---

(defstruct gateway-agent
  "A registered agent."
  (id "" :type string)
  (display-name "" :type string))

;;; --- Model registry ---

(defstruct gateway-model
  "An available model."
  (id "" :type string)
  (name "" :type string)
  (provider "" :type string))

;;; --- Connection state ---

(defstruct gateway-connection
  "State for a connected client."
  (nonce "" :type string)
  (authenticated nil :type boolean)
  (client-id "" :type string)
  (client-display-name "" :type string)
  (protocol-version 3 :type integer)
  (tick-interval-ms 30000 :type integer))

;;; --- Event stream state ---

(defstruct event-stream
  "Tracks event stream state for ordering, dedupe, and reconnect."
  (next-seq 1 :type (integer 0 *))         ; next sequence number to assign
  (emitted nil :type list)                  ; list of emitted events with seq
  (seen-ids nil :type list)                 ; idempotency keys already processed (for dedupe)
  (last-ack-seq 0 :type (integer 0 *))     ; last seq acknowledged by client
  (connected-p t :type boolean)             ; whether client is currently connected
  (reconnect-count 0 :type (integer 0 *))) ; number of reconnections
