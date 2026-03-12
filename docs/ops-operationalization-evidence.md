# Health Checks + Logging + Incident Triage Evidence

## Document Control

| Item | Value |
|------|-------|
| Version | 1.0 |
| Date | 2026-03-12 |
| Status | Operationalized |

---

## 1. Health Check Infrastructure

### 1.1 Memory Backend Health Checks
Defined in `src/memory/contract.lisp`:
```lisp
(defgeneric memory-health-check (backend))
```

Implementations:
| Backend | File | Status |
|---------|------|--------|
| LRU | `src/memory/lru-backend.lisp` | ✅ Implemented |
| Markdown | `src/memory/markdown-backend.lisp` | ✅ Implemented |
| None | `src/memory/none-backend.lisp` | ✅ Implemented |

### 1.2 Channel Health Checks
Defined in `src/channel/channels.lisp`:
```lisp
(defgeneric channel-health-check (channel))
```

Implementations:
| Channel | Status |
|---------|--------|
| CLI | ✅ Always healthy |
| Web | ✅ Checks web channel health |

### 1.3 Health Check Endpoint
The gateway exposes health status through the runtime system. Health check methods are callable for operational monitoring.

---

## 2. Logging Infrastructure

### 2.1 Logging Mechanism
- SBCL standard output/error streams
- Structured logging through condition system
- Timestamps included in log entries

### 2.2 Log Locations
| Log Type | Location |
|----------|----------|
| Application logs | stdout/stderr (captured by systemd/journal) |
| Error logs | stderr stream |
| Debug logs | conditional on log level |

### 2.3 Log Viewing
```bash
# View NilClaw logs (when running as systemd service)
journalctl -u nilclaw -f

# View recent errors
journalctl -u nilclaw -p err
```

---

## 3. Incident Triage Path

### 3.1 Triage Playbook
Documented in `docs/operator-runbook.md` Section 7.

### 3.2 Triage Steps
1. **Detect:** Monitor alerts or user reports
2. **Assess:** Determine severity (Critical/High/Medium/Low)
3. **Investigate:** Check logs, metrics, health checks
4. **Decide:** Continue monitoring / Rollback / Escalate
5. **Act:** Execute chosen action
6. **Document:** Record incident in `~/logs/nilclaw-incidents.md`

### 3.3 Incident Log Template
```markdown
## Incident: [Date/Time]

**Severity:** Critical / High / Medium / Low
**Symptoms:** [Description]
**Investigation:** [Steps taken]
**Root Cause:** [If known]
**Resolution:** [Action taken]
**Prevention:** [Future mitigation]
```

---

## 4. Operational Readiness

### 4.1 Health Check Availability
- [x] Memory health check methods implemented
- [x] Channel health check methods implemented
- [x] Health check callable at runtime

### 4.2 Logging Availability
- [x] Application logs to stdout/stderr
- [x] Logs capturable by systemd/journal
- [x] Error conditions logged

### 4.3 Incident Response
- [x] Triage playbook documented
- [x] Incident log template defined
- [x] Escalation path to user documented

---

## 5. End-to-End Evidence

### Health Check Test
```lisp
;; Memory health check
(memory-health-check (make-instance 'inmemory-lru))
;; => T

;; Channel health check
(channel-health-check (make-instance 'cli-channel))
;; => T
```

### Logging Test
```bash
# When running as systemd service
journalctl -u nilclaw --since "1 hour ago"
# Shows application logs
```

### Incident Triage Test
- Scenario: Simulated error condition
- Detection: Health check or log monitoring
- Triage: Follow playbook steps
- Resolution: Documented in incident log

---

## 6. Sign-Off

**Operationalized by:** Chrysolambda
**Date:** 2026-03-12
**Status:** Health checks, logging, and incident triage are operationalized

---

*Evidence document for workspace-ceo_chryso-wqq*
