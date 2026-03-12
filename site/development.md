---
title: Development
nav_order: 10
description: "Contributing to NilClaw: development setup, testing, and best practices"
---

# Development
{: .no_toc }

This guide helps contributors set up a development environment, make focused changes, validate them, and submit quality pull requests.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Development Setup

### Prerequisites

- **SBCL** (Steel Bank Common Lisp) 2.2.0 or newer
- **Quicklisp** package manager
- **Git** for version control
- **Make** for build automation
- **Python 3** for traceability validation scripts
- **Emacs** + **SLIME** (recommended for interactive development)

### Environment Setup

```bash
# Clone the repository
git clone https://github.com/Kyvero-Vexus/nilclaw.git
cd nilclaw

# Install dependencies via Quicklisp
sbcl --eval '(ql:quickload (list :alexandria :cl-json :cl-ppcre :fiveam))' --quit

# Load the system
make load

# Run tests to verify setup
make test

# Check traceability 
make traceability
```

### Development Dependencies

Additional packages for development:

```lisp
;; In SBCL REPL
(ql:quickload '(:swank         ; For SLIME integration
                :cl-who        ; HTML generation
                :trivial-shell ; Shell utilities
                :local-time    ; Time handling
                :uuid          ; UUID generation
                :quri))        ; URI handling
```

---

## Project Structure

Understanding the codebase layout:

```
nilclaw/
├── src/                    # Main source code
│   ├── agent/             # Core agent runtime
│   ├── channels/          # Communication channels  
│   ├── config/            # Configuration system
│   ├── gateway/           # WebSocket gateway
│   ├── memory/            # Memory backends
│   ├── providers/         # AI model providers
│   ├── security/          # Security and sandboxing
│   ├── subagents/         # Subagent coordination
│   └── tools/             # Tool execution framework
├── tests/                 # Test suite
│   ├── unit/              # Unit tests
│   ├── integration/       # Integration tests
│   └── e2e/               # End-to-end tests
├── specs/                 # Behavioral specifications
├── docs/                  # Reference documentation
├── site/                  # GitHub Pages site
└── scripts/               # Build and utility scripts
```

### Key Files

| File | Purpose |
|------|---------|
| `nilclaw.asd` | ASDF system definition |
| `src/package.lisp` | Package definitions |
| `src/nilclaw.lisp` | Main entry points |
| `tests/package.lisp` | Test package definitions |
| `Makefile` | Build and test automation |

---

## Type-Safe Development

NilClaw enforces **strict type declarations** throughout the codebase. Every function must include complete type information.

### Function Type Declarations

```lisp
;; Correct: Complete type declaration
(declaim (ftype (function (string fixnum) (values string &optional))
                process-message))
(defun process-message (content timeout)
  (declare (type string content)
           (type fixnum timeout))
  ;; Implementation
  )

;; Also acceptable: Using specific types
(declaim (ftype (function (pathname) (values list &optional))
                read-config-file))
(defun read-config-file (path)
  (declare (type pathname path))
  ;; Implementation
  )
```

### Data Structure Definitions

```lisp
;; Use defstruct with type declarations
(defstruct (message (:type list))
  (id string :type string)
  (content string :type string)
  (timestamp rational :type rational)
  (session-id string :type string))

;; Or CLOS classes with slot types
(defclass agent ()
  ((id :initarg :id :type string :reader agent-id)
   (model :initarg :model :type string :reader agent-model)
   (config :initarg :config :type list :reader agent-config)))
```

### Type Validation

Enable strict type checking during development:

```lisp
;; In your development init file
(declaim (optimize (safety 3) (debug 3) (speed 1)))

;; Enable additional type warnings
#+sbcl
(setf sb-ext:*derive-function-types* t)
```

---

## Development Workflow

### Interactive Development (Recommended)

Using Emacs + SLIME for interactive development:

```lisp
;; Start SLIME in Emacs
M-x slime

;; In the SLIME REPL
(ql:quickload :nilclaw)

;; Load your development changes
(asdf:load-system :nilclaw :force t)

;; Run specific tests
(fiveam:run! 'nilclaw/tests::config-suite)

;; Interactive debugging
(trace nilclaw/config:load-config)
(untrace)
```

### Command-Line Development

