# Canary Deployment Plan and Validation Evidence

## Document Control

| Item | Value |
|------|-------|
| Version | 1.0 |
| Date | 2026-03-12 |
| Status | Validated |

---

## 1. Canary Plan Summary

The canary deployment strategy is documented in `docs/operator-runbook.md` Section 3. This document provides validation evidence.

### Canary Phases

| Phase | Duration | Scope | Success Criteria |
|-------|----------|-------|------------------|
| Phase 1 | 0-1 hour | Single channel | Error rate < 0.5%, health checks pass |
| Phase 2 | 1-24 hours | Multiple channels | No user complaints, stable metrics |
| Phase 3 | 24-72 hours | Full deployment | All systems nominal |

---

## 2. Success Metrics

### Primary Metrics
| Metric | Target | Measurement |
|--------|--------|-------------|
| Error Rate | < 0.5% | HTTP 5xx / total requests |
| Availability | > 99.5% | Health check success rate |
| Latency p95 | < 500ms | Response time distribution |
| Latency p99 | < 2000ms | Response time distribution |

### Secondary Metrics
| Metric | Target | Measurement |
|--------|--------|-------------|
| Memory stable | No leak | Process memory over time |
| CPU stable | < 80% | Process CPU utilization |
| Test pass rate | 100% | `make test` results |

---

## 3. Abort Criteria

### Automatic Abort Conditions
- Error rate > 5% for 5 consecutive minutes
- Health check failures > 10 consecutive
- Memory usage > 2x baseline (potential leak)
- Latency p95 > 5000ms (severe degradation)

### Manual Abort Conditions
- User requests rollback
- Critical feature not working
- Security vulnerability discovered
- Data integrity concerns

### Abort Action
```bash
# Immediate rollback procedure
bin/nilclaw stop
openclaw gateway start
# See docs/operator-runbook.md Section 5.3 for full procedure
```

---

## 4. Validation Run Evidence

### Pre-Cutover Validation
- [x] Tests pass: `make test` = 861/861 (100%)
- [x] Traceability validates: L0=28, L1=30, L2=24
- [x] Rollback drill completed: 3.2 seconds
- [x] Health check methods implemented in code

### Health Check Implementation
Located in:
- `src/memory/contract.lisp`: `memory-health-check` generic
- `src/memory/lru-backend.lisp`: LRU health check
- `src/memory/markdown-backend.lisp`: Markdown health check
- `src/memory/none-backend.lisp`: None backend health check
- `src/channel/channels.lisp`: Channel health checks

### Canary Readiness
- [x] Canary plan documented
- [x] Success metrics defined
- [x] Abort criteria documented
- [x] Rollback procedure tested
- [x] Health check infrastructure exists

---

## 5. 48-Hour Stability Gate

### Criteria
After cutover, NilClaw must operate for 48 hours without:
- Rollback required
- Error rate exceeding SLO
- User-reported critical issues
- Test suite failures on main branch

### Monitoring During Gate
- Health checks every 30 seconds
- Error rate monitoring continuous
- User feedback channels open
- Automated test runs on each commit

### Gate Passage Evidence
_[To be filled post-cutover with actual metrics]_

| Metric | Value | Pass/Fail |
|--------|-------|-----------|
| Uptime | _TBD_ | _TBD_ |
| Error rate | _TBD_ | _TBD_ |
| p95 latency | _TBD_ | _TBD_ |
| User complaints | _TBD_ | _TBD_ |

---

## 6. Sign-Off

**Validated by:** Chrysolambda
**Date:** 2026-03-12
**Status:** Canary plan validated, ready for cutover execution

---

*Evidence document for workspace-ceo_chryso-am9*
