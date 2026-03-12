# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive GitHub Pages documentation site
- Complete API reference documentation
- Detailed security policy documentation
- Development and contribution guidelines
- GitHub Actions workflow for automated documentation deployment

### Changed
- Project renamed from NilClaw to NilClaw
- Updated all documentation to reference NilClaw consistently
- Removed references to Zig and Homebrew (project uses SBCL/Quicklisp)
- Enhanced README with badges, features list, and better organization

## [0.1.0] - 2024-03-12

### Added
- Initial public release of NilClaw
- Core agent runtime with message processing
- WebSocket gateway protocol implementation
- Channel system with CLI and Web adapters
- Auto-reply system with configurable rules
- Tool execution framework with security sandboxing
- Provider abstraction layer for AI/ML services
- HTTP client with retry/backoff strategies
- Memory management system (SQLite, Markdown, None backends)
- Configuration system with environment variable overrides
- Security policy with autonomy levels and command filtering
- Subagent coordination system (ACP patterns)
- Cron scheduling and heartbeat management
- Comprehensive test suite (838 tests)
- Spec-driven development approach
- Strict type safety with SBCL declarations
- Coalton integration for strongly typed core modules

### Test Coverage
- **L0 Tests**: 28 unit tests
- **L1 Tests**: 30 integration tests
- **L2 Tests**: 24 end-to-end behavioral tests
- **Total**: 838/838 tests passing (100%)

### Features

#### Tool Execution
- File operations (read, write, edit)
- Shell execution with security controls
- Web operations (search, fetch)
- Browser automation
- Process management

#### Provider System
- Anthropic Claude support
- OpenAI GPT support
- Local Ollama support
- Custom HTTP endpoints
- Configurable retry and timeout

#### Channel System
- CLI interactive interface
- Web HTTP/WebSocket interface
- Auto-reply with pattern matching
- Rate limiting and filtering

#### Security
- Three autonomy levels (deny, allowlist, full)
- Command allowlist/blocklist
- Path restrictions
- Sandbox backends (Landlock, Firejail, Bubblewrap, Docker)
- Audit logging
- Resource limits

#### Memory
- SQLite backend with FTS search
- Markdown backend for human-readable logs
- Stateless operation mode
- Automatic archival

#### Subagents
- Hierarchical agent coordination
- Task delegation
- Inter-agent communication
- Resource management
- Fault tolerance

### Documentation
- Comprehensive README
- Installation guide
- Configuration reference
- Architecture overview
- Security policy
- Development guide
- API reference
- GitHub Pages site

### Development Infrastructure
- Makefile for build automation
- GitHub Actions CI/CD
- Traceability validation
- GPG-signed commits
- Conventional commits standard
- Contributing guidelines

## [0.0.1] - 2024-01-15

### Added
- Initial project setup
- Basic project structure
- ASDF system definition
- Core package definitions
- Initial test framework
- Basic configuration system

---

## Version History

- **0.1.0** (2024-03-12): Initial public release with full feature set
- **0.0.1** (2024-01-15): Project initialization

## Future Roadmap

### Planned for 0.2.0
- Enhanced subagent coordination patterns
- Additional tool implementations
- Performance optimizations
- Extended provider support
- Improved error handling

### Planned for 0.3.0
- Web UI improvements
- Additional memory backend options
- Plugin system for custom tools
- Enhanced monitoring and observability

### Long-term Goals
- Production-ready stability
- Comprehensive provider ecosystem
- Advanced subagent coordination
- Performance benchmarking suite
- Community plugin repository

---

For more details on each release, see the [GitHub Releases](https://github.com/Kyvero-Vexus/nilclaw/releases) page.