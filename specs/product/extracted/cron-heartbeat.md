---
Layer: L1
Lane: operations
Spec ID: L1-EXT-cron-heartbeat
Status: draft
Last Updated: 2026-03-10
Traceability:
  L0: [F-AGENT-SCHEDULING, C-REL-TIMEOUT-RETRY]
---

# Cron & Heartbeat Specification

## Overview

The cron system provides scheduled task execution (shell commands or agent
prompts) with cron expressions, one-shot delays, and interval-based
scheduling. The heartbeat system provides periodic polling driven by a
`HEARTBEAT.md` file in the workspace.

## Cron Jobs

### CronJob Structure

| Field             | Type           | Default      | Description                    |
|-------------------|----------------|--------------|--------------------------------|
| `id`              | string         | —            | Unique job identifier          |
| `expression`      | string         | —            | Cron expression or delay       |
| `command`         | string         | —            | Shell command (for shell jobs)  |
| `prompt`          | string?        | null         | Agent prompt (for agent jobs)  |
| `name`            | string?        | null         | Human-readable label           |
| `model`           | string?        | null         | Model override (agent jobs)    |
| `job_type`        | enum           | `shell`      | `shell` or `agent`             |
| `session_target`  | enum           | `isolated`   | `isolated` or `main`           |
| `paused`          | bool           | `false`      | Whether job is paused          |
| `one_shot`        | bool           | `false`      | Run once then delete           |
| `enabled`         | bool           | `true`       | Whether job is active          |
| `delete_after_run`| bool           | `false`      | Delete after successful run    |
| `next_run_secs`   | i64            | 0            | Next scheduled run (unix)      |
| `last_run_secs`   | i64?           | null         | Last run timestamp             |
| `last_status`     | string?        | null         | Last run status                |
| `last_output`     | string?        | null         | Last run output                |
| `created_at_s`    | i64            | 0            | Creation timestamp             |
| `delivery`        | DeliveryConfig | default      | Result delivery config         |

### Job Types

| Type    | Execution                                    |
|---------|----------------------------------------------|
| `shell` | Run shell command, capture output            |
| `agent` | Send prompt to agent, get response           |

### Session Target

| Target     | Behavior                                      |
|------------|-----------------------------------------------|
| `isolated` | Run in dedicated session (default)            |
| `main`     | Run in the main conversation session          |

### Schedule Types

| Kind    | Description                        | Example            |
|---------|------------------------------------|--------------------|
| `cron`  | Standard cron expression + TZ      | `"0 9 * * *"`      |
| `at`    | One-shot at specific timestamp     | Unix timestamp     |
| `every` | Recurring interval (milliseconds)  | `every_ms: 3600000`|

### Duration Parsing

Human-readable delay strings for one-shot tasks:

| Suffix | Unit    | Example  | Seconds |
|--------|---------|----------|---------|
| `s`    | seconds | `30s`    | 30      |
| `m`    | minutes | `5m`     | 300     |
| `h`    | hours   | `2h`     | 7200    |
| `d`    | days    | `1d`     | 86400   |
| `w`    | weeks   | `1w`     | 604800  |
| (none) | seconds | `60`     | 60      |

### Delivery Configuration

Controls how results are delivered after execution:

| Field        | Type         | Default       | Description                |
|--------------|--------------|---------------|----------------------------|
| `mode`       | DeliveryMode | `none`        | Delivery trigger           |
| `channel`    | string?      | null          | Delivery channel           |
| `to`         | string?      | null          | Delivery target            |
| `best_effort`| bool         | `true`        | Don't fail on delivery error|

Delivery modes: `none`, `always`, `on_error`, `on_success`

### Run History

| Field           | Type   | Description               |
|-----------------|--------|---------------------------|
| `id`            | u64    | Run identifier            |
| `job_id`        | string | Parent job ID             |
| `started_at_s`  | i64    | Start timestamp           |
| `finished_at_s` | i64    | End timestamp             |
| `status`        | string | Run status                |
| `output`        | string?| Run output                |
| `duration_ms`   | i64?   | Duration in milliseconds  |

