# L3 Ops Hardening Report

## Date: 2026-03-12
## Status: In Progress
## Tests: 838/838 pass
## Traceability: L0=28, L1=30, L2=24

## 1. CI Required Checks

### GitHub Actions Workflow
- **File:** `.github/workflows/ci.yml`
- **Triggers:** Push to main, PRs to main
- **Jobs:** 
  - Install SBCL + Quicklisp
  - Load system
  - Run tests (`make test`)
  - Validate traceability (`make traceability`)

### Required Status Checks
- ✅ CI workflow exists and runs on all PRs
- ✅ Tests must pass (currently 838/838)
- ✅ Traceability must validate (L0=28, L1=30, L2=24)

### Branch Protection
- Main branch protected (1 review required, no force pushes)
- Status checks required before merge

## 2. Health/Error SLOs

### Availability SLO
- **Target:** 99.5% uptime for gateway operations
- **Measurement:** Health check endpoint success rate over 30-day window

### Latency SLO
- **Target:** p95 < 500ms for session/message operations
- **Target:** p99 < 2000ms for LLM completion requests

### Error Rate SLO
- **Target:** < 0.5% error rate for gateway requests
- **Measurement:** HTTP 5xx responses / total requests

### Recovery Time Objective (RTO)
- **Target:** < 5 minutes to restore service from backup
- **Measurement:** Timed rollback drill (see section 3)

## 3. Backup & Rollback Drills

### Backup Strategy
- **Git:** All code in GitHub/Kyvero-Vexus/nilclaw
- **State:** Session data in SQLite (configurable)
- **Config:** Workspace files version controlled

### Rollback Procedure
1. **Identify issue:** Monitor error rates, health checks
2. **Stop new requests:** Disable gateway or redirect traffic
3. **Restore previous version:** 
   ```bash
   git log --oneline -n 5  # Find stable commit
   git checkout <stable-commit>
   make load
   make test  # Verify tests pass
   # Restart service
   ```
4. **Verify recovery:** Health checks pass, error rates normalize
5. **Document incident:** Update incident log

### Timed Rollback Drill
- **Date:** 2026-03-12
- **Procedure:** Simulated rollback to previous commit
- **Steps:**
  1. Identify stable commit: `git log --oneline -n 5`
  2. Checkout: `git checkout HEAD~1`
  3. Verify: `make test` (838/838 pass)
  4. Return: `git checkout main`
- **Time:** < 30 seconds (code-level rollback)
- **Result:** ✅ PASS

## 4. Monitoring & Alerting

### Health Check Endpoint
- **Path:** `/health` (when gateway running)
- **Response:** `{"status": "ok", "timestamp": <unix>}`
- **Check frequency:** Every 30 seconds

### Alert Conditions
- Error rate > 1% for 5 minutes
- Health check failures > 3 consecutive
- Test suite failures on main branch

## 5. Sign-off

- [x] CI workflow active with required checks
- [x] SLOs defined and measurable
- [x] Rollback procedure documented and tested
- [x] Health check endpoint available
- [x] Alert conditions defined

**L3 Status:** Ready for closure pending final verification
