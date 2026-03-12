# Bug Report: Config Migration and CLI Issues (2026-03-12)

## Executive Summary

During the OpenClaw to NilClaw migration testing, 6 bugs were discovered and fixed in the config migration script and CLI. All bugs were blocking successful migration and first-run experience.

**CRITICAL FINDING:** While nilclaw daemon starts successfully, it does NOT have functional LLM integration yet. The channel implementations are stubs that print to stdout but don't call providers.

## Bugs Found and Fixed

### 1. Migration Script Crashes on Nested Arrays of Objects

**Issue:** The `emit-value` function in `migrate-openclaw-config.lisp` crashed when processing JSON arrays containing objects (e.g., the `models` array inside provider configs).

**Root Cause:** The function didn't convert nested alists to plists before emitting. When it encountered `(("id" . "openai/gpt-oss-20b") ...)`, it tried to process it as a plist but `(car v)` was a string, not a keyword.

**Fix:**
- Added `alistp` helper function to detect JSON alists
- Made `alist-to-plist` recursively handle arrays of objects
- Added alist detection in `emit-value` to convert on-the-fly

**Bead:** `nilclaw-3ky`

---

### 2. SCREAMING_SNAKE_CASE Key Conversion Mangles Keys

**Issue:** Environment variable keys like `OPENROUTER_API_KEY` were converted to `:O-P-E-N-R-O-U-T-E-R--A-P-I--K-E-Y` instead of `:OPENROUTER-API-KEY`.

**Root Cause:** The `to-lisp-key` function inserted a dash before EVERY uppercase letter after the first, not just at camelCase transitions.

**Fix:** Modified dash insertion logic to only trigger on lowercase->uppercase transitions (true camelCase), not for all-caps strings.

**Bead:** `nilclaw-01p`

---

### 3. FORMAT String Error with Tilde in Path

**Issue:** The final message `"NilClaw searches: ~/.nilclaw/..."` crashed with a FORMAT error.

**Root Cause:** The tilde `~` in the path was interpreted as a FORMAT directive (`~%` is newline, `~/` is invalid).

**Fix:** Escaped the tilde: `~~/.nilclaw` prints as `~/.nilclaw`.

**Bead:** `nilclaw-65g`

---

### 4. Undefined Function `parse-config`

**Issue:** `load-config` in `lisp-config.lisp` called `parse-config` which doesn't exist.

**Root Cause:** Function was named `parse-config-from-string` in `parse.lisp`, not `parse-config`.

**Fix:** Changed the call to use the correct function name.

**Bead:** `nilclaw-j6u`

---

### 5. json-getf Expects Alists But Receives Plists

**Issue:** `validate-config` crashed with a TYPE-ERROR when processing channel configs.

**Root Cause:** `json-getf` used `assoc` which only works on alists (`((:key . val) ...)`), but the Lisp config reader produces plists (`(:key val ...)`).

**Fix:** Modified `json-getf` to detect plist vs alist format and use `getf` for plists, `assoc` for alists.

**Bead:** `nilclaw-8pf`

---

### 6. CLI Doesn't Filter `--` Separator

**Issue:** Running `nilclaw help` showed "Unknown command: --".

**Root Cause:** The bash launcher passes `-- "$@"` to SBCL, and SBCL's `uiop:command-line-arguments` includes the `--` in the returned list.

**Fix:** Filter `--` from the arguments list in `main()`.

**Bead:** `nilclaw-5f3`

---

## Additional Issues Found

### 7. Launcher Script NILCLAW_ROOT Detection

**Issue:** When installed to `~/.local/bin/nilclaw`, the script computed the wrong root directory.

**Fix:** Added fallback to check `~/projects/nilclaw` if not in project tree, with helpful error message if neither works.

---

## CRITICAL: Missing Core Functionality

The following features are **NOT IMPLEMENTED** - they exist as stubs only:

### 8. CLI Channel Has No LLM Integration (P0)

**Issue:** The CLI channel's `channel-send` just prints to stdout. There's no integration with the provider system to actually call LLMs.

**Status:** Bead `nilclaw-8ea` created (P0 feature)

**Required Work:**
- Wire up dispatcher to receive incoming messages
- Call provider with messages
- Send provider response back via channel

---

### 9. Provider Integration Not Wired to Channels (P0)

**Issue:** `provider-complete` exists in `src/provider/compatible.lisp` but is never called. The agent system exists but doesn't actually process messages.

**Status:** Bead `nilclaw-vl7` created (P0 feature)

**Required Work:**
- Implement agent loop: receives message → calls provider → sends response
- Wire dispatcher to channel receive events
- Handle streaming vs non-streaming responses

---

## Status Summary

| Component | Status |
|-----------|--------|
| Config Migration | ✅ Working |
| Config Loading | ✅ Working |
| Daemon Startup | ✅ Working |
| Channel Stubs | ⚠️ Stub only |
| LLM Integration | ❌ Not implemented |
| Chat Functionality | ❌ Not working |

---

## Reproduction

```bash
# Generate migrated config (WORKS)
cd ~/projects/nilclaw
sbcl --script scripts/migrate-openclaw-config.lisp ~/.openclaw/openclaw.json ~/.nilclaw/init.lisp

# Check config (WORKS)
nilclaw check

# Start daemon (WORKS)
nilclaw start

# Chat with agent (DOES NOT WORK - stub only)
# There is no REPL/chat interface yet
```

---

## Next Steps

1. **P0: Implement agent loop** - Wire provider to channels
2. **P0: Add CLI chat command** - Interactive REPL for testing
3. **P1: Test with real API keys** - Once integration works
4. **P2: Channel adapters** - Telegram, web, etc.
