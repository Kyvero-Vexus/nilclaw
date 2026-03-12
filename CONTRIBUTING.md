# Contributing to NilClaw

Thank you for your interest in contributing to NilClaw! This document provides guidelines and instructions for contributing.

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help maintain a welcoming community

## Development Setup

### Prerequisites

- **SBCL** 2.5.2+ (Steel Bank Common Lisp)
- **Quicklisp** (Common Lisp package manager)
- **Git** with GPG signing configured

### Getting Started

```bash
# Fork and clone
git clone https://github.com/YOUR-USERNAME/nilclaw.git
cd nilclaw

# Install dependencies
sbcl --load ~/quicklisp/setup.lisp \
     --eval '(ql:quickload (list :alexandria :cl-json :cl-ppcre :fiveam))'

# Run tests
make test
```

## Development Workflow

### 1. Create a Branch

```bash
git checkout -b feature/your-feature-name
```

### 2. Make Changes

- Follow the coding standards below
- Add tests for new functionality
- Ensure all tests pass

### 3. Commit Changes

All commits must:
- Be GPG-signed (`git commit -S`)
- Follow conventional commit format
- Include co-authorship footer

```bash
git commit -S -m "feat(module): add new feature

Detailed description of the change.

Co-authored-by: htayj <htayj@users.noreply.github.com>"
```

### 4. Push and Create PR

```bash
git push origin feature/your-feature-name
```

Then create a pull request on GitHub.

## Coding Standards

### Static Typing

All code must use SBCL type declarations:

```lisp
(declaim (optimize (safety 3) (debug 3)))

(declaim (ftype (function (string) (values string &optional))
                process-input))
(defun process-input (input)
  (declare (type string input))
  ...)
```

### Structure Definitions

All structure slots must be typed:

```lisp
(defstruct my-structure
  (name "" :type string)
  (count 0 :type (integer 0 *))
  (enabled t :type boolean))
```

### Error Handling

Use Common Lisp conditions:

```lisp
(define-condition my-error (error)
  ((detail :reader my-error-detail :initarg :detail)))

(defun risky-operation ()
  (handler-case
      (do-something-dangerous)
    (error (e)
      (error 'my-error :detail (princ-to-string e)))))
```

### Documentation

All public functions must have docstrings:

```lisp
(defun process-message (message)
  "Process an incoming message and return a response.
   MESSAGE should be a string.
   Returns a string response."
  (declare (type string message))
  ...)
```

## Testing

### Running Tests

```bash
# Full test suite
make test

# Load only
make load

# Traceability
make traceability
```

### Writing Tests

Use FiveAM:

```lisp
(in-package #:nilclaw/tests)

(def-suite my-feature-suite :in nilclaw-suite)
(in-suite my-feature-suite)

(test my-feature-works
  "Test that my-feature does what it should."
  (let ((result (my-feature "input")))
    (is (string= "expected" result))
    (is (> (length result) 0))))
```

### Test Coverage

- All new features must have tests
- All tests must pass (838/838)
- Traceability must be maintained

## Commit Standards

### Conventional Commits

Use conventional commit prefixes:

| Prefix | Usage |
|--------|-------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation |
| `test` | Test changes |
| `refactor` | Code refactoring |
| `chore` | Maintenance |

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

Example:

```
feat(channel): add IRC channel adapter

Implement IRC protocol support with TLS and NickServ authentication.
Includes rate limiting and message queueing.

Closes #123

Co-authored-by: htayj <htayj@users.noreply.github.com>
```

### Required Footer

All commits must include:

```
Co-authored-by: htayj <htayj@users.noreply.github.com>
```

## Pull Request Guidelines

### PR Title

Use conventional commit format:

```
feat(channel): add IRC channel adapter
```

### PR Description

Include:
- What changes and why
- How to test
- Related issues
- Checklist

### PR Checklist

- [ ] All tests pass (`make test`)
- [ ] Traceability maintained (`make traceability`)
- [ ] Code follows style guide
- [ ] Documentation updated
- [ ] Commit messages follow standard
- [ ] Commits are GPG-signed

## Code Review

All PRs require:
- At least one approval
- All CI checks passing
- No unresolved conversations

## License

By contributing, you agree that your contributions will be licensed under AGPL-3.0-or-later.

## Questions?

Open an issue for:
- Bug reports
- Feature requests
- Documentation improvements
- Questions about contributing

Thank you for contributing to NilClaw!
