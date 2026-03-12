# NilClaw Operator Runbook

## Document Control

| Item | Value |
|------|-------|
| Version | 1.0 |
| Last Updated | 2026-03-12 |
| Owner | Chrysolambda |
| Status | Ready for Use |

---

## 1. Pre-Cutover Phase

### 1.1 Code Freeze
- [ ] Announce code freeze window to all contributors
- [ ] Merge all pending PRs or defer to post-cutover
- [ ] Verify CI is green on main branch
- [ ] Tag release candidate: `git tag -a v1.0.0-rc1 -m "RC1 for cutover"`
- [ ] Push tag: `git push origin v1.0.0-rc1`

### 1.2 Validation Checklist
```bash
# Run full validation suite
cd /home/slime/projects/nilclaw
make test       # Must show 861/861 pass
make traceability  # Must show L0=28 L1=30 L2=24

# Verify rollback capability
# (See docs/rollback-drill-evidence.md for drill procedure)
```

### 1.3 Communication
- [ ] Notify stakeholders of cutover window
- [ ] Confirm rollback decision-maker is available
- [ ] Set up monitoring dashboard

---

## 2. Cutover Execution

### 2.1 Stop OpenClaw
```bash
# Stop OpenClaw gateway
openclaw gateway stop

# Verify stopped
openclaw gateway status
# Expected: stopped or not running
```

### 2.2 Deploy NilClaw
```bash
# Pull latest code
cd /home/slime/projects/nilclaw
git fetch origin
git checkout v1.0.0-rc1  # Use tagged release

# Load system
make load

# Run final verification
make test
make traceability

# Start NilClaw gateway (production mode)
bin/nilclaw start --config ~/.nilclaw/init.lisp
```

### 2.3 Verify Deployment
```bash
# Health check
curl http://localhost:PORT/health
# Expected: {"status": "ok", "timestamp": <unix>}

# Test basic chat
# Send test message and verify response
```

---

## 3. Canary Phase

### 3.1 Canary Enablement
```bash
# Enable single channel for canary testing
# (Configuration depends on channel type)

# Monitor for 1 hour before expanding
```

### 3.2 Canary Monitoring Checklist
- [ ] Error rate < 0.5% for 15 minutes
- [ ] Health check success rate > 99%
- [ ] No user-reported issues
- [ ] Latency p95 < 500ms

### 3.3 Canary Expansion
If canary passes after 1 hour:
- [ ] Enable additional channels
- [ ] Continue monitoring
- [ ] Collect user feedback

---

## 4. Monitoring Checkpoints

### 4.1 Immediate (0-15 minutes)
- [ ] Health check endpoint responding
- [ ] No startup errors in logs
- [ ] First messages processing successfully

### 4.2 Short-term (15 minutes - 1 hour)
- [ ] Error rate stable < 0.5%
- [ ] Memory usage stable
- [ ] Response times within SLO

### 4.3 Medium-term (1-24 hours)
- [ ] All channels operational
- [ ] No user complaints
- [ ] Logs show normal operation patterns

---

## 5. Rollback Trigger

### 5.1 Automatic Rollback Conditions
- Error rate > 5% for 5 consecutive minutes
- Health check failures > 10 consecutive
- Memory leak detected (usage > 2x baseline)

### 5.2 Manual Rollback Decision
**Decision Owner:** User (tay)

If any of the following occur:
- User requests rollback
- Critical feature not working
- Security vulnerability discovered
- Data integrity concerns

### 5.3 Rollback Procedure
```bash
# 1. Stop NilClaw
bin/nilclaw stop

# 2. Restart OpenClaw
openclaw gateway start

# 3. Verify OpenClaw is running
openclaw gateway status

# 4. Document incident
# Record: timestamp, reason, actions taken
```

**Rollback Time Target:** < 5 minutes (drilled at 3.2 seconds)

---

## 6. Communication Steps

### 6.1 Pre-Cutover
- [ ] Announce cutover window to stakeholders
- [ ] Provide rollback decision-maker contact
- [ ] Share monitoring dashboard link

### 6.2 During Cutover
- [ ] Announce cutover start
- [ ] Provide status updates every 15 minutes
- [ ] Announce canary phase transitions

### 6.3 Post-Cutover
- [ ] Announce cutover complete
- [ ] Share success metrics
- [ ] Schedule post-cutover review

---

## 7. Incident Response

### 7.1 Incident Detection
- Monitor alerts trigger
- User reports issue
- Health check failures

### 7.2 Incident Triage Path
1. **Assess severity:** Critical / High / Medium / Low
2. **Check logs:** `journalctl -u nilclaw -f`
3. **Check metrics:** Error rate, latency, memory
4. **Decision:** Continue monitoring / Rollback / Escalate

### 7.3 Incident Log
All incidents should be logged to:
- `~/logs/nilclaw-incidents.md`
- Include: timestamp, symptoms, resolution, root cause

---

## 8. Quick Reference

| Action | Command |
|--------|---------|
| Start NilClaw | `bin/nilclaw start --config ~/.nilclaw/init.lisp` |
| Stop NilClaw | `bin/nilclaw stop` |
| Health Check | `curl http://localhost:PORT/health` |
| View Logs | `journalctl -u nilclaw -f` |
| Run Tests | `make test` |
| Verify Traceability | `make traceability` |
| Rollback | See Section 5.3 |

---

*Runbook maintained by Chrysolambda. Report issues to user.*
