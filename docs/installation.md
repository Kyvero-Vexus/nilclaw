# Installation

This guide covers the main installation paths for macOS, Linux, and Windows.

## Page Guide

**Who this page is for**

- First-time users installing NullClaw on a local machine
- Operators choosing between package install and source build
- Contributors validating the baseline runtime before deeper setup

**Read this next**

- Open [Configuration](./configuration.md) after the binary is installed and on your `PATH`
- Open [Usage and Operations](./usage.md) when you are ready to run first commands and service mode
- Open [README](./README.md) if you want the broader English docs map before going deeper

**If you came from ...**

- [README](./README.md): this page is the concrete first-run path after choosing the installation track
- [Commands](./commands.md): come here first if the CLI is missing or `nullclaw --help` does not work yet
- [Development](./development.md): return here if a contributor workflow also needs a clean local binary setup

## Prerequisites

- If building from source, use **Zig 0.15.2**.
- Git (required for source install).

Check Zig version:

```bash
zig version
```

The output must be `0.15.2`.

## Option 1: Homebrew (recommended for macOS/Linux)

```bash
brew install nullclaw
nullclaw --help
```

If the command works, installation is complete.

## Option 2: Build from Source (cross-platform)

```bash
git clone https://github.com/nullclaw/nullclaw.git
cd nullclaw
zig build -Doptimize=ReleaseSmall
zig build test --summary all
```

Build output:

- `zig-out/bin/nullclaw`

## Add Binary to PATH

### macOS/Linux (zsh/bash)

```bash
zig build -Doptimize=ReleaseSmall -p "$HOME/.local"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
# bash users: use ~/.bashrc
source ~/.zshrc
```

### Windows (PowerShell)

```powershell
zig build -Doptimize=ReleaseSmall -p "$HOME\.local"

$bin = "$HOME\.local\bin"
$user_path = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not ($user_path -split ";" | Where-Object { $_ -eq $bin })) {
  [Environment]::SetEnvironmentVariable("Path", "$user_path;$bin", "User")
}
$env:Path = "$env:Path;$bin"
```

## Verify Installation

```bash
nullclaw --help
nullclaw --version
nullclaw status
```

If `status` returns component state successfully, runtime basics are ready.

## Upgrade and Uninstall

### Homebrew

```bash
brew update
brew upgrade nullclaw
brew uninstall nullclaw
```

### Source install

- Upgrade: `git pull`, then rebuild with `zig build -Doptimize=ReleaseSmall`.
- Uninstall: delete the installed `nullclaw` binary and remove the PATH entry.

## Next Steps

- Run `nullclaw onboard --interactive`, then continue with [Configuration](./configuration.md)
- Use [Usage and Operations](./usage.md) for first-run commands, service mode, and troubleshooting
- Keep [Commands](./commands.md) nearby if you want a task-based CLI reference after install

## Related Pages

- [README](./README.md)
- [Configuration](./configuration.md)
- [Usage and Operations](./usage.md)
- [Commands](./commands.md)
