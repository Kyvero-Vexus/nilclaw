# E2E Spec: Provider Abstraction & Multi-Model Specification

## Requirements
- Runnable NilClaw build and CLI available locally.
- Provider/channel credentials required by exercised scenarios (test tokens only).
- Network access to configured APIs/webhooks/channels as needed.
- Writable temp workspace for fixtures and captured logs.

## Scope
Validate `specs/extracted/provider-abstraction.md` behavior via running-app interfaces only (CLI, gateway APIs, channels, MCP/tool calls).

## Setup
1. Prepare clean workspace and deterministic test config.
2. Export required secrets/env vars for the selected scenarios.
3. Start NilClaw services (and gateway when applicable) with logs enabled.
4. Confirm readiness before executing scenarios.

## Test Scenarios
- Validate **Overview** through real CLI/API/channel interactions.
- Validate **Provider Interface** through real CLI/API/channel interactions.
- Validate **Core Types** through real CLI/API/channel interactions.
- Validate **Provider Implementations** through real CLI/API/channel interactions.
- Validate **Reliable Provider (Retry & Fallback)** through real CLI/API/channel interactions.
- Validate **Agent Routing** through real CLI/API/channel interactions.
- Validate **Model Route Format** through real CLI/API/channel interactions.
- Validate **API Key Resolution** through real CLI/API/channel interactions.

## Procedure (Per Scenario)
1. Arrange test preconditions and fixtures.
2. Execute behavior through real interface(s).
3. Capture observable outputs (exit code, HTTP response, channel events, logs).
4. Assert expected outcomes and error handling.
5. Reset modified state.

## Expected Outcomes
- Externally visible behavior matches the source spec for success and failure paths.
- Errors are actionable and do not crash the process.
- Routing/auth/rate-limit behavior is correct where applicable.

## Troubleshooting Signals
- Startup or health-check failure indicates configuration or secret mismatch.
- HTTP 4xx/5xx or missing channel events indicates routing/auth integration defects.
- Timeout/backoff anomalies indicate reliability policy regressions.

## Teardown
1. Stop services and clear temporary fixtures.
2. Scrub transient credentials and archive logs for debugging.

## Traceability
- Source spec: `specs/extracted/provider-abstraction.md`
- Bead: `nilclaw-9gi`
