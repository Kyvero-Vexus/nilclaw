# Commands Specification (Adapted from NullClaw docs)

> Frozen reference — do not modify. Source: NullClaw docs/en/commands.md

## Overview

The system provides a CLI organized by task categories: setup, runtime
operations, channels, scheduling, data management, and hardware.

## Setup and Interaction

| Command Pattern                  | Purpose                                  |
|----------------------------------|------------------------------------------|
| `help`                           | Show top-level help                      |
| `version`                        | Show CLI version                         |
| `onboard --interactive`          | Run interactive setup wizard             |
| `onboard --api-key K --provider P` | Quick provider + API key setup        |
| `onboard --channels-only`        | Reconfigure channels and allowlists only |
| `agent -m "..."`                 | Single-message mode (one prompt)         |
| `agent`                          | Interactive chat mode                    |

## Runtime and Operations

| Command Pattern                  | Purpose                                  |
|----------------------------------|------------------------------------------|
| `gateway`                        | Start long-running runtime               |
| `gateway --port P`               | Override gateway port                    |
| `gateway --host H --port P`      | Override host and port                   |
| `service install/start/stop/restart/status/uninstall` | Manage background service |
| `status`                         | Show overall system status               |
| `doctor`                         | Run diagnostics                          |
| `update --check`                 | Check for updates                        |
| `update --yes`                   | Install updates without prompt           |
| `auth login <provider>`          | Authenticate via OAuth device flow       |
| `auth status <provider>`         | Show authentication state                |
| `auth logout <provider>`         | Remove stored credentials                |

Notes:
- `gateway --host/--port` overrides only bind settings; other gateway security comes from config.
- `auth` supports specific provider OAuth flows.

## Channel Management

| Command Pattern                  | Purpose                                  |
|----------------------------------|------------------------------------------|
| `channel list`                   | List known and configured channels       |
| `channel start [name]`           | Start default or specific channel        |
| `channel status`                 | Show channel health                      |
| `channel add <type>`             | Print guidance for adding a channel      |
| `channel remove <name>`          | Print guidance for removing a channel    |

## Scheduling (Cron)

| Command Pattern                  | Purpose                                  |
|----------------------------------|------------------------------------------|
| `cron list`                      | List scheduled tasks                     |
| `cron add "expr" "command"`      | Add recurring shell task                 |
| `cron add-agent "expr" "prompt" --model M` | Add recurring agent task        |
| `cron once <delay> "command"`    | One-shot delayed shell task              |
| `cron once-agent <delay> "prompt" --model M` | One-shot delayed agent task  |
| `cron run <id>`                  | Run task immediately                     |
| `cron pause/resume <id>`         | Pause or resume task                     |
| `cron remove <id>`               | Delete task                              |
| `cron runs <id>`                 | Show recent run history                  |
| `cron update <id> [options]`     | Update existing task                     |

## Memory Management

| Command Pattern                  | Purpose                                  |
|----------------------------------|------------------------------------------|
| `memory stats`                   | Show memory config and counters          |
| `memory count`                   | Show total memory entries                |
| `memory reindex`                 | Rebuild vector index                     |
| `memory search "query" --limit N`| Run retrieval against memory             |
| `memory get <key>`               | Show one memory entry                    |
| `memory list --category C --limit N` | List entries by category             |
| `memory drain-outbox`            | Drain durable vector outbox queue        |
| `memory forget <key>`            | Delete one memory entry                  |

## Workspace and Models

| Command Pattern                  | Purpose                                  |
|----------------------------------|------------------------------------------|
| `workspace edit <file>`          | Open bootstrap file in $EDITOR           |
| `workspace reset-md [options]`   | Reset bundled markdown files             |
| `capabilities [--json]`          | Show capability summary                  |
| `models list`                    | List providers and default models        |
| `models info <model>`            | Show model details                       |
| `models benchmark`               | Run model latency benchmark              |
| `models refresh`                 | Refresh model catalog                    |
| `migrate openclaw [--dry-run]`   | Migrate from OpenClaw                    |

## Hardware

| Command Pattern                  | Purpose                                  |
|----------------------------------|------------------------------------------|
| `hardware scan`                  | Scan connected hardware                  |
| `hardware flash <fw> [--target]` | Flash firmware to device                 |
| `hardware monitor`               | Monitor hardware devices                 |

## Machine-Facing Flags

| Flag                        | Purpose                    |
|-----------------------------|----------------------------|
| `--export-manifest`         | Export runtime manifest     |
| `--list-models`             | Print model information    |
| `--probe-provider-health`   | Probe provider health      |
| `--probe-channel-health`    | Probe channel health       |
| `--from-json`               | JSON-driven entry path     |

## Troubleshooting Order

1. `doctor`
2. `status`
3. `channel status`
4. `agent -m "self-check"`
5. If gateway involved: health endpoint check