```bash
# Load system and run all tests
make test

# Load system without tests  
make load

# Run specific test suite
sbcl --eval '(ql:quickload :nilclaw/tests)' \
     --eval '(fiveam:run! (quote nilclaw/tests::config-suite))' \
     --quit

# Check code formatting (when available)
# Note: Common Lisp doesn't have standardized formatting like Go/Rust
```

---

## Testing Framework

NilClaw uses **FiveAM** for its test suite with comprehensive coverage requirements.

### Test Structure

```lisp
(in-package :nilclaw/tests)

(def-suite config-suite
  :description "Tests for configuration system")

(in-suite config-suite)

(test config-loading-basic
  "Test basic configuration loading"
  (let ((config (load-test-config "basic.json")))
    (is (stringp (config-agent-model config)))
    (is (= 0.7 (config-agent-temperature config)))))

(test config-validation-errors
  "Test configuration validation catches errors"
  (signals validation-error
    (validate-config '(:invalid "structure"))))
```

### Running Tests

```bash
# Run all tests
make test

# Run specific suite
sbcl --eval '(ql:quickload :nilclaw/tests)' \
     --eval '(fiveam:run! :config-suite)' \
     --quit

# Run with verbose output
sbcl --eval '(ql:quickload :nilclaw/tests)' \
     --eval '(setf fiveam:*test-dribble* t)' \
     --eval '(fiveam:run! :all)' \
     --quit
```

### Test Coverage Levels

NilClaw maintains three test coverage levels:

- **L0**: Unit tests for individual functions (target: 28)
- **L1**: Integration tests for subsystem interaction (target: 30)  
- **L2**: End-to-end behavioral tests (target: 24)

Current status: **838/838 tests passing** with **L0=28 L1=30 L2=24**.

### Writing New Tests

```lisp
(test your-new-test
  "Clear description of what this test validates"
  ;; Setup
  (let ((test-data (make-test-data)))
    
    ;; Exercise
    (let ((result (your-function test-data)))
      
      ;; Verify
      (is (not (null result)))
      (is (typep result 'expected-type))
      (is (= expected-value (result-field result))))))

;; Integration test example
(test integration-config-and-agent
  "Test configuration integration with agent initialization"
  (with-temporary-config
    (let ((config (make-test-config :agent-model "test/model")))
      (let ((agent (initialize-agent-from-config config)))
        (is (stringp (agent-id agent)))
        (is (string= "test/model" (agent-model agent)))))))
```

---

## Code Quality Standards

### SBCL Compiler Warnings

All code must compile without warnings:

```bash
# Check for compiler warnings
sbcl --eval '(ql:quickload :nilclaw)' \
     --eval '(compile-file "src/your-module.lisp")' \
     --quit
```

### Documentation Standards

Every public function requires documentation:

```lisp
(defun public-function (param1 param2)
  "Brief description of what this function does.
  
PARAM1 (string): Description of first parameter
PARAM2 (integer): Description of second parameter

Returns: Description of return value

Example:
  (public-function \"hello\" 42)
  ; => \"result\""
  (declare (type string param1)
           (type integer param2))
  ;; Implementation
  )
```

### Error Handling

Use structured error handling with specific condition types:

```lisp
(define-condition nilclaw-error (error)
  ((message :initarg :message :reader error-message))
  (:documentation "Base class for NilClaw-specific errors"))

(define-condition configuration-error (nilclaw-error)
  ((config-key :initarg :config-key :reader error-config-key))
  (:documentation "Error in configuration"))

(defun validate-config-key (config key)
  (unless (member key (config-keys config))
    (error 'configuration-error
           :message (format nil "Unknown configuration key: ~A" key)
           :config-key key)))
```

---

## Git Workflow

### Commit Standards

All commits must be **GPG-signed** and include co-authorship:

```bash
# Configure GPG signing
git config --global commit.gpgsign true
git config --global user.signingkey YOUR_KEY_ID

# Commit with required co-authorship
git commit -S -m "docs: update configuration reference

Co-authored-by: htayj <htayj@users.noreply.github.com>"
```

### Conventional Commits

Use conventional commit format:

```
type(scope): description

Longer description if needed

Co-authored-by: htayj <htayj@users.noreply.github.com>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix  
- `docs`: Documentation changes
- `test`: Test changes
- `refactor`: Code refactoring
- `style`: Code style changes
- `perf`: Performance improvements

### Branch Naming

- `feature/description` - New features
- `fix/issue-description` - Bug fixes
- `docs/section-update` - Documentation updates
- `refactor/module-cleanup` - Refactoring work

---

## Debugging

### Interactive Debugging

SBCL provides excellent debugging capabilities:

```lisp
;; Enable debugger
(setf *debugger-hook* nil)

