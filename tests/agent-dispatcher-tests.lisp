(in-package #:nilclaw/tests)
(in-suite agent-dispatcher-suite)

(test dispatcher-xml-single-and-multiple
  (multiple-value-bind (calls text)
      (nilclaw/dispatcher:parse-tool-calls
       "Before <tool_call>{\"name\":\"shell\",\"arguments\":{\"command\":\"ls -la\"}}</tool_call> After")
    (is (= 1 (length calls)))
    (is (string= "shell" (nilclaw/dispatcher:tool-call-name (first calls))))
    (is (search "ls -la" (nilclaw/dispatcher:tool-call-arguments-json (first calls))))
    (is (search "Before" text))
    (is (search "After" text)))
  (multiple-value-bind (calls text)
      (nilclaw/dispatcher:parse-tool-calls
       "<tool_call>{\"name\":\"a\",\"arguments\":{}}</tool_call><tool_call>{\"name\":\"b\",\"arguments\":{}}</tool_call><tool_call>{\"name\":\"c\",\"arguments\":{}}</tool_call>")
    (declare (ignore text))
    (is (= 3 (length calls)))
    (is (string= "a" (nilclaw/dispatcher:tool-call-name (first calls))))
    (is (string= "b" (nilclaw/dispatcher:tool-call-name (second calls))))
    (is (string= "c" (nilclaw/dispatcher:tool-call-name (third calls))))))

(test dispatcher-xml-edge-cases
  (multiple-value-bind (calls text)
      (nilclaw/dispatcher:parse-tool-calls "Just normal response")
    (is (null calls))
    (is (string= "Just normal response" text)))
  (multiple-value-bind (calls text)
      (nilclaw/dispatcher:parse-tool-calls "")
    (is (null calls))
    (is (string= "" text)))
  (multiple-value-bind (calls text)
      (nilclaw/dispatcher:parse-tool-calls "<tool_call>{\"name\":\"x\",\"arguments\":{}}</tool_call>")
    (is (= 1 (length calls)))
    (is (string= "x" (nilclaw/dispatcher:tool-call-name (first calls))))
    (is (string= "" text)))
  (multiple-value-bind (calls text)
      (nilclaw/dispatcher:parse-tool-calls "<tool_call>memory_list{\"limit\":10}</arg_value>")
    (declare (ignore text))
    (is (listp calls)))
  (multiple-value-bind (calls text)
      (nilclaw/dispatcher:parse-tool-calls "<tool_call>this is not json</tool_call>")
    (declare (ignore text))
    (is (null calls))))

(test dispatcher-function-tag
  (let ((call (nilclaw/dispatcher:parse-function-tag "<function=shell><parameter=command>ps aux | grep nilclaw</parameter></function>")))
    (is (string= "shell" (nilclaw/dispatcher:tool-call-name call)))
    (is (search "command" (nilclaw/dispatcher:tool-call-arguments-json call))))
  (let ((call (nilclaw/dispatcher:parse-function-tag "<function=file_write><parameter=path>/tmp/test.txt</parameter><parameter=content>hello world</parameter></function>")))
    (is (string= "file_write" (nilclaw/dispatcher:tool-call-name call)))
    (is (search "hello world" (nilclaw/dispatcher:tool-call-arguments-json call))))
  (signals error (nilclaw/dispatcher:parse-function-tag "plain text"))
  (signals error (nilclaw/dispatcher:parse-function-tag "<function=bad name><parameter=x>y</parameter></function>"))
  (multiple-value-bind (calls txt)
      (nilclaw/dispatcher:parse-tool-calls
       "foo <tool_call><function=shell><parameter=command>echo \"hello\"</parameter></function></tool_call> bar")
    (is (= 1 (length calls)))
    (is (search "foo" txt))
    (is (search "bar" txt))))

(test dispatcher-json-extract
  (is (string= "{\"key\":{\"nested\":true}}"
               (nilclaw/dispatcher:extract-json-object "some text {\"key\":{\"nested\":true}} more text")))
  (is (null (nilclaw/dispatcher:extract-json-object "no json here")))
  (is (null (nilclaw/dispatcher:extract-json-object "] some text")))
  (is (string= "[1, 2, 3]"
               (nilclaw/dispatcher:extract-json-object "some text [1, 2, 3] more text")))
  (is (string= "[{\"a\":1}]"
               (nilclaw/dispatcher:extract-json-object "xx [{\"a\":1}] yy"))))

(test dispatcher-native-format
  (is (nilclaw/dispatcher:is-native-format "{\"content\":\"x\",\"tool_calls\":[]}"))
  (is (nilclaw/dispatcher:is-native-json-format "  {\"content\":\"x\"}"))
  (is (not (nilclaw/dispatcher:is-native-json-format "<tool_call>..</tool_call>")))
  (is (nilclaw/dispatcher:contains-tool-call-markup "<tool_call>..</tool_call>"))
  (is (nilclaw/dispatcher:contains-tool-call-markup "[TOOL_CALL]x[/TOOL_CALL]"))
  (is (not (nilclaw/dispatcher:contains-tool-call-markup "plain text"))))

(test dispatcher-parse-native-tool-calls
  (multiple-value-bind (calls text)
      (nilclaw/dispatcher:parse-native-tool-calls
       "{\"content\":\"I will list files.\",\"tool_calls\":[{\"id\":\"call_abc\",\"function\":{\"name\":\"shell\",\"arguments\":{\"command\":\"ls\"}}}]}")
    (is (listp calls))
    (is (string= "I will list files." text)))
  (multiple-value-bind (calls text)
      (nilclaw/dispatcher:parse-native-tool-calls "{\"content\":null,\"tool_calls\":[]}")
    (is (null calls))
    (is (string= "" text)))
  (multiple-value-bind (calls text)
      (nilclaw/dispatcher:parse-native-tool-calls "{\"content\":\"Just text\"}")
    (is (null calls))
    (is (string= "Just text" text))))

(test dispatcher-format-results
  (let ((xml (nilclaw/dispatcher:format-tool-results
              (list (list :name "shell" :output "hello world" :success t :tool-call-id "tc-1")
                    (list :name "file_read" :output "permission denied" :success nil :tool-call-id "tc-2")))))
    (is (search "<tool_result>" xml))
    (is (search "shell" xml))
    (is (search "ok" xml))
    (is (search "error" xml))
    (is (search "tc-1" xml)))
  (let ((empty (nilclaw/dispatcher:format-tool-results nil)))
    (is (search "Tool results" empty))))

(test dispatcher-format-native-results
  (let ((json (nilclaw/dispatcher:format-native-tool-results
               (list (list :output "hello\n\t\"world\"" :tool-call-id "x")
                     (list :output "no id")))))
    (is (search "tool_call_id" json))
    (is (search "unknown" json))
    (is (search "hello" json)))
  (is (string= "[]" (nilclaw/dispatcher:format-native-tool-results nil))))

(test dispatcher-utilities
  (is (search "<tool_call>" (nilclaw/dispatcher:build-tool-instructions)))
  (let ((hist (nilclaw/dispatcher:build-assistant-history-with-tool-calls
               (list '((:role . "assistant") (:content . "x")))
               (list "one" "two"))))
    (is (= 3 (length hist))))
  (is (string= "{\"a\":1}" (nilclaw/dispatcher:repair-json "blah {\"a\":1} blah"))))
