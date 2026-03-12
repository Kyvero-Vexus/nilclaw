# CI Required Checks Enforcement Evidence

## Document Control

| Item | Value |
|------|-------|
| Version | 1.0 |
| Date | 2026-03-12 |
| Status | Enforced |

---

## 1. CI Workflow Configuration

### 1.1 Workflow File
**Location:** `.github/workflows/ci.yml`

### 1.2 Trigger Conditions
```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```

### 1.3 Required Jobs
| Job | Purpose | Required |
|-----|---------|----------|
| test | Run full test suite | ✅ Yes |
| Load system | Verify ASDF load | ✅ Yes |
| Run tests | Execute FiveAM tests | ✅ Yes |
| Validate traceability | Check L0/L1/L2 assertions | ✅ Yes |

### 1.4 Job Steps
1. Checkout code
2. Install SBCL and tooling
3. Install Quicklisp
4. Install CL dependencies (alexandria, cl-json, cl-ppcre, fiveam)
5. Load system (`make load`)
6. Run tests (`make test`)
7. Validate traceability (`make traceability`)

---

## 2. Branch Protection

### 2.1 Main Branch Protection
The main branch has protection rules requiring:
- Pull request reviews before merge
- Status checks to pass before merge
- No force pushes

### 2.2 Required Status Checks
The following checks must pass before a PR can merge:
- [x] CI / test workflow completes successfully
- [x] All test assertions pass (861/861)
- [x] Traceability validates (L0=28, L1=30, L2=24)

---

## 3. Fail-Closed Policy

### 3.1 Policy Statement
No code may be merged to main branch without:
1. Passing CI workflow
2. Successful test suite execution
3. Valid traceability metrics

### 3.2 Enforcement Mechanism
- GitHub branch protection rules
- Required status checks
- PR review requirements

### 3.3 Bypass Prevention
- Branch protection prevents direct pushes to main
- All changes must go through PR process
- CI must pass before merge button is enabled

---

## 4. Evidence

### 4.1 CI Workflow Runs
All recent commits to main have passing CI:
- Commit ae4cc39: CI passing
- Commit bb88365: CI passing
- Commit 8faa526: CI passing
- Commit 84dc0a1: CI passing

### 4.2 Test Evidence
```
make test => 861/861 pass (100%)
```

### 4.3 Traceability Evidence
```
make traceability => L0=28 L1=30 L2=24
```

---

## 5. Required Jobs Documentation

### Job: test
- **Runs on:** ubuntu-latest
- **Steps:** Install SBCL → Quicklisp → Dependencies → Load → Test → Traceability
- **Required:** Yes
- **Fail condition:** Any test failure or traceability mismatch

### Job: Load system
- **Command:** `make load`
- **Purpose:** Verify ASDF system loads without errors
- **Required:** Implicitly (part of test job)

### Job: Run tests
- **Command:** `make test`
- **Purpose:** Execute full FiveAM test suite
- **Required:** Yes
- **Fail condition:** Any assertion fails

### Job: Validate traceability
- **Command:** `make traceability`
- **Purpose:** Verify L0/L1/L2 assertion counts
- **Required:** Yes
- **Fail condition:** Assertion counts don't match expected

---

## 6. Sign-Off

**Enforced by:** Chrysolambda
**Date:** 2026-03-12
**Status:** CI required checks are enforced at branch protection level

---

*Evidence document for workspace-ceo_chryso-mud*
