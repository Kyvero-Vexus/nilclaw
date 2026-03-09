# Tool System Specification

## Overview

The tool system provides a vtable-based abstraction for agent capabilities.
Tools are registered at startup, their schemas are sent to the LLM as function
definitions, and the dispatcher handles parsing tool calls from LLM responses
and formatting results back into the conversation.

## Tool Interface

### VTable Methods

| Method           | Signature                                         | Required |
|------------------|---------------------------------------------------|----------|
| `execute`        | (allocator, args: JsonObjectMap) → ToolResult     | Yes      |
| `name`           | () → string                                       | Yes      |
| `description`    | () → string                                       | Yes      |
| `parameters_json`| () → string (JSON schema)                         | Yes      |
| `deinit`         | (allocator) → void                                | Optional |

### ToolResult

| Field      | Type    | Description                           |
|------------|---------|---------------------------------------|
| `success`  | bool    | Whether the tool succeeded            |
| `output`   | string  | Tool output (may be empty literal)    |
| `error_msg`| string? | Error message on failure              |

Ownership: `output` and `error_msg` are heap-allocated and owned by the caller,
except for static literals from `ToolResult.ok("")` / `ToolResult.fail("literal")`.

### ToolSpec

| Field            | Type   | Description                |
|------------------|--------|----------------------------|
| `name`           | string | Tool name                  |
| `description`    | string | Tool description           |
| `parameters_json`| string | JSON schema for parameters |

### Argument Extraction Helpers

| Helper          | Type       | Description                  |
|-----------------|------------|------------------------------|
| `getString`     | string?    | Extract string from args     |
| `getBool`       | bool?      | Extract boolean from args    |
| `getInt`        | i64?       | Extract integer from args    |
| `getValue`      | JsonValue? | Extract raw JSON value       |
| `getStringArray`| JsonValue[]?| Extract array of values     |

## Built-in Tools

### Core Tools (Always Available)

| Tool        | Description                                       |
|-------------|---------------------------------------------------|
| `shell`     | Execute shell commands                            |
| `file_read` | Read file contents                                |
| `file_write`| Write/create files                                |
| `file_edit` | Edit files with find-and-replace                  |

### Standard Tools (Always with `allTools`)

| Tool           | Description                                    |
|----------------|------------------------------------------------|
| `git`          | Git operations                                 |
| `image_info`   | Image metadata extraction                      |
| `memory_store` | Store key-value memory                         |
| `memory_recall`| Recall from memory (hybrid search)             |
| `memory_list`  | List memory entries                            |
| `memory_forget`| Delete memory entries                          |
| `delegate`     | Delegate to named sub-agents                   |
| `schedule`     | Create scheduled tasks                         |
| `spawn`        | Spawn async sub-agents                         |

### Optional Tools (Feature-Gated)

| Tool           | Gate                     | Description               |
|----------------|--------------------------|---------------------------|
| `pushover`     | `http_enabled`           | Push notifications        |
| `http_request` | `http_enabled`           | HTTP requests             |
| `web_search`   | `http_enabled`           | Web search (multi-provider)|
| `web_fetch`    | `http_enabled`           | Fetch/extract web content |
| `browser`      | `browser_enabled`        | Browser automation        |
| `screenshot`   | `screenshot_enabled`     | Take screenshots          |
| `composio`     | `composio_api_key` set   | Composio integrations     |
| `browser_open` | `browser_open_domains` set| Open URLs in browser     |
| `hardware_info`| `hardware_boards` set    | Hardware board info       |
| `hardware_memory`| `hardware_boards` set  | Hardware memory R/W       |
| `i2c`          | `hardware_boards` set    | I2C communication         |

### MCP Tools

Externally initialized tools (from MCP servers) are appended to the tool
list at startup. They use the same Tool interface.

### Subagent Tool Restrictions

Subagents receive a restricted tool set to prevent infinite loops and
cross-channel side effects:

**Included**: `shell`, `file_read`, `file_write`, `file_edit`, `git`,
`http_request` (if enabled)

**Excluded**: `message`, `spawn`, `delegate`, `schedule`, `memory_*`,
`composio`, `browser`, `screenshot`, `pushover`, `web_search`, `web_fetch`,
`cron_*`, `hardware_*`, `i2c`, `spi`

## Tool Dispatch Configuration

### Shell Tool

| Field             | Type   | Default                   | Description              |
|-------------------|--------|---------------------------|--------------------------|
| `workspace_dir`   | string | —                         | Working directory        |
| `allowed_paths`   | list   | `[]`                      | Additional allowed dirs  |
| `timeout_ns`      | u64    | `60 * ns_per_s`           | Execution timeout        |
| `max_output_bytes`| usize  | `1,048,576` (1 MB)        | Output truncation limit  |
| `policy`          | SecurityPolicy? | null              | Autonomy policy          |

### File Tools (read/write/edit)

