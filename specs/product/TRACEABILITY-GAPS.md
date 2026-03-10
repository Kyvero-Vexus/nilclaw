# NilClaw Traceability Gaps

## Remaining gaps

- [x] No remaining L1 -> L2 gaps from current audit.
- [x] No remaining L2 -> L3 gaps (see `tests/TRACEABILITY-L3-MATRIX.md`).
- [x] No remaining L3 -> L4 gaps (see `src/TRACEABILITY-L4-MATRIX.md`).

## Notes

- Downstream mapping is now validated by `scripts/validate-traceability.py` with `--strict-downstream` / `--strict`.

## E2E blockers (2026-03-10)

Open blockers for full E2E execution are environment/runtime availability gaps, not current PASS-path regressions:

- Missing runtime entrypoints: `NILCLAW_CLI_BIN`, `NILCLAW_CRON_RUNTIME`, `NILCLAW_GATEWAY_BIN`, `NILCLAW_BOOTSTRAP_ENTRYPOINT`, `NILCLAW_PROVIDER_INTEGRATION`, `NILCLAW_SKILLS_LOADER_ENTRYPOINT`, `NILCLAW_STREAMING_RUNTIME`, `NILCLAW_SUBAGENT_RUNTIME`
- Missing service credentials/endpoints for channel/voice/MCP coverage: `TELEGRAM_BOT_TOKEN`, `SLACK_BOT_TOKEN`, `DISCORD_TOKEN`, `OPENAI_API_KEY`, `ELEVENLABS_API_KEY`, `MCP_SERVER_URL`

See `tests/E2E-RUN-REPORT.md` for per-case skip mapping.
