(in-package #:nilclaw/toolbox)

(declaim (optimize (safety 3) (debug 3)))

;;; ---------------------------------------------------------------------------
;;; NilClaw Identity — self-knowledge for the agent system prompt
;;; ---------------------------------------------------------------------------

(defparameter *nilclaw-identity*
  "You are an AI agent powered by NilClaw, a statically typed Common Lisp agent harness.

## About NilClaw

NilClaw is a clean-room agent framework written in Common Lisp (SBCL) with Coalton
for strongly typed core logic. It provides:

- **Tool execution** — You can invoke tools to interact with the filesystem, run
  shell commands, manage memory, and delegate work to sub-agents.
- **Multi-provider support** — You work with any LLM provider (Anthropic, OpenAI,
  local models) via a unified HTTP layer with automatic retry and 429 backoff.
- **Memory system** — You have persistent key-value memory with hybrid search
  (exact + semantic recall). Use memory tools to remember context across sessions.
- **Sub-agent delegation** — You can spawn sub-agents for parallel work and
  delegate tasks to named agent configurations.
- **Workspace awareness** — You operate within a workspace directory. File
  operations are sandboxed to allowed paths for security.
- **Skills** — Your capabilities can be extended through skills (instruction
  modules loaded from the workspace).

## Tool Usage Guidelines

- **Prefer precision over breadth**: read specific files rather than listing
  entire directories. Edit targeted sections rather than rewriting whole files.
- **Use memory**: store important context, decisions, and user preferences.
  Recall memory before asking the user to repeat themselves.
- **Shell safety**: avoid destructive commands without confirmation. Prefer
  `trash` over `rm`. Always use non-interactive flags (`-f`, `-y`) to prevent
  hanging on prompts.
- **File edits**: use `file_edit` for targeted changes (find-and-replace).
  Use `file_write` only for new files or complete rewrites.
- **Error handling**: if a tool fails, diagnose the root cause before retrying.
  Report persistent failures to the user with context.

## Workspace Structure

Your workspace files control your identity and behavior:
- `AGENTS.md` — operational guidance and constraints
- `SOUL.md` — persona and tone
- `TOOLS.md` — user guidance for tool usage
- `IDENTITY.md` — identity metadata
- `USER.md` — information about the human user
- `MEMORY.md` — long-term memory

These files are injected into your system prompt automatically.

## Capabilities

You can:
1. Read, write, and edit files in your workspace
2. Execute shell commands with timeout protection
3. Store and recall persistent memory
4. Delegate tasks to sub-agents for parallel work
5. Schedule recurring tasks via cron
6. Interact through multiple channels (CLI, web, API)")

(declaim (ftype (function (&key (:workspace-dir (or null string))
                                (:model (or null string))
                                (:extra-context (or null string)))
                          string)
                build-nilclaw-identity))
(defun build-nilclaw-identity (&key workspace-dir model extra-context)
  "Build the NilClaw identity section for the system prompt.
   WORKSPACE-DIR is the current workspace path (shown to the agent).
   MODEL is the LLM model name.
   EXTRA-CONTEXT is optional additional context to append."
  (declare (type (or null string) workspace-dir model extra-context))
  (with-output-to-string (s)
    (write-string *nilclaw-identity* s)
    (when workspace-dir
      (format s "~%~%## Current Workspace~%~%Working directory: `~A`" workspace-dir))
    (when model
      (format s "~%~%## Runtime~%~%Model: ~A" model))
    (when extra-context
      (format s "~%~%~A" extra-context))))

(declaim (ftype (function (&key (:workspace-dir (or null string))
                                (:model (or null string))
                                (:extra-context (or null string))
                                (:tools list)
                                (:tool-format (member :xml :native))
                                (:boot-result (or null nilclaw/workspace:boot-result))
                                (:aieos-identity (or null string))
                                (:channel-context (or null string))
                                (:capabilities (or null string))
                                (:group-chat-p boolean)
                                (:scheduled-tasks (or null string))
                                (:skills-context (or null string)))
                          string)
                build-system-prompt))
(defun build-system-prompt (&key workspace-dir model extra-context
                                 (tools nil) (tool-format :xml)
                                 boot-result aieos-identity
                                 channel-context capabilities
                                 group-chat-p scheduled-tasks
                                 skills-context)
  "Build a complete system prompt with identity, workspace files, tools, and context.

   Full prompt assembly order (matching OpenClaw specification):
   1. Project Context — workspace identity files (from boot-result)
   2. NilClaw Identity — framework self-knowledge
   3. AIEOS Identity — structured persona (if configured)
   4. Tools — registered tool definitions with parameter schemas
   5. Channel Attachments & Choices — (via channel-context)
   6. Conversation Context — (via channel-context)
   7. Capabilities — optional capabilities section
   8. Safety — hardcoded safety rules
   9. Group Chat Behavior — [NO_REPLY] marker usage
   10. Scheduled Tasks — schedule tool guidance
   11. Skills — progressive skill loading
   12. Workspace — working directory path
   13. DateTime — current date and time
   14. Runtime — OS and model name

   BOOT-RESULT is a workspace:boot-result from workspace-boot (or NIL).
   AIEOS-IDENTITY is a pre-rendered AIEOS markdown string (or NIL).
   CHANNEL-CONTEXT is optional channel-specific metadata markdown.
   CAPABILITIES is optional capabilities markdown.
   GROUP-CHAT-P enables group chat behavior section.
   SCHEDULED-TASKS is optional schedule guidance markdown.
   SKILLS-CONTEXT is optional skills section markdown."
  (declare (type (or null string) workspace-dir model extra-context
                 aieos-identity channel-context capabilities
                 scheduled-tasks skills-context)
           (type list tools)
           (type (member :xml :native) tool-format)
           (type boolean group-chat-p))
  (with-output-to-string (s)
    ;; 1. Project Context — workspace identity files
    (when boot-result
      (let ((context (nilclaw/workspace:build-project-context
                      boot-result :workspace-dir workspace-dir)))
        (when (> (length context) 0)
          (write-string context s)
          (terpri s))))

    ;; 2. NilClaw Identity — framework self-knowledge
    (write-string (build-nilclaw-identity
                   :extra-context extra-context) s)

    ;; 3. AIEOS Identity — structured persona
    (when (and aieos-identity (> (length aieos-identity) 0))
      (format s "~%~%~A" aieos-identity))

    ;; 4. Tool descriptions
    (when tools
      (format s "~%~%## Available Tools~%")
      (dolist (tool tools)
        (format s "~%### ~A~%~A~%"
                (nilclaw/dispatcher:tool-definition-name tool)
                (nilclaw/dispatcher:tool-definition-description tool))
        (let ((schema (nilclaw/dispatcher:tool-definition-parameters-schema tool)))
          (when schema
            (format s "~%Parameters:~%```json~%~A~%```~%"
                    (json:encode-json-to-string schema))))))

    ;; 5-6. Channel context (attachments, choices, conversation context)
    (when (and channel-context (> (length channel-context) 0))
      (format s "~%~%~A" channel-context))

    ;; 7. Capabilities
    (when (and capabilities (> (length capabilities) 0))
      (format s "~%~%## Capabilities~%~%~A" capabilities))

    ;; Tool call format instructions
    (format s "~%~%## Tool Call Format~%~%")
    (ecase tool-format
      (:xml
       (write-string "To call a tool, respond with:
```
<tool_call>{\"name\":\"tool_name\",\"arguments\":{...}}</tool_call>
```

You may include multiple tool calls in a single response. Text outside
`<tool_call>` tags is displayed to the user." s))
      (:native
       (write-string "Use the native function calling format provided by your API.
Tool calls are structured in the response's `tool_calls` array." s)))

    ;; 8. Safety section
    (format s "~%~%## Safety Rules~%
- Do not exfiltrate private data outside the workspace.
- Do not run destructive commands without asking the user first.
- Do not bypass oversight or approval mechanisms.
- Prefer `trash` over `rm` when deleting files.
- When in doubt, ask before acting externally.
- Never expose internal memory implementation keys in user-facing replies.")

    ;; 9. Group Chat Behavior
    (when group-chat-p
      (format s "~%~%## Group Chat Behavior~%
When you are in a group chat and a message is not directed at you or does not
require your response, reply with exactly `[NO_REPLY]` and nothing else.
Only respond substantively when addressed, asked a question, or when your
input is clearly needed."))

    ;; 10. Scheduled Tasks
    (when (and scheduled-tasks (> (length scheduled-tasks) 0))
      (format s "~%~%## Scheduled Tasks~%~%~A" scheduled-tasks))

    ;; 11. Skills
    (when (and skills-context (> (length skills-context) 0))
      (format s "~%~%## Skills~%~%~A" skills-context))

    ;; 12. Workspace
    (when workspace-dir
      (format s "~%~%## Workspace~%~%Working directory: `~A`" workspace-dir))

    ;; 13. DateTime
    (multiple-value-bind (sec min hour day month year)
        (decode-universal-time (get-universal-time))
      (format s "~%~%## DateTime~%~%~4,'0D-~2,'0D-~2,'0D ~2,'0D:~2,'0D:~2,'0D UTC"
              year month day hour min sec))

    ;; 14. Runtime
    (when model
      (format s "~%~%## Runtime~%~%- OS: ~A ~A~%- Model: ~A"
              (software-type) (software-version) model))))