### Job Update (Patch)

Fields that can be updated on an existing job:

| Field             | Type    | Description                |
|-------------------|---------|----------------------------|
| `expression`      | string? | New schedule expression    |
| `command`         | string? | New shell command          |
| `prompt`          | string? | New agent prompt           |
| `name`            | string? | New label                  |
| `enabled`         | bool?   | Enable/disable             |
| `model`           | string? | New model override         |
| `delete_after_run`| bool?   | Change auto-delete flag    |

### Cron Tools

| Tool          | Description                    |
|---------------|--------------------------------|
| `cron_add`    | Create recurring/one-shot task |
| `cron_list`   | List scheduled tasks           |
| `cron_remove` | Delete a task                  |
| `cron_run`    | Run task immediately           |
| `cron_runs`   | Show run history               |
| `cron_update` | Update task properties         |

## Heartbeat System

### HeartbeatEngine

| Field              | Type     | Default | Description                    |
|--------------------|----------|---------|--------------------------------|
| `enabled`          | bool     | —       | Whether heartbeat is enabled   |
| `interval_minutes` | u32      | —       | Poll interval (min 5 minutes)  |
| `workspace_dir`    | string   | —       | Workspace directory            |
| `observer`         | Observer?| null    | Observability backend          |
| `bootstrap_provider`| BootstrapProvider?| null | File/memory provider    |

### HEARTBEAT.md Format

Tasks are lines starting with `- ` (dash + space):
```markdown
# Periodic Tasks

- Check email for important messages
- Review calendar for upcoming events
- Check the weather forecast
```

### Task Parsing Rules

- Lines starting with `- ` (after whitespace trimming) are tasks
- Leading whitespace on the line is ignored
- The `- ` prefix is stripped, remaining text is the task
- Empty task text (just `- `) is skipped
- Headers (`#`), empty lines, and non-bullet text are ignored

### Effectively Empty Detection

A HEARTBEAT.md is considered empty (skip heartbeat) when it contains only:
- Empty lines
- Markdown headers (`#`, `##`, etc.)
- Empty markdown bullets (`-`, `*`, `+` without text)
- Empty checkbox bullets (`- [ ]`, `- [x]`, `- [X]`)

### Tick Outcomes

| Outcome              | Condition                        |
|----------------------|----------------------------------|
| `processed`          | File found, has tasks            |
| `skipped_empty_file` | File found but effectively empty |
| `skipped_missing_file`| File does not exist             |

### File Reading

- Max file size: 64 KB
- Reads via bootstrap provider first (if available)
- Falls back to direct file read from workspace

### Default File Creation

`ensureHeartbeatFile()` creates a default `HEARTBEAT.md` with example
tasks if the file doesn't exist.

### Minimum Interval

The heartbeat interval is clamped to a minimum of 5 minutes.

## Scheduler Configuration

| Field               | Type | Default | Description                |
|---------------------|------|---------|----------------------------|
| `enabled`           | bool | `true`  | Enable scheduler           |
| `max_tasks`         | u32  | `64`    | Max scheduled tasks        |
| `max_concurrent`    | u32  | `4`     | Max concurrent executions  |
| `agent_timeout_secs`| u64  | `0`     | Agent task timeout (0=none)|
| `poll_secs`         | u64  | `15`    | Scheduler polling interval |
| `retries`           | u32  | `2`     | Retry count on failure     |

## Integration Points

- **Cron tools**: registered as standard tools in the agent
- **Event bus**: results can be routed to channels via delivery config
- **Agent core**: agent-type jobs create isolated agent sessions
- **Config**: `scheduler.*`, `cron.*`, `heartbeat.*` configure behavior
- **Session management**: `main` session target runs in existing session
