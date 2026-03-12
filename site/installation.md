---
layout: default
title: Installation
nav_order: 2
parent: nilclaw
---

# Installation

## Prerequisites

- **SBCL** 2.5.2+ (Steel Bank Common Lisp)
- **Quicklisp** (Common Lisp package manager)

## Quick Install

```bash
# Clone
git clone https://github.com/Kyvero-Vexus/nilclaw.git
cd nilclaw

# Run tests
make test

# Run directly (development)
./bin/nilclaw check
```

## Running the Daemon

### Development Mode

```bash
# Run in foreground with default config
./bin/nilclaw start

# Run with explicit config
./bin/nilclaw start ~/.nilclaw/init.lisp

# Check config validity
./bin/nilclaw check

# Show help
./bin/nilclaw help
```

### System Service (Linux)

Install as a system service:

```bash
# 1. Install launcher to PATH
sudo cp bin/nilclaw /usr/local/bin/
sudo chmod +x /usr/local/bin/nilclaw

# 2. Set environment (adjust paths)
export NILCLAW_ROOT=/opt/nilclaw

# 3. Install systemd unit
sudo cp contrib/nilclaw.service /etc/systemd/system/
sudo systemctl daemon-reload

# 4. Enable and start
sudo systemctl enable nilclaw
sudo systemctl start nilclaw

# 5. Check status
sudo systemctl status nilclaw
```

### User Service (Linux)

Run as a user service without sudo:

```bash
# 1. Install launcher locally
mkdir -p ~/.local/bin
cp bin/nilclaw ~/.local/bin/

# 2. Create user systemd directory
mkdir -p ~/.config/systemd/user

# 3. Copy service file (edit paths first)
cp contrib/nilclaw.service ~/.config/systemd/user/

# 4. Edit to use local path
# Change: ExecStart=%h/.local/bin/nilclaw start
# Change: Environment=NILCLAW_ROOT=%h/projects/nilclaw

# 5. Enable and start
systemctl --user daemon-reload
systemctl --user enable nilclaw
systemctl --user start nilclaw
```

## Configuration

Create `~/.nilclaw/init.lisp`:

```lisp
(configure
  :default-model "anthropic/claude-sonnet-4-20250514"
  :default-provider "openrouter"
  :gateway (:port 3000 :host "127.0.0.1")
  :memory (:backend "hybrid" :auto-save t)
  :channels ((:type :cli :enabled t)))
```

See [Configuration](configuration.html) for full reference.

## Migrating from OpenClaw

Convert your existing OpenClaw config:

```bash
sbcl --script scripts/migrate-openclaw-config.lisp \
    ~/.openclaw/config.json \
    ~/.nilclaw/init.lisp
```

The output is pure Common Lisp — edit it directly.

## Building a Standalone Binary

For production, build a standalone SBCL image:

```bash
sbcl --eval '(asdf:load-system "nilclaw")' \
     --eval '(sb-ext:save-lisp-and-die "nilclaw-bin" :executable t :toplevel (function nilclaw/gateway:main))'
```

Then run directly:

```bash
./nilclaw-bin start
```

## Verifying Installation

```bash
# Check version
./bin/nilclaw version

# Validate config
./bin/nilclaw check

# Quick test
./bin/nilclaw start &
# Should see: [nilclaw] Starting NilClaw daemon...
# Should see: [nilclaw] NilClaw is ready.
```

## Troubleshooting

### SBCL not found

Install SBCL:
```bash
# Debian/Ubuntu
sudo apt-get install sbcl

# macOS
brew install sbcl
```

### Quicklisp not loaded

```bash
sbcl --load ~/quicklisp/setup.lisp \
     --eval '(ql:add-to-init-file)'
```

### Permission denied on ~/.nilclaw

```bash
mkdir -p ~/.nilclaw
chmod 755 ~/.nilclaw
```

### Port already in use

Edit your config:
```lisp
:gateway (:port 3001 ...)
```
