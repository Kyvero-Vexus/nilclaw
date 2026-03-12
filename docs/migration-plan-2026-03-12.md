# NilClaw OpenClaw → Lisp migration plan (2026-03-12)

Plan summary:
- Install NilClaw daemon and systemd service (launcher bin/nilclaw, contrib/nilclaw.service)
- Migrate OpenClaw config to NilClaw Lisp config via scripts/migrate-openclaw-config.lisp
- Store resulting Lisp init at ~/.nilclaw/init.lisp (secret keys loaded from env)
- Start NilClaw in development mode to verify config load and basic chat path
- Deploy production launcher and systemd service; supply API keys via EnvironmentFile
- Validate: run canary cutover tests, patch issues, update docs
- Ensure no API keys are stored in git; keep secrets in env

Planned steps (detailed):
1) Gather real OpenClaw config path (OPENCLAW_CONFIG_PATH). If unknown, fallback to typical places under ~/.openclaw/config.json.
2) Run migration script: sbcl --load scripts/migrate-openclaw-config.lisp --eval (migrate-openclaw-config:main "<OPENCLAW_CONFIG_PATH>" "~/.nilclaw/init.lisp") --quit
3) Validate Lisp config load: sbcl --eval "(progn (load \"~/.nilclaw/init.lisp\") (print 'OK))" --quit
4) Start NilClaw with launcher: bin/nilclaw start --config ~/.nilclaw/init.lisp
5) If systemd: copy launcher to /usr/local/bin/nilclaw, install contrib/nilclaw.service, adjust paths, enable & start via systemd
6) Secure keys: write ~/.nilclaw/env with API keys; set Permissions 600; reference via EnvironmentFile in systemd
7) Run a basic chat: send a message to the NilClaw instance and verify a reply
8) Bug triage: all issues found will be written to docs/issues.md and a short patch will be prepared
9) Update memory/dumps: add durable logs to memory/2026-03-12.md
10) Commit and push: include a coherent commit with signs; include Co-authored-by tag

Notes:
- All changes must avoid leaking API keys to git.
- Documentation updates will reflect the Lisp-based config and the new startup flow.

Owner: Chrysolambda (via Kyvero Vexus)