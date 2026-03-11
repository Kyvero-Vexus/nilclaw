# L2 Provider HTTP Parity Plan

Status: **in progress**

This document captures the current provider HTTP layer state and remaining L2 work.

## Current Provider Capabilities

`src/provider/compatible.lisp` implements:
- `provider-complete`: retry-aware completion orchestration
- Transient error retry: `:timeout`, `:rate-limited`, `:network-fault`
- Non-retry errors: `:malformed-payload` and other non-transient codes fail fast
- Configurable `max-retries` per runtime
- Test coverage in `tests/providers-compatible-tests.lisp`

## L2 HTTP Layer Requirements

For full OpenClaw HTTP provider parity, nilclaw needs:

### 1. Real HTTP Transport
- HTTP client abstraction (Dexador or Drakma)
- Auth header injection (API key from config)
- Request building (model, messages, parameters)
- Response parsing (content, usage, provider error codes)

### 2. 429/Backoff Semantics
- Parse `Retry-After` header from 429 responses
- Exponential backoff with configurable floor/ceiling
- Integrate with existing `:rate-limited` retry path

### 3. Provider Error Mapping
- HTTP status → provider error code mapping
- Common provider error taxonomy (auth, rate limit, context length, etc.)
- Structured error payloads for agent/tool consumption

### 4. Config Integration
- Per-provider API keys from `config-providers`
- Base URL override support
- Native-tools flag awareness

## Test Requirements

L2 provider tests should exercise:
- Live HTTP stub with 200/429/5xx responses
- Retry-After header parsing
- Backoff timing invariants
- Error code mapping contract

## Current Blockers

- No real HTTP client implementation yet
- 429/Retry-After parsing not implemented
- Provider error taxonomy not defined

## Next Steps

1. Add HTTP client abstraction module
2. Implement 429/backoff semantics
3. Define provider error taxonomy
4. Add integration tests with HTTP stubs
5. Wire into config-providers
