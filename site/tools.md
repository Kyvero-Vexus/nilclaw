---
layout: default
title: Tool Execution
nav_order: 6
---

# Tool Execution

The tool execution framework provides registration, dispatch, and result plumbing for LLM tool calls.

## Overview

Tools are registered with a handler function. When the LLM requests a tool call, the dispatcher:

1. Parses the tool call from LLM output (XML, native, or function-tag format)
2. Looks up the handler in the registry
3. Executes the handler with error protection
4. Formats the result for the LLM

## Tool Registry

### Creating a Registry

```lisp
(defparameter *registry* (nilclaw/dispatcher:make-tool-registry))
```

### Registering Tools

```lisp
;; Register a simple tool
(nilclaw/dispatcher:register-tool *registry* "greet"
  (lambda (args)
    (format nil "Hello, ~A!" (gethash "name" args))))

;; Register with explicit handler
(defun my-read-handler (args)
  (let ((path (gethash "path" args)))
    (handler-case
      (uiop:read-file-string path)
      (error (e) (format nil "Error reading ~A: ~A" path e)))))

(nilclaw/dispatcher:register-tool *registry* "read" #'my-read-handler)
```

### Listing Tools

```lisp
(nilclaw/dispatcher:list-tools *registry*)
;; => (("greet" . #<FUNCTION>) ("read" . #<FUNCTION>))
```

### Looking Up Tools

```lisp
(nilclaw/dispatcher:lookup-tool *registry* "greet")
;; => #<FUNCTION>
```

## Tool Calls

### Creating Tool Calls

```lisp
(defparameter *call*
  (nilclaw/dispatcher:make-tool-call
    :name "greet"
    :arguments-json "{\"name\":\"World\"}"
    :id "call-123"))
```

### Parsing Tool Calls

The dispatcher supports multiple LLM output formats:

#### Native Format

```
<greet>{"name": "World"}</greet>
```

```lisp
(nilclaw/dispatcher:parse-native-tool-calls output)
```

#### XML Format

```xml
<function_calls>
<invoke name="greet">
<parameter name="name">World</parameter>
</invoke>
</function_calls>
```

```lisp
(nilclaw/dispatcher:parse-xml-tool-calls output)
```

#### Function Tag Format

```
<function=greet>{"name": "World"}</function>
```

```lisp
(nilclaw/dispatcher:parse-function-tag-tool-calls output)
```

### Auto-Detection

```lisp
;; Automatically detect format
(nilclaw/dispatcher:parse-tool-calls output)
```

## Execution

### Single Tool

```lisp
(nilclaw/dispatcher:execute-tool *registry* *call*)
;; => "Hello, World!"
```

### Batch Execution

```lisp
(defparameter *calls*
  (list
    (nilclaw/dispatcher:make-tool-call :name "greet" :arguments-json "{\"name\":\"Alice\"}")
    (nilclaw/dispatcher:make-tool-call :name "greet" :arguments-json "{\"name\":\"Bob\"}")))

(nilclaw/dispatcher:execute-tools *registry* *calls)
;; => ("Hello, Alice!" "Hello, Bob!")
```

### With Iteration Limit

```lisp
;; Limit to 15 tool iterations
(nilclaw/dispatcher:execute-tool-loop *registry* *initial-call* 
  :max-iterations 15)
```

## Result Formatting

### For LLM

```lisp
;; Format as LLM-ready message
(nilclaw/dispatcher:format-tool-results *calls* results)
;; => "Tool results:\n1. greet: Hello, Alice!\n2. greet: Hello, Bob!"
```

### Native Format

```lisp
(nilclaw/dispatcher:format-native-tool-results *calls* results)
```

## Error Handling

Tools are executed with error protection:

```lisp
;; Handler throws error
(nilclaw/dispatcher:register-tool *registry* "fail"
  (lambda (args) (error "Intentional failure")))

;; Execution catches and returns error message
(nilclaw/dispatcher:execute-tool *registry* fail-call)
;; => "Error executing tool 'fail': Intentional failure"
```

## Tool Instructions

Generate tool instructions for the LLM:

```lisp
(nilclaw/dispatcher:build-tool-instructions *registry*)
;; => "Available tools:
;;     - greet: (handler)
;;     - read: (handler)
;;     ..."
```

## JSON Repair

The dispatcher includes JSON repair for malformed LLM output:

```lisp
;; Repair common JSON errors
(nilclaw/dispatcher:repair-json "{\"name\": 'World'}")
;; => "{\"name\": \"World\"}"
```

## Custom Parsers

Register custom parsers for proprietary formats:

```lisp
;; Add custom format detection
(setf (gethash "custom-format" nilclaw/dispatcher:*parsers*)
      #'my-custom-parser)
```
