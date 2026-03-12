# NilClaw Documentation

This directory provides structured English documentation for NilClaw, covering installation, configuration, operations, and development.

If you are new here, use the guided paths below instead of guessing which page to open first.

## Page Guide

**Who this page is for**

- New users choosing their first documentation path
- Operators deciding which operational guide to open next
- Contributors looking for the right entry point before deeper docs

**Read this next**

- Start with [Installation](./installation.md) if NilClaw is not running yet
- Go to [Configuration](./configuration.md) if you already installed it
- Jump to [Commands](./commands.md) if you want a task-based CLI reference

**If you came from ...**

- `README.md`: use this page as the English landing page, then branch into the guide you need
- [Commands](./commands.md): come back here if you want a broader map of the docs set
- [Development](./development.md): return here if you need user or operator docs outside contributor workflows

## Start Paths

### 1. I just want to get it running

Recommended order:

1. [Installation](./installation.md)
2. [Configuration](./configuration.md)
3. [Usage and Operations](./usage.md)
4. [Commands](./commands.md)

### 2. I need deployment or operations guidance

Focus on:

- [Usage and Operations](./usage.md)
- [Security](./security.md)
- [Gateway API](./gateway-api.md)
- [Signal Deployment](../../SIGNAL.md)

### 3. I want to contribute code or docs

Focus on:

- [Architecture](./architecture.md)
- [Development](./development.md)
- [Commands](./commands.md)
- [Contributing](../../CONTRIBUTING.md)

## Navigation

- [Installation](./installation.md)
- [Configuration](./configuration.md)
- [Usage and Operations](./usage.md)
- [Architecture](./architecture.md)
- [Security](./security.md)
- [Gateway API](./gateway-api.md)
- [Commands](./commands.md)
- [Development](./development.md)

## Start Here

1. NilClaw requires **SBCL** (Steel Bank Common Lisp) and **Quicklisp**.
2. Default config path is `~/.nilclaw/config.json`.
3. For first run, load the system and initialize configuration.

## Fastest First Run

```bash
# Install dependencies (Linux/macOS)
sbcl --eval '(ql:quickload :nilclaw)' --eval '(nilclaw/config:initialize-default-config)' --quit

# Run tests
make test
```

For detailed installation instructions, see [Installation](./installation.md).

## Specialized Guides

- [Contributing](../../CONTRIBUTING.md)
- [Security Policy](../../SECURITY.md)
- [Signal Deployment](../../SIGNAL.md)

## Next Steps

- Follow [Installation](./installation.md) for setup from Homebrew or source
- Continue to [Configuration](./configuration.md) to wire providers, memory, and channels
- Use [Usage and Operations](./usage.md) once you want to run NullClaw day to day

## Related Pages

- [Commands](./commands.md)
- [Development](./development.md)
- [Architecture](./architecture.md)
- [Gateway API](./gateway-api.md)