| Field             | Type   | Default                   | Description              |
|-------------------|--------|---------------------------|--------------------------|
| `workspace_dir`   | string | —                         | Base directory           |
| `allowed_paths`   | list   | `[]`                      | Additional allowed dirs  |
| `max_file_size`   | u64    | `10,485,760` (10 MB)      | Max file size            |
| `bootstrap_provider`| BootstrapProvider? | null        | For workspace file writes|
| `backend_name`    | string | `"hybrid"`                | Memory backend name      |

### HTTP Request Tool

| Field              | Type   | Default      | Description           |
|--------------------|--------|--------------|-----------------------|
| `allowed_domains`  | list   | `[]`         | Domain allowlist      |
| `max_response_size`| u32    | `1,000,000`  | Max response bytes    |

### Web Search Tool

| Field                | Type   | Default  | Description              |
|----------------------|--------|----------|--------------------------|
| `searxng_base_url`   | string?| null     | SearXNG instance URL     |
| `provider`           | string | `"auto"` | Search provider          |
| `fallback_providers` | list   | `[]`     | Fallback provider chain  |
| `timeout_secs`       | u64    | `30`     | Search timeout           |

### Web Fetch Tool

| Field              | Type   | Default    | Description           |
|--------------------|--------|------------|-----------------------|
| `default_max_chars`| u32    | `100,000`  | Max extracted chars   |
| `allowed_domains`  | list   | `[]`       | Domain allowlist      |

### Delegate Tool

| Field             | Type   | Default | Description              |
|-------------------|--------|---------|--------------------------|
| `agents`          | list   | `[]`    | Available named agents   |
| `fallback_api_key`| string?| null    | Fallback API key         |
| `depth`           | u32    | `0`     | Current delegation depth |

### Spawn Tool

| Field    | Type              | Default | Description              |
|----------|-------------------|---------|--------------------------|
| `manager`| SubagentManager?  | null    | Subagent lifecycle mgr   |

## Tool Call Parsing (Dispatcher)

### Parse Flow

1. Check for OpenAI native JSON format `{"tool_calls": [...]}`
2. If found, parse structured tool calls
3. If no calls found (or not native format), fall through to XML parsing
4. Parse `<tool_call>` XML tags from response text

### XML Tool Call Format

```
Some text before tool calls
<tool_call>
{"name": "shell", "arguments": {"command": "ls -la"}}
</tool_call>
More text between calls
<tool_call>
{"name": "file_read", "arguments": {"file_path": "README.md"}}
</tool_call>
```

Text outside `<tool_call>` tags is captured and joined as display text.

### Security: XML-Only Extraction

Tool calls are ONLY extracted from explicit `<tool_call>` tags. Raw JSON in
the response body is NOT parsed as tool calls, preventing prompt injection
where malicious content could include JSON mimicking tool calls.

### Native (Structured) Tool Calls

When a provider supports native tool calls (`supportsNativeTools() == true`)
and streaming is not active:
1. Provider returns `ChatResponse.tool_calls` array
2. Dispatcher converts each `ToolCall` → `ParsedToolCall`
3. If all structured calls are empty (no names), falls back to XML parsing

### Tool Call Markup Detection

`containsToolCallMarkup(text)` checks for:
- `<tool_call>`
- `[TOOL_CALL]`
- `[tool_call]`

Used to suppress raw tool-call markup from user-visible output.

### Result Formatting

Tool results are formatted back into the conversation as messages with
role `tool`, including the `tool_call_id` for correlation.

### Tool Instructions

The dispatcher builds tool usage instructions that are appended to the
system prompt, explaining the XML `<tool_call>` format to the LLM.

## Memory Tool Binding

Memory tools are created without a backend and bound later:

1. `bindMemoryTools(tools, memory)` — connects Memory interface
2. `bindMemoryRuntime(tools, mem_rt)` — connects MemoryRuntime for hybrid search

Binding works by vtable identity matching (not by tool name), ensuring
that tools with colliding names are not incorrectly bound.

## Path Security

All file and shell tools validate paths through a security module:
- Paths must be within `workspace_dir` or `allowed_paths`
- System-critical paths are always blocked
- Symbolic links are resolved (realpath) before checking
- Path traversal attacks (`..`) are blocked

## Default Tool Sets

### `defaultTools` (4 tools)
`shell`, `file_read`, `file_write`, `file_edit`

### `allTools` (13-18+ tools depending on config)
All standard tools + optional tools based on config flags + MCP tools

### `subagentTools` (5-6 tools)
`shell`, `file_read`, `file_write`, `file_edit`, `git`, optional `http_request`

## Integration Points

- **Agent core**: passes tool specs to provider, executes tools during turn loop
- **Provider**: receives tool specs for function-calling API
- **Config**: `tools.*` settings configure tool limits
- **Security**: `SecurityPolicy` checked before shell execution
- **Memory**: memory tools bound to memory backend post-initialization
- **MCP**: external MCP tools injected into tool list at startup
- **Bootstrap**: file_write and file_edit update bootstrap files when applicable
