(in-package #:nilclaw/dispatcher)

(declaim (optimize (safety 3) (debug 3)))

(defstruct tool-call
  (name "" :type string)
  (arguments-json "{}" :type string)
  (id nil :type (or null string)))
