# Agent Dispatcher Test Specifications

## Overview
The dispatcher module handles parsing of tool calls from LLM responses, formatting tool results for context injection, JSON extraction/repair, and support for multiple tool call formats (XML, native/OpenAI JSON, function-tag, and various hybrid formats from different model providers).

---

## XML Tool Call Parsing (parseToolCalls / parseXmlToolCalls)

### Extracts single call
- **Input**: Text + `<tool_call>{"name": "shell", "arguments": {"command": "ls -la"}}</tool_call>`
- **Expected**: 1 call, name="shell", arguments contain "ls -la", text before tags preserved

### Extracts multiple calls
- **Input**: Two `<tool_call>` blocks with name="file_read"
- **Expected**: 2 calls, both named "file_read"

### Three consecutive calls
- **Input**: Three tool_call blocks with names "a", "b", "c"
- **Expected**: 3 calls in order

### Returns text only when no calls
- **Input**: "Just a normal response with no tools."
- **Expected**: 0 calls, full text preserved

### Handles text before and after
- **Input**: "Before text." + tool_call + "After text."
- **Expected**: Both "Before text." and "After text." in result text, 1 call

### Rejects raw JSON without tags
- **Input**: JSON object without `<tool_call>` wrapper
- **Expected**: 0 calls (raw JSON treated as text)

### Handles markdown fenced JSON
- **Input**: `<tool_call>` containing ` ```json {...} ``` `
- **Expected**: 1 call, JSON parsed correctly from fenced block

### Handles preamble text inside tag
- **Input**: `<tool_call>` with "I will now call the tool:" before the JSON
- **Expected**: 1 call, preamble text skipped, JSON parsed

### Empty string
- **Input**: ""
- **Expected**: 0 calls, empty text

### Unclosed tag
- **Input**: `<tool_call>` without `</tool_call>`
- **Expected**: 0 calls, original text preserved as-is (no duplication)

### Compact call with malformed closing tag
- **Input**: `<tool_call>memory_list{"limit": 10, "include_content": true}</arg_value>`
- **Expected**: 1 call, name="memory_list", arguments parsed correctly (limit=10, include_content=true)

### Compact malformed close with XML-like argument content
- **Input**: `<tool_call>file_write{"path":"index.html","content":"</html>"}</arg_value>`
- **Expected**: 1 call, name="file_write", content value is "</html>"

### Compact call with no closing tag
- **Input**: `<tool_call>file_read{"path": "/home/user/.nullclaw/void.md"}`
- **Expected**: 1 call, name="file_read", path parsed correctly

### Malformed JSON inside tag → skipped
- **Input**: `<tool_call>this is not json</tool_call>`
- **Expected**: 0 calls

### Malformed XML-like arg_key payload → skipped
- **Input**: `<tool_call>web_search<arg_key>query</arg_key><arg_value>...</arg_value></tool_call>`
- **Expected**: 0 calls (non-JSON, non-function-tag format rejected)

### Empty arguments defaults to empty object
- **Input**: `<tool_call>{"name": "shell"}</tool_call>` (no "arguments" key)
- **Expected**: 1 call, arguments_json="{}"

### Whitespace-only inside tag
- **Input**: `<tool_call>   \n   </tool_call>`
- **Expected**: 0 calls

---

## Function-Tag Format

### Single parameter
- **Input**: `<function=shell><parameter=command>ps aux | grep nullclaw</parameter></function>`
- **Expected**: name="shell", arguments contain "command" and "ps aux | grep nullclaw"

### Multiple parameters
- **Input**: `<function=file_write><parameter=path>/tmp/test.txt</parameter><parameter=content>hello world</parameter></function>`
- **Expected**: name="file_write", both path and content parameters present

### Whitespace and newlines handled
- **Input**: Function tag with newlines between tags
- **Expected**: Parsed correctly, "ls -la" extracted

### No function tag → error
- **Input**: "just plain text"
- **Expected**: NoFunctionTag error

