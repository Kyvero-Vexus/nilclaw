(defpackage #:nilclaw/dispatcher
  (:use #:cl)
  (:export
   #:tool-call
   #:tool-call-name
   #:tool-call-arguments-json
   #:tool-call-id
   #:parse-tool-calls
   #:parse-xml-tool-calls
   #:parse-function-tag
   #:extract-json-object
   #:is-native-format
   #:is-native-json-format
   #:contains-tool-call-markup
   #:parse-native-tool-calls
   #:format-tool-results
   #:format-native-tool-results
   #:repair-json
   #:build-tool-instructions
   #:build-assistant-history-with-tool-calls))