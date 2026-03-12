# Commands

This page groups the NilClaw CLI by task so you can find the right command quickly without scanning the full help output.

`nilclaw help` gives the top-level summary; this page stays aligned with it and expands into the detailed subcommands and notes.

## Page Guide

**Who this page is for**

- Users who already have NilClaw installed and need the right CLI entry point
- Operators checking runtime, service, channel, or diagnostic commands
- Contributors verifying command names, flags, and task groupings

**Read this next**

- Open [Configuration](./configuration.md) if you need to understand what the commands act on
- Open [Usage and Operations](./usage.md) if you want workflows instead of command listings
- Open [Development](./development.md) if you are changing CLI behavior or docs

**If you came from ...**

- [README](./README.md): this page is the fastest way to find a concrete command
- [Installation](./installation.md): after setup, use this page to validate the install and learn daily commands
- `nilclaw help`: use this page when the built-in help is correct but too terse

## Start with these

- Show help: `nilclaw help`
- Show version: `nilclaw version` or `nilclaw --version`
- First-time setup: `nilclaw onboard --interactive`
- Quick validation: `nilclaw agent -m "hello"`
- Long-running mode: `nilclaw gateway`

## Setup and interaction

| Command | Purpose |
|---|---|
| `nilclaw help` | Show top-level help |
| `nilclaw version` / `nilclaw --version` | Show CLI version |
| `nilclaw onboard --interactive` | Run the interactive setup wizard |
| `nilclaw onboard --api-key sk-... --provider openrouter` | Quick provider + API key setup |
| `nilclaw onboard --api-key ... --provider ... --model ... --memory ...` | Set provider, model, and memory backend in one command |
| `nilclaw onboard --channels-only` | Reconfigure channels and allowlists only |
| `nilclaw agent -m "..."` | Run a single prompt |
| `nilclaw agent` | Start interactive chat mode |

## Runtime and operations

| Command | Purpose |
|---|---|
| `nilclaw gateway` | Start the long-running runtime using configured host and port |
| `nilclaw gateway --port 8080` | Override the gateway port from the CLI |
| `nilclaw gateway --host 0.0.0.0 --port 8080` | Override host and port from the CLI |
| `nilclaw service install` | Install the background service |
| `nilclaw service start` | Start the background service |
| `nilclaw service stop` | Stop the background service |
| `nilclaw service restart` | Restart the background service |
| `nilclaw service status` | Show service status |
| `nilclaw service uninstall` | Remove the background service |
| `nilclaw status` | Show overall system status |
| `nilclaw doctor` | Run diagnostics |
| `nilclaw update --check` | Check for updates without installing |
| `nilclaw update --yes` | Install updates without prompting |
| `nilclaw auth login openai-codex` | Authenticate `openai-codex` via OAuth device flow |
| `nilclaw auth login openai-codex --import-codex` | Import auth from `~/.codex/auth.json` |
| `nilclaw auth status openai-codex` | Show authentication state |
| `nilclaw auth logout openai-codex` | Remove stored credentials |

Notes:

- `auth` currently supports only `openai-codex`.
- `gateway --host/--port` overrides only the bind settings; the rest of gateway security still comes from config.

## Channels, scheduling, and extensions

### `channel`

| Command | Purpose |
|---|---|
| `nilclaw channel list` | List known and configured channels |
| `nilclaw channel start` | Start the default available channel |
| `nilclaw channel start telegram` | Start a specific channel |
| `nilclaw channel status` | Show channel health |
| `nilclaw channel add <type>` | Print guidance for adding a channel to config |
| `nilclaw channel remove <name>` | Print guidance for removing a channel from config |

### `cron`

