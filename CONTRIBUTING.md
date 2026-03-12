# Contributing to NilClaw

Thank you for your interest in contributing to NilClaw! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for all contributors.

## How to Contribute

### Reporting Issues

1. Check if the issue already exists in [GitHub Issues](https://github.com/Kyvero-Vexus/nilclaw/issues)
2. If not, create a new issue with:
   - Clear, descriptive title
   - Steps to reproduce (for bugs)
   - Expected vs. actual behavior
   - System information (SBCL version, OS, etc.)
   - Relevant code examples or error messages

### Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature-name`)
3. Make your changes following our coding standards
4. Run tests to ensure nothing breaks (`make test`)
5. Commit your changes (see Commit Guidelines below)
6. Push to your fork
7. Open a Pull Request

## Development Setup

### Prerequisites

- **SBCL** 2.2.0 or newer
- **Quicklisp** package manager
- **Git**
- **Make**
- **GPG** for signing commits

### Initial Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/nilclaw.git
cd nilclaw

# Install dependencies
sbcl --eval '(ql:quickload (list :alexandria :cl-json :cl-ppcre :fiveam))' --quit

# Load the system
make load

# Run tests
make test

# Verify traceability
make traceability
```

## Coding Standards

### Type Safety

NilClaw enforces **strict type declarations** throughout the codebase. All functions must include complete type information:

```lisp
;; Correct: Complete type declaration
(declaim (ftype (function (string fixnum) (values string &optional))
                process-message))
(defun process-message (content timeout)
  (declare (type string content)
           (type fixnum timeout))
  ;; Implementation
  )
```

### Code Style

- Use meaningful names for functions and variables
- Keep functions focused and small
- Include comprehensive documentation strings
- Follow Common Lisp naming conventions
- Use proper indentation (Emacs + SLIME recommended)

### Documentation

Every public function must include a docstring:

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

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run specific test suite
sbcl --eval '(ql:quickload :nilclaw/tests)' \
     --eval '(fiveam:run! :config-suite)' \
     --quit

# Verify traceability
make traceability
```

### Writing Tests

All new code must include tests:

```lisp
(in-package :nilclaw/tests)

(def-suite your-feature-suite
  :description "Tests for your feature")

(in-suite your-feature-suite)

(test your-feature-basic
  "Test basic functionality of your feature"
  (let ((result (your-function "test-data")))
    (is (not (null result)))
    (is (typep result 'expected-type))))
```

### Test Coverage

Maintain test coverage at all levels:
- **L0**: Unit tests for individual functions
- **L1**: Integration tests for subsystem interaction
- **L2**: End-to-end behavioral tests

Current metrics: **L0=28 L1=30 L2=24** with 838/838 tests passing

## Commit Guidelines

### Conventional Commits

Use conventional commit format:

```
type(scope): description

[optional body]

Co-authored-by: htayj <htayj@users.noreply.github.com>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Test changes
- `refactor`: Code refactoring
- `style`: Code style changes (formatting, etc.)
- `perf`: Performance improvements
- `chore`: Build process or auxiliary tool changes

### GPG Signing

All commits must be **GPG-signed**:

```bash
# Configure GPG signing (one-time setup)
git config --global commit.gpgsign true
git config --global user.signingkey YOUR_KEY_ID

# Commit with signature
git commit -S -m "feat: add new configuration option

Co-authored-by: htayj <htayj@users.noreply.github.com>"
```

### Co-authorship

All commits must include the co-authorship line:

```
Co-authored-by: htayj <htayj@users.noreply.github.com>
```

## Pull Request Process

### Before Submitting

1. ✅ All tests pass (`make test`)
2. ✅ Traceability maintained (`make traceability`)
3. ✅ Code compiles without warnings
4. ✅ Documentation updated
5. ✅ Commit messages follow guidelines
6. ✅ Branch is up-to-date with main

### PR Description Template

```markdown
## Summary
- Brief description of changes
- Why these changes were made
- Any relevant context

## Type of Change
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature causing existing functionality to change)
- [ ] Documentation update

## Testing
- [ ] Tests pass locally (`make test`)
- [ ] Traceability maintained (`make traceability`)
- [ ] New tests added for new functionality

## Checklist
- [ ] Code follows type safety standards
- [ ] Documentation updated
- [ ] Commit messages follow guidelines
- [ ] All commits are GPG-signed
```

### Review Process

1. PRs require at least one approval
2. All CI checks must pass
3. Resolve all review comments
4. Squash commits if requested
5. Maintainer will merge when ready

## Development Tips

### Interactive Development

Use Emacs + SLIME for the best development experience:

```lisp
;; In SLIME REPL
(ql:quickload :nilclaw)
(asdf:load-system :nilclaw :force t)

;; Test specific functions
(fiveam:run! 'your-test-name)

;; Debug interactively
(trace function-name)
(untrace)
```

### Debugging

```lisp
;; Enable debugger
(setf *debugger-hook* nil)

;; Trace execution
(trace your-function)

;; Step through code
(step (your-function args))

;; Inspect variables
(describe variable)
(inspect complex-object)
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
  (sb-profile:report))
```

## Questions or Problems?

- **Issues**: [GitHub Issues](https://github.com/Kyvero-Vexus/nilclaw/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Kyvero-Vexus/nilclaw/discussions)
- **Documentation**: This site and the `docs/` directory

## License

By contributing to NilClaw, you agree that your contributions will be licensed under the AGPL-3.0-or-later license.

---

Thank you for contributing to NilClaw! Your efforts help make this project better for everyone.