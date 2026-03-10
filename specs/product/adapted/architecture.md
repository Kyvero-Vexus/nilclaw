---
Layer: L1
Lane: architecture
Spec ID: L1-ADP-architecture
Status: draft
Last Updated: 2026-03-10
Traceability:
  L0: [F-UI-GATEWAY, F-AGENT-SESSIONS]
---

# Architecture Specification (Adapted from NullClaw docs)

> Frozen reference — do not modify. Source: NullClaw docs/en/architecture.md

## Overview

The system uses a pluggable architecture with interface-based abstraction.
Most capabilities are extended by implementing interfaces and registering
factories. Runtime implementation selection happens through factories, allowing
provider/channel/tool/memory swaps without core orchestration rewrites.

## Subsystems and Extension Points

| Subsystem       | Interface        | Built-in Implementations (partial)                                | Extension Approach             |
|-----------------|------------------|-------------------------------------------------------------------|--------------------------------|
| AI Models       | Provider         | OpenRouter, Anthropic, OpenAI, Ollama, Groq, and more            | Add provider + register        |
| Channels        | Channel          | CLI, Telegram, Signal, Discord, Slack, Matrix, WhatsApp, Nostr…  | Add channel + register         |
| Memory          | Memory           | SQLite (hybrid retrieval), Markdown                               | Add memory backend             |
| Tools           | Tool             | shell, file_read, file_write, http_request, browser_open…        | Add tool implementation        |
| Observability   | Observer         | Noop, Log, File, Multi                                            | Add observer backend           |
| Runtime         | RuntimeAdapter   | Native, Docker, WASM                                              | Add runtime adapter            |
| Security        | Sandbox          | Landlock, Firejail, Bubblewrap, Docker (auto)                     | Add sandbox backend            |
| Tunnel          | Tunnel           | None, Cloudflare, Tailscale, ngrok, Custom                        | Add tunnel provider            |
| Peripheral      | Peripheral       | Serial, Arduino, RPi GPIO, STM32/Nucleo                          | Add hardware driver            |

## Memory Stack

| Layer              | Implementation                                         |
|--------------------|--------------------------------------------------------|
| Vector retrieval   | Embeddings stored as BLOBs, cosine similarity search   |
| Keyword retrieval  | FTS5 with BM25 ranking                                |
| Hybrid merge       | Weighted vector + keyword merge                        |
| Embeddings         | Pluggable embedding provider (OpenAI/custom/noop)      |
| Data hygiene       | Automatic archive and purge                            |
| Snapshots          | Full export/import migration path                      |

## Design Constraints

1. Prefer extension through new implementations, not invasive core rewrites.
2. Keep subsystem boundaries strict — avoid cross-subsystem internal coupling.
3. For high-risk paths (security, runtime, gateway, tools), include boundary
   and failure-path validation.
