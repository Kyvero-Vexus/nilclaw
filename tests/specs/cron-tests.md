---
Layer: L2
Lane: integration
Spec ID: L2-INT-cron-tests
Status: draft
Last Updated: 2026-03-10
Traceability:
  L1: [L1-EXT-cron-heartbeat, L1-OPS-baseline-operations]
  L0: [F-AGENT-SCHEDULING, C-REL-TIMEOUT-RETRY]
---

# Cron Test Specifications

## Overview
The cron module provides scheduled task execution with support for recurring (cron expression) and one-shot (duration-based) jobs. It includes shell and agent job types, persistence via JSON, run history tracking, delivery of results via an event bus, and pause/resume controls.

---

## Duration Parsing

### Minutes
- "30m" → 1800 seconds

### Hours
- "2h" → 7200 seconds

### Days
- "1d" → 86400 seconds

### Weeks
- "1w" → 604800 seconds

### Seconds
- "30s" → 30 seconds

### Default unit is minutes
- "5" (no suffix) → 300 seconds

### Empty string → EmptyDelay error
### Unknown unit → UnknownDurationUnit error ("5x")

---

## Timestamp Formatting

### Known UTC timestamp
- 1772460000 → "Mon Mar 02 2026 14:00:00 UTC"

### Unix epoch
- 0 → "Thu Jan 01 1970 00:00:00 UTC"

### Negative timestamp → "invalid timestamp"

### Exact-size buffer (28 bytes) → works
### Undersized buffer (27 bytes) → "buffer too small"

---

## Cron Expression Handling

### normalizeExpression
- 5 fields (standard cron) → needs second prefix
- 6 fields (with seconds) → does not need prefix
- 4 fields → InvalidCronExpression error

### nextRunForCronExpression
- `*/5 * * * *` from epoch → 300 seconds (5 minutes)
- `0 * * * *` from epoch → 3600 seconds (1 hour)
- `30 2 * * *` from epoch → 9000 seconds (2:30 AM)
- Sunday aliases: `0 0 * * 0` and `0 0 * * 7` produce same next run
- Leap day: `0 0 29 2 *` from epoch → 68169600 seconds

---

## CronScheduler

### Add and list
- Add job with expression + command → listed with correct fields, not one_shot, not paused

### addOnce creates one-shot
- Add with duration → one_shot=true

### Remove
- Remove by ID → job gone, list returns 0

### Generated IDs stay unique after removals
- Add 3 jobs, remove middle one, add new → new ID differs from all previous

### Pause and resume
- Pause → paused=true, resume → paused=false

### Max tasks enforced
- Scheduler with max_tasks=1 → second addJob returns MaxTasksReached error

### getJob
- Valid ID → returns job
- Invalid ID → null

### getMutableJob
- Returns mutable pointer for valid ID
- Returns null for unknown ID

### updateJob modifies fields
- Patch with new command + enabled=false → command updated, enabled=false, paused=true

### updateJob keeps agent command and prompt in sync
- Updating command on agent job → prompt also updated
- Updating prompt + model explicitly → both command and prompt updated

### Remove frees agent job fields
- Remove agent job with prompt/model → no memory leaks

---

## Persistence (Save/Load)

### Save and load roundtrip
- 2 jobs (1 recurring with last_run, 1 one-shot) → saved and loaded with all fields intact

### JSON-sensitive command characters roundtrip
- Command with quotes, newlines, backslashes → preserved through save/load

### Agent fields roundtrip
- Agent job with prompt + model → job_type=agent, prompt and model preserved

### cliRunJob persists last status and timestamp
- Run a job via CLI → last_run_secs and last_status set to "ok"

### resolveRunnableCwd
- Valid directory → returns path
- Missing directory → null

### reloadJobs auto-recovers malformed store
- Malformed JSON on disk → keeps runtime jobs, heals store file

---

## Enums

### JobType
- "shell" → shell, "agent" / "AGENT" → agent (case insensitive)
- shell.asStr() → "shell", agent.asStr() → "agent"

### SessionTarget
- "isolated" → isolated, "main" / "MAIN" → main (case insensitive)
- isolated.asStr() → "isolated", main.asStr() → "main"

### DeliveryMode
- Parse and asStr roundtrip for all modes

### CronJob field initialization
- Job with all new fields (job_type, session_target, enabled, created_at_s) → all accessible

---

## Run History

### addRun and listRuns
- Add 2 runs → listRuns returns entries

### addRun prunes history
- Add 5 runs with max_history=3 → only ≤3 retained

### listRuns returns only matching job runs when interleaved
- 2 jobs with interleaved runs → listRuns for job A returns only job A's 2 runs

---

## Tick Execution

### Removes more than 64 one-shot jobs in one pass
- 80 one-shot agent jobs with 1s delay, tick at +2s → all 80 removed (0 jobs remaining)

### Tick without bus still executes jobs
- Jobs run even when no event bus is connected

### Tick reschedules recurring job using cron expression
- After tick fires recurring job → next_run_secs updated

### One-shot job deleted after tick execution
- One-shot job fires → removed from scheduler

---

## Delivery

### deliverResult creates correct OutboundMessage
- mode=always, channel="telegram", to="chat123" → message published to bus

### deliverResult with mode=none does nothing
- No message published

### deliverResult with no channel does nothing
- Null channel → no message published

### deliverResult on_success skips on failure
- mode=on_success, success=false → no delivery

### deliverResult on_error skips on success
- mode=on_error, success=true → no delivery

### deliverResult on_error delivers on failure
- mode=on_error, success=false → message published

### deliverResult uses default chat_id when to is null
- Null to field → uses default chat_id from config

### deliverResult skips empty output
- Empty output string → no delivery

### deliverResult best_effort swallows closed bus error
- Bus already closed → no error propagated (swallowed)

---

## Shell and Agent Job Execution

### Shell job uses configured cwd for relative output paths
### Shell job delivers stdout via bus
### Agent job delivers result via bus

---

## Utility

### collectChildOutputWithTimeout disables timeout when zero
- timeout=0 → no timeout enforced

### collectChildOutputWithTimeout kills process after deadline
- Slow process → killed after timeout

### preferAgentExecPath
- Regular path → kept
- Deleted Linux path (with " (deleted)" suffix) → uses /proc/self/exe

### pathAgentExecutableName → platform-specific command name

---

## Module Compilation

### cron module compiles without errors
