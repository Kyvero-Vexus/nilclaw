---
Layer: L1
Lane: architecture
Spec ID: L1-EXT-subagent-system
Status: draft
Last Updated: 2026-03-10
Traceability:
  L0: [F-AGENT-SUBAGENTS, F-AGENT-SESSIONS, C-SAFE-PRIORITY]
---

# Sub-Agent System Specification

## Overview

The sub-agent system enables background task execution via isolated agent
instances running in separate OS threads. Sub-agents have restricted tool
sets to prevent infinite loops and cross-channel side effects. Results are
routed back to the originating session via an event bus.

## SubagentManager

### Structure

| Field                  | Type            | Description                        |
|------------------------|-----------------|------------------------------------|
| `tasks`                | HashMap(u64, TaskState) | Active/completed task states |
| `next_id`              | u64             | Monotonic task ID counter          |
| `mutex`                | Mutex           | Guards task map                    |
| `config`               | SubagentConfig  | Concurrency/iteration limits       |
| `bus`                  | Bus?            | Event bus for result routing       |
| `task_runner`          | TaskRunnerFn?   | Optional tool-loop callback        |

Plus inherited config fields: provider, model, workspace, autonomy settings.

### SubagentConfig

| Field            | Type | Default | Description                    |
|------------------|------|---------|--------------------------------|
| `max_iterations` | u32  | `15`    | Max tool iterations per task   |
| `max_concurrent` | u32  | `4`     | Max concurrent subagents       |

## Task Lifecycle

### States

| Status      | Description                    |
|-------------|--------------------------------|
| `running`   | Thread is executing            |
| `completed` | Task finished successfully     |
| `failed`    | Task finished with error       |

### TaskState

| Field          | Type      | Description                  |
|----------------|-----------|------------------------------|
| `status`       | TaskStatus| Current state                |
| `label`        | string    | Human-readable task label    |
| `session_key`  | string?   | Originating session key      |
| `result`       | string?   | Task output (on completion)  |
| `error_msg`    | string?   | Error message (on failure)   |
| `started_at`   | i64       | Start timestamp (ms)         |
| `completed_at` | i64?      | Completion timestamp (ms)    |
| `thread`       | Thread?   | OS thread handle             |

## Spawn Flow

1. **Validate agent** (if named agent specified): check agents list
2. **Check concurrency**: reject if running count >= `max_concurrent`
3. **Allocate task state**: create TaskState with `running` status
4. **Copy inputs**: duplicate task text, label, origin info
5. **Spawn thread**: create OS thread with `subagentThreadFn`
6. **Return task_id**: immediately (non-blocking)

### Named Agent Resolution

When `agent_name` is provided:
- Look up in configured `agents` list
- Override provider, model, API key, system prompt, temperature
- Error `UnknownAgent` if not found

### Default System Prompt

**With task runner** (tool-loop mode):
> "You are a background subagent. Complete the assigned task concisely and
> accurately. Use available tools when they materially improve correctness."

**Without task runner** (legacy fallback):
> "You are a background subagent. Complete the assigned task concisely and
> accurately. You have no access to interactive tools — focus on reasoning
> and analysis."

## Execution Modes

### Tool-Loop Mode (preferred)

When `task_runner` callback is set:
1. Build `TaskRunRequest` with all config parameters
2. Call `task_runner(allocator, request)` → result string
3. On success: complete task with result
4. On error: fail task with error name

### Legacy Fallback Mode

When no `task_runner`:
1. Call `providers.completeWithSystem()` for single-shot LLM response
2. No tool access — pure reasoning only

## TaskRunRequest

Full configuration snapshot passed to the task runner:

| Field                             | Type            | Description                |
|-----------------------------------|-----------------|----------------------------|
| `task`                            | string          | Task prompt                |
| `system_prompt`                   | string          | System prompt              |
| `api_key`                         | string?         | Provider API key           |
| `default_provider`                | string          | Provider name              |
| `default_model`                   | string?         | Model name                 |
| `temperature`                     | f64             | Temperature                |
| `workspace_dir`                   | string          | Workspace directory        |
| `allowed_paths`                   | string[]        | Additional allowed paths   |
| `http_enabled`                    | bool            | HTTP tools enabled         |
| `http_allowed_domains`            | string[]        | Domain allowlist           |
| `http_max_response_size`          | u32             | Max response size          |
| `tools_config`                    | ToolsConfig     | Tool limits                |
| `memory_config`                   | MemoryConfig    | Memory settings            |
| `max_tool_iterations`             | u32             | From SubagentConfig        |
| `autonomy`                        | AutonomyLevel   | Security level             |
| Various security fields...        | ...             | Inherited from manager     |

## Result Routing

When a task completes (success or failure):

1. Duplicate result/error strings into manager's allocator
2. Lock mutex, update TaskState
3. If event bus available:
   - Format result message: `[Subagent '<label>' completed]\n<result>`
   - Create system `InboundMessage` with source `"system:subagent"`
   - Publish to bus for delivery to originating session

## Tool Restrictions

Sub-agents receive a restricted tool set (see Tool System spec):

**Included**: `shell`, `file_read`, `file_write`, `file_edit`, `git`,
optional `http_request`

**Excluded**: `message`, `spawn`, `delegate`, `schedule`, `memory_*`,
`composio`, `browser`, `screenshot`, `pushover`, `web_search`, `web_fetch`

This prevents:
- Infinite spawn loops (spawn → spawn → ...)
- Cross-channel message side effects
- Memory corruption from concurrent access

## Thread Safety

- `SubagentManager.mutex` guards the tasks map
- Task completion happens from the spawned thread (locks mutex)
- Bus publication happens outside the lock
- Each thread has independent arena allocation

## Operations

| Operation       | Description                      | Thread-safe |
|-----------------|----------------------------------|-------------|
| `spawn`         | Create new background subagent   | Yes         |
| `spawnWithAgent`| Spawn with named agent profile   | Yes         |
| `getTaskStatus` | Query task state                 | Yes         |
| `getTaskResult` | Get completed task result        | Yes         |
| `getRunningCount`| Count running tasks             | Yes         |
| `deinit`        | Join all threads, free resources | Terminal    |

## Integration Points

- **Spawn tool**: `spawn` tool in agent calls `manager.spawn()`
- **Event bus**: results routed as `InboundMessage` for session delivery
- **Agent routing**: named agents resolved from config
- **Provider system**: creates provider for LLM calls in thread