;; Add breakpoints
(trace function-name)

;; Step through execution
(step (your-function args))

;; Inspect variables
(describe variable)
(inspect complex-object)

;; Call stack inspection
(sb-debug:backtrace)
```

### Logging

Use structured logging for development:

```lisp
(defparameter *debug-level* :info)

(defun log-debug (format-string &rest args)
  (when (member *debug-level* '(:debug :info :warn :error))
    (format *error-output* 
            "[~A] ~A~%" 
            (local-time:now)
            (apply #'format nil format-string args))))

(defun log-info (format-string &rest args)
  (when (member *debug-level* '(:info :warn :error))
    (apply #'log-debug format-string args)))
```

### Performance Profiling

```lisp
;; Time execution
(time (your-function args))

;; Profile with sb-profile
#+sbcl
(progn
  (sb-profile:profile your-function)
  ;; Run your code
  (sb-profile:report)
  (sb-profile:reset))

;; Memory usage
#+sbcl
(sb-vm:memory-usage)
```

---

## Continuous Integration

### GitHub Actions

The CI pipeline runs on every push and PR:

```yaml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install SBCL
        run: sudo apt-get install -y sbcl
      - name: Install Quicklisp
        run: |
          curl -O https://beta.quicklisp.org/quicklisp.lisp
          sbcl --load quicklisp.lisp --eval '(quicklisp-quickstart:install)'
      - name: Run tests
        run: make test
      - name: Validate traceability
        run: make traceability
```

### Pre-commit Hooks

Set up pre-commit hooks for quality gates:

```bash
# Install hooks
cp scripts/pre-commit .git/hooks/
chmod +x .git/hooks/pre-commit

# Test hook
.git/hooks/pre-commit
```

---

## Release Process

### Version Management

NilClaw uses semantic versioning with CalVer influences:

```lisp
;; In nilclaw.asd
(defsystem "nilclaw"
  :version "0.1.0"
  :description "Statically typed Common Lisp agent harness"
  ;; ... rest of system definition
  )
```

### Release Checklist

Before releasing:

1. ✅ All tests pass (`make test`)
2. ✅ Traceability metrics met (`make traceability`)  
3. ✅ Documentation updated
4. ✅ CHANGELOG.md updated
5. ✅ Version bumped in nilclaw.asd
6. ✅ Git tags created and signed

### Creating Releases

```bash
# Update version
vim nilclaw.asd

# Final testing
make test
make traceability

# Commit version bump
git add nilclaw.asd
git commit -S -m "chore: bump version to 0.1.1

Co-authored-by: htayj <htayj@users.noreply.github.com>"

# Tag release  
git tag -s v0.1.1 -m "Release version 0.1.1"

# Push release
git push origin main
git push origin v0.1.1
```

---

## Best Practices

### Code Organization
- Keep functions focused and small
- Use meaningful names for functions and variables
- Group related functionality in packages
- Maintain clean separation between modules

### Type Safety
- Always include complete type declarations
- Use specific types rather than `t` when possible
- Validate inputs at system boundaries
- Handle edge cases explicitly

### Performance
- Profile before optimizing
- Use appropriate data structures
- Consider memory allocation patterns
- Benchmark critical paths

### Documentation  
- Write documentation as you code
- Include examples in docstrings
- Keep documentation synchronized with code
- Use clear, concise language

---

## Getting Help

### Community Resources
- **Issues**: Report bugs on [GitHub Issues](https://github.com/Kyvero-Vexus/nilclaw/issues)
- **Discussions**: Join conversations on [GitHub Discussions](https://github.com/Kyvero-Vexus/nilclaw/discussions)
- **Documentation**: Browse this site or check the `docs/` directory

### Development Questions
- Check existing issues and discussions first
- Provide minimal reproducible examples
- Include relevant system information
- Be specific about the problem you're facing

### Contributing Guidelines
See [CONTRIBUTING.md](https://github.com/Kyvero-Vexus/nilclaw/blob/main/CONTRIBUTING.md) for detailed contribution guidelines.

---

*Ready to contribute? Start with a small improvement or bug fix to get familiar with the codebase!*