### Value with quotes is JSON-escaped
- **Input**: `<parameter=command>echo "hello world"</parameter>`
- **Expected**: Valid JSON, command value is `echo "hello world"` (quotes properly escaped)

### Function-tag inside tool_call
- **Input**: `<tool_call><function=shell>...</function></tool_call>`
- **Expected**: 1 call, parsed via function-tag parser

### Function-tag with surrounding text
- **Input**: Text before and after the tool_call with function-tag inside
- **Expected**: Text preserved, 1 call parsed

### Parameters bounded by `</function>`
- **Input**: Two function blocks concatenated
- **Expected**: Only first function's parameters extracted; second function's params do NOT leak

### Invalid function name with special chars
- Names containing `"`, `<`, or spaces → InvalidFunctionName error

### Valid names with dots, dashes, underscores
- "my-tool_v2.0" → accepted

---

## Format Results

### Single result produces XML
- **Input**: ToolExecutionResult {name="shell", output="hello world", success=true}
- **Expected**: XML output with `<tool_result>`, tool name, output content, "ok" status

### Marks errors
- **Input**: ToolExecutionResult {success=false, output="permission denied"}
- **Expected**: Contains "error" marker

### Empty results
- **Expected**: Contains "Tool results" text

### Multiple results
- **Input**: 3 results (2 success, 1 failure)
- **Expected**: All names and outputs present in formatted string

### With tool_call_id
- **Input**: Result with tool_call_id="tc-123"
- **Expected**: Contains tool name and output

---

## JSON Object Extraction (extractJsonObject)

### Finds nested object
- `"some text {\"key\": {\"nested\": true}} more text"` → `{\"key\": {\"nested\": true}}`

### Returns null for no object
- "no json here" → null

### Unmatched close brace does not panic
- "} not an object …" → no crash (depth underflow protection)

### Unmatched close bracket does not panic
- "] some text …" → no crash

### With leading text
- "Here is the result: {…}" → extracts the object

### Deeply nested
- `{"a":{"b":{"c":true}}}` → entire string

