---
layout: default
title: API Reference
nav_order: 5
---

# API Reference

## Gateway API

NilClaw exposes an HTTP/WebSocket API for external clients.

### Base URL

```
http://localhost:8080/
```

### Protocol

JSON-RPC 2.0 over HTTP/WebSocket.

## Methods

### `chat.send`

Send a chat message to the agent.

**Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "chat.send",
  "params": {
    "message": "Hello, NilClaw!",
    "session_key": "session-123",
    "channel": "cli"
  },
  "id": 1
}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "ok": true,
    "response": "Hello! How can I help you today?"
  },
  "id": 1
}
```

### `chat.history`

Retrieve chat history for a session.

**Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "chat.history",
  "params": {
    "session_key": "session-123",
    "limit": 50
  },
  "id": 2
}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "messages": [
      {"role": "user", "content": "Hello!"},
      {"role": "assistant", "content": "Hi there!"}
    ]
  },
  "id": 2
}
```

### `sessions.list`

List all active sessions.

**Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "sessions.list",
  "params": {},
  "id": 3
}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "sessions": [
      {"key": "session-123", "channel": "cli", "created_at": 1700000000}
    ]
  },
  "id": 3
}
```

### `agents.list`

List available agents.

**Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "agents.list",
  "params": {},
  "id": 4
}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "agents": [
      {"id": "default", "name": "NilClaw Agent", "model": "gpt-4o-mini"}
    ]
  },
  "id": 4
}
```

### `models.list`

List available models.

**Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "models.list",
  "params": {},
  "id": 5
}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "models": [
      {"id": "gpt-4o-mini", "provider": "openai"},
      {"id": "claude-3-sonnet", "provider": "anthropic"}
    ]
  },
  "id": 5
}
```

### `tools.list`

List available tools.

**Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools.list",
  "params": {},
  "id": 6
}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "tools": [
      {"name": "read", "description": "Read file contents"},
      {"name": "write", "description": "Write file contents"}
    ]
  },
  "id": 6
}
```

### `tools.execute`

Execute a tool.

**Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tools.execute",
  "params": {
    "name": "read",
    "arguments": {"path": "/tmp/test.txt"}
  },
  "id": 7
}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "ok": true,
    "content": "File contents here..."
  },
  "id": 7
}
```

## Error Responses

All errors follow JSON-RPC 2.0 error format:

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32600,
    "message": "Invalid Request",
    "data": {"details": "Missing required field: message"}
  },
  "id": null
}
```

### Error Codes

| Code | Meaning |
|------|---------|
| -32700 | Parse error |
| -32600 | Invalid Request |
| -32601 | Method not found |
| -32602 | Invalid params |
| -32603 | Internal error |

## WebSocket Streaming

For streaming responses, connect via WebSocket:

```
ws://localhost:8080/ws
```

Messages follow the same JSON-RPC format with streaming chunks:

```json
{
  "jsonrpc": "2.0",
  "method": "chat.stream",
  "params": {
    "message": "Tell me a story",
    "session_key": "session-123"
  },
  "id": 8
}
```

Stream chunks:

```json
{"chunk": "Once upon a time..."}
{"chunk": " there lived a dragon..."}
{"done": true}
```

## Health Check

### `GET /health`

Returns service health status.

**Response:**

```json
{
  "status": "ok",
  "timestamp": 1700000000
}
```