| Command | Purpose |
|---|---|
| `nilclaw cron list` | List scheduled tasks |
| `nilclaw cron add "0 * * * *" "command"` | Add a recurring shell task |
| `nilclaw cron add-agent "0 * * * *" "prompt" --model <model>` | Add a recurring agent task |
| `nilclaw cron once 10m "command"` | Add a one-shot delayed shell task |
| `nilclaw cron once-agent 10m "prompt" --model <model>` | Add a one-shot delayed agent task |
| `nilclaw cron run <id>` | Run a task immediately |
| `nilclaw cron pause <id>` / `resume <id>` | Pause or resume a task |
| `nilclaw cron remove <id>` | Delete a task |
| `nilclaw cron runs <id>` | Show recent run history |
| `nilclaw cron update <id> --expression ... --command ... --prompt ... --model ... --enable/--disable` | Update an existing task |

### `skills`

| Command | Purpose |
|---|---|
| `nilclaw skills list` | List installed skills |
| `nilclaw skills install <source>` | Install from a GitHub URL or local path |
| `nilclaw skills remove <name>` | Remove a skill |
| `nilclaw skills info <name>` | Show skill metadata |

## Data, models, and workspace

### `memory`

| Command | Purpose |
|---|---|
| `nilclaw memory stats` | Show resolved memory config and counters |
| `nilclaw memory count` | Show total number of memory entries |
| `nilclaw memory reindex` | Rebuild the vector index |
| `nilclaw memory search "query" --limit 10` | Run retrieval against memory |
| `nilclaw memory get <key>` | Show one memory entry |
| `nilclaw memory list --category task --limit 20` | List memory entries by category |
| `nilclaw memory drain-outbox` | Drain the durable vector outbox queue |
| `nilclaw memory forget <key>` | Delete one memory entry |

### `workspace`, `capabilities`, `models`, `migrate`

| Command | Purpose |
|---|---|
| `nilclaw workspace edit AGENTS.md` | Open a bootstrap markdown file in `$EDITOR` |
| `nilclaw workspace reset-md --dry-run` | Preview workspace markdown reset |
| `nilclaw workspace reset-md --include-bootstrap --clear-memory-md` | Reset bundled markdown files and optionally clear extra files |
| `nilclaw capabilities` | Show a text capability summary |
| `nilclaw capabilities --json` | Show a JSON capability manifest |
| `nilclaw models list` | List providers and default models |
| `nilclaw models info <model>` | Show model details |
| `nilclaw models benchmark` | Run model latency benchmark |
| `nilclaw models refresh` | Refresh the model catalog |
| `nilclaw migrate openclaw --dry-run` | Preview OpenClaw migration |
| `nilclaw migrate openclaw --source /path/to/workspace` | Migrate from a specific source workspace |

Notes:

- `workspace edit` works only with file-based backends such as `markdown` and `hybrid`.
- If bootstrap data is stored in the database backend, the CLI will tell you to use the agent's `memory_store` tool instead.

## Hardware and automation-facing entry points

### `hardware`

| Command | Purpose |
|---|---|
| `nilclaw hardware scan` | Scan connected hardware |
| `nilclaw hardware flash <firmware_file> [--target <board>]` | Flash firmware to a device (currently a placeholder command) |
| `nilclaw hardware monitor` | Monitor hardware devices (currently a placeholder command) |

### Top-level machine-facing flags

These are more useful for automation, probing, or integrations than for normal day-to-day CLI use:

| Command | Purpose |
|---|---|
| `nilclaw --export-manifest` | Export the runtime manifest |
| `nilclaw --list-models` | Print model information |
| `nilclaw --probe-provider-health` | Probe provider health |
| `nilclaw --probe-channel-health` | Probe channel health |
| `nilclaw --from-json` | Run a JSON-driven entry path |

## Recommended troubleshooting order

1. `nilclaw doctor`
2. `nilclaw status`
3. `nilclaw channel status`
4. `nilclaw agent -m "self-check"`
5. If gateway is involved, also run `curl http://127.0.0.1:3000/health`

## Next Steps

- Go to [Usage and Operations](./usage.md) for task-based runtime workflows
- Go to [Configuration](./configuration.md) if a command depends on provider, gateway, or memory settings
- Go to [Development](./development.md) if you plan to change command behavior or update docs alongside code

## Related Pages

- [README](./README.md)
- [Installation](./installation.md)
- [Gateway API](./gateway-api.md)
- [Architecture](./architecture.md)