### String containing braces
- `{"key": "value with { and } inside"}` → entire string (braces in strings don't affect depth)

### Empty string → null
### Unmatched brace → null

### Finds array
- "some text [1, 2, 3] more text" → "[1, 2, 3]"

### Finds nested array
- "[[1, 2], [3, 4]]" → entire string

### Prefers earlier bracket/brace
- "[{…}]" → array (bracket comes first)
- "{\"arr\": [1, 2]}" → object (brace comes first)

---

## Native/OpenAI Tool Call Format

### isNativeFormat detects OpenAI tool_calls
- JSON with "tool_calls" array → true
- XML format → false
- Plain text → false
- "tool_calls" in non-JSON context → false

### isNativeJsonFormat
- Valid native JSON → true
- With leading whitespace → true
- XML response → false
- Plain text → false
- Empty string → false
- Array → false

### containsToolCallMarkup
- `<tool_call>…</tool_call>` → true
- `[TOOL_CALL]…[/TOOL_CALL]` → true
- `[tool_call]…[/tool_call]` → true (case variants)
- Plain text → false

### parseNativeToolCalls single call
- JSON with content + tool_calls array (1 entry)
- **Expected**: text="I will list files.", 1 call, name="shell", tool_call_id="call_abc"

### parseNativeToolCalls multiple calls
- JSON with 2 tool_call entries
- **Expected**: 2 calls with correct names and tool_call_ids

### Null content
- `{"content":null, "tool_calls":[…]}`
- **Expected**: text="" (empty string), calls parsed

### No tool_calls key
- `{"content":"Just text."}`
- **Expected**: 0 calls, text preserved

### Empty tool_calls array
- **Expected**: 0 calls, text preserved

### Skips entries without function field
- Entry missing "function" key → skipped, next valid entry parsed

### Skips entries with empty function name
- `"name": ""` → skipped

### Preserves tool_call_id
- id="call_xyz789" → preserved in parsed result

---

## Native Tool Result Formatting

### Single result
- **Expected**: Valid JSON array, role="tool", tool_call_id present, content matches

### Multiple results
- **Expected**: JSON array with 2 entries, correct tool_call_ids

### Missing tool_call_id defaults to "unknown"
- **Expected**: tool_call_id="unknown" in output

### Empty results → "[]"

### Escapes special characters in output
- newlines, tabs, quotes in output → valid JSON (parseable)

---

## Dispatcher Kind

### Enum values distinct
- xml and native have different integer representations

---

## Auto-routing Between Formats

### parseToolCalls routes OpenAI JSON to native parser
- JSON with tool_calls → parsed via native parser, tool_call_id preserved

### parseToolCalls falls back to XML when JSON has no tool_calls
- XML format → parsed via XML parser

---

## Structured Tool Call Parsing (parseStructuredToolCalls)

### Converts ToolCall slice
- 2 ToolCalls → 2 ParsedToolCalls with names, arguments, and tool_call_ids

### Skips empty name
- Entry with name="" → skipped

### Empty input → empty output

### Empty id becomes null
- id="" → tool_call_id=null

---

## JSON Repair (repairJson)

### Removes trailing commas
- `{"key": "value",}` → valid JSON

### Removes trailing comma in array
- `[1, 2, 3,]` → valid JSON with 3 elements

### Balances unclosed braces
- `{"name": "shell", "arguments": {"command": "ls"` → balanced, valid JSON

### Balances unclosed brackets
- `[1, 2, 3` → balanced, valid JSON with 3 elements

### Balances unclosed quote
- `{"name": "shell}` → repaired (quotes balanced)

### Escapes newlines in strings
- Literal newlines inside JSON strings → escaped, valid JSON

### Passes through valid JSON unchanged

### Handles combined issues
- Trailing comma + unclosed brace → repaired, valid JSON

### parseToolCallJson with trailing comma repair
- Tool call JSON with trailing comma → parsed correctly, name extracted

### parseToolCallJson with unclosed brace repair
- Tool call JSON with missing closing brace → parsed correctly

### parseToolCallJson robustness
- JSON-in-JSON name field → extracts inner "name" value
- Trailing XML tag in name (`shell</arg_value>`) → cleaned to "shell"
- JSON-like name without nested "name" → keeps outer name text

---

## Vendor-Specific Formats

### Minimax format
- `<tool_call><invoke name="shell"><parameter name="command">ls</parameter></invoke></minimax:tool_call>`
- **Expected**: Parsed correctly, 1 call

### Minimax format robustness
- Malformed comma after invoke name → still parsed

### Hybrid format (JSON name + parameter tags)
- `<tool_call>{"name": "shell", <parameter name="command">…</parameter></tool_call>`
- **Expected**: Parsed, name and arguments extracted

### Tool-tag hybrid format
- `<tool_call><tool name="shell"><parameter name="command">ls</parameter></tool></tool_call>`
- **Expected**: Parsed correctly

### Square bracket format
- `[TOOL_CALL]<invoke name="shell">…</invoke>[/TOOL_CALL]`
- **Expected**: Parsed correctly

### Function-tag fallback when JSON has braces in value
- Parameter value contains `{hello}` → extractJsonObject picks it up but parseToolCallJson fails → function-tag tried as fallback → success

---

## ParsedToolCall / ToolExecutionResult Defaults

### ParsedToolCall default tool_call_id is null
### ToolExecutionResult default tool_call_id is null

---

## Build Tool Instructions

### Empty tools
- **Expected**: Output contains "Tool Use Protocol" and "tool_call"

---

## buildAssistantHistoryWithToolCalls

### With text and calls
- Text + 2 calls → output contains text, 2 `<tool_call>` blocks, tool names

### Empty text
- No text + 1 call → output starts with `<` (no empty prefix)

### No calls
- Text + 0 calls → output is text + newline

### Empty text and no calls → empty string

### Preserves arguments JSON
- Arguments including code content preserved in output

### Escapes special chars in name
- Tool name with `"` → properly JSON-escaped, valid JSON inside `<tool_call>` tags
