# MCP Client Specification

## Overview

The MCP (Model Context Protocol) client spawns external tool servers as
child processes, communicates via JSON-RPC 2.0 over newline-delimited stdio,
and wraps discovered tools into the standard Tool vtable for seamless
integration with the agent's tool system.

## Protocol

- **Transport**: stdio (stdin/stdout pipes to child process)
- **Format**: JSON-RPC 2.0, newline-delimited
- **Protocol version**: `2024-11-05`

## McpServer

### Configuration

| Field    | Type       | Description                       |
|----------|------------|-----------------------------------|
| `name`   | string     | Server identifier                 |
| `command`| string     | Command to launch server          |
| `args`   | string[]   | Command arguments                 |
| `env`    | KV pairs[] | Environment variable overrides    |

### Connection Lifecycle

1. **Spawn**: Launch child process with stdin/stdout/stderr pipes
2. **Environment**: Inherit key parent vars (PATH, HOME, etc.) + config overrides
3. **Initialize**: Send `initialize` request with client info
4. **Verify**: Check response has valid `protocolVersion` in result
5. **Notify**: Send `notifications/initialized` notification
6. **Discover**: Call `tools/list` to get available tools
7. **Wrap**: Create McpToolWrapper for each discovered tool

### Inherited Environment Variables

PATH, HOME, TERM, LANG, LC_ALL, LC_CTYPE, USER, SHELL, TMPDIR, NODE_PATH,
NPM_CONFIG_PREFIX, and Windows equivalents (USERPROFILE, APPDATA, etc.)

### Initialize Handshake

Request:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "capabilities": {},
    "clientInfo": {"name": "nullclaw", "version": "<version>"}
  }
}
```

Expected response must contain `result.protocolVersion`.

### Tool Discovery

Request: `tools/list` with params `{}`

Response format:
```json
{
  "result": {
    "tools": [
      {
        "name": "read_file",
        "description": "Read a file",
        "inputSchema": {"type": "object", "properties": {...}}
      }
    ]
  }
}
```

### Tool Invocation

Request: `tools/call` with params:
```json
{
  "name": "<original_tool_name>",
  "arguments": {<tool_args>}
}
```

Response format:
```json
{
  "result": {
    "content": [
      {"type": "text", "text": "<output>"}
    ]
  }
}
```

Multiple content items are joined with newlines.

## McpToolWrapper

Adapts an MCP tool definition into the standard Tool vtable interface.

### Tool Naming Convention

MCP tools are prefixed to avoid collisions with built-in tools:
```
mcp_<server_name>_<tool_name>
```

Example: server `fs` with tool `read_file` → `mcp_fs_read_file`

### Execution Flow

1. Re-serialize ObjectMap arguments to JSON string
2. Call `server.callTool(original_name, args_json)`
3. Parse response content
4. Return as ToolResult

### Ownership

- First wrapper for a server has `owns_server = true` (responsible for cleanup)
- Subsequent wrappers from the same server have `owns_server = false`

## Initialization

`initMcpTools(allocator, configs)`:

For each server config:
1. Create McpServer instance
2. Connect (spawn + handshake)
3. List tools
4. Wrap each tool with McpToolWrapper
5. Add to output list

**Error handling**: Failures on individual servers are logged and skipped.
The system continues with remaining servers.

## Error Handling

| Error            | Cause                              |
|------------------|------------------------------------|
| `InvalidHandshake`| Initialize response malformed     |
| `JsonRpcError`   | Server returned JSON-RPC error     |
| `InvalidJson`    | Response is not valid JSON         |
| `MissingResult`  | No `result` field in response      |
| `NoStdin`        | Child process stdin unavailable    |
| `NoStdout`       | Child process stdout unavailable   |
| `EndOfStream`    | Child process closed stdout        |

## Integration Points

- **Tool system**: MCP tools registered via `allTools()` `mcp_tools` parameter
- **Config**: `mcp_servers` config section defines server list
- **Agent core**: MCP tools appear in tool specs sent to LLM
- **MCP filter groups**: `tool_filter_groups` can include/exclude MCP tools
  using glob patterns (tools starting with `mcp_` are subject to filtering)
