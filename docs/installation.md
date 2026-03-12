# Installation

This guide covers the main installation paths for Linux, macOS, and Windows.

## Page Guide

**Who this page is for**

- First-time users installing NilClaw on a local machine
- Operators setting up development or production environments
- Contributors validating the baseline runtime before deeper setup

**Read this next**

- Open [Configuration](./configuration.md) after the system is loaded
- Open [Usage and Operations](./usage.md) when you are ready to run first commands
- Open [README](./README.md) if you want the broader docs map before going deeper

## Prerequisites

- **SBCL** (Steel Bank Common Lisp) 2.2.0 or newer
- **Quicklisp** package manager
- Git (required for source install)
- Make (for build automation)

Check SBCL version:

```bash
sbcl --version
```

## Option 1: Install from Source (recommended)

```bash
# Clone the repository
git clone https://github.com/Kyvero-Vexus/nilclaw.git
cd nilclaw

# Install dependencies via Quicklisp
sbcl --eval '(ql:quickload (list :alexandria :cl-json :cl-ppcre :fiveam))' --quit

# Load the system
make load

# Run tests
make test

# Verify traceability
make traceability
```

## Option 2: Quicklisp Installation (when available)

```lisp
;; In SBCL REPL
(ql:quickload :nilclaw)
```

## Install SBCL and Quicklisp

### Linux (Debian/Ubuntu)

```bash
sudo apt-get update
sudo apt-get install sbcl curl

# Install Quicklisp
curl -O https://beta.quicklisp.org/quicklisp.lisp
sbcl --load quicklisp.lisp
```

Then in SBCL:
```lisp
(quicklisp-quickstart:install)
(ql:add-to-init-file)
```

### Linux (RedHat/CentOS/Fedora)

```bash
sudo dnf install sbcl curl  # Fedora
# or
sudo yum install sbcl curl  # CentOS/RHEL

# Install Quicklisp (same as above)
curl -O https://beta.quicklisp.org/quicklisp.lisp
sbcl --load quicklisp.lisp
```

### macOS

```bash
brew install sbcl curl

# Install Quicklisp (same as above)
curl -O https://beta.quicklisp.org/quicklisp.lisp
sbcl --load quicklisp.lisp
```

### Windows

1. Download SBCL from http://www.sbcl.org/platform-table.html
2. Install and add to PATH
3. Install Quicklisp using PowerShell:

```powershell
# Download Quicklisp
Invoke-WebRequest -Uri https://beta.quicklisp.org/quicklisp.lisp -OutFile quicklisp.lisp

# Load in SBCL
sbcl --load quicklisp.lisp
```

Then in SBCL:
```lisp
(quicklisp-quickstart:install)
(ql:add-to-init-file)
```

## Verify Installation

```bash
# Check that NilClaw loads successfully
sbcl --eval '(ql:quickload :nilclaw)' --quit

# Run the full test suite (should show 838/838 passing)
make test

# Verify traceability metrics
make traceability
```

Expected output:
```
L0=28 L1=30 L2=24
Did 838 checks.
    Pass: 838 (100%)
    Skip: 0 ( 0%)
    Fail: 0 ( 0%)
```

## Configuration Setup

Initialize default configuration:

```lisp
;; In SBCL REPL
(ql:quickload :nilclaw)
(nilclaw/config:initialize-default-config)
```

This creates `~/.nilclaw/config.json` with default settings.

## Next Steps

- Configure your setup with [Configuration](./configuration.md)
- Learn basic operations with [Usage and Operations](./usage.md)
- Reference CLI commands with [Commands](./commands.md)

## Related Pages

- [README](./README.md)
- [Configuration](./configuration.md)
- [Usage and Operations](./usage.md)
- [Commands](./commands.md)