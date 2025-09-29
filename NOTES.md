Zap v1 (porcelain on top of Git)

Strategy: keep .git/ exactly as-is. Use git CLI or libgit2 under the hood; add an AI layer (your Switchboard) for reasoning.

Core UX

zap commit → generates Conventional Commit subject/body from staged diff, matches repo’s style.

zap explain [RANGE|FILE] → plain-English summary of changes, with links to code hunks.

zap merge → conflict assistant that proposes minimal, tested patches; shows risk notes.

zap review → local PR review (static + AI); --escalate=claude when warranted.

zap changelog → auto-curate release notes by type/scope.

zap sync → safer pull: analyze incoming changes, highlight breaking spots before merge.

zap guard → pre-commit/CI policy checks (secrets, TODOs, license headers, test coverage deltas).

Smart context (tiny + sharp)

Diff packs, last N commits, repo style (.zap.toml), language mix, test results.

Business awareness (optional): CK Tech SOPs/issue taxonomy for better commit messages/tasks.

Works offline by default; cloud escalation only by policy flag.

Implementation sketch

Language: Zig (fits your plan; fast, single static binary).

Git access: start with shelling to git (robust, portable); later add libgit2 via @cImport.

AI: HTTP to switchboardd (your Rust router → local Ollama first, escalate if needed).

State: .zap/ folder for caches (embeddings, style profile); keep size bounded.

Example .zap.toml

[style]
type_scope_required=true
imperative=true
max_subject_len=72

[policies]
allow_cloud=false
block_secrets=true
require_tests_on= ["feat","fix","refactor"]

[routing]
prefer_local=true
escalate_on_long_ctx=true

Zap v2 (optional “better than Git” layers—still compatible)

Semantic history: attach structured metadata to commits (intent, risk, affected domains) in refs/notes or trailers → still Git-compatible.

Semantic diff: code-aware hunks (moved functions, API changes) for clearer reviews.

Task graph: lightweight links commit ↔ issue ↔ doc with signed notes.

Auto-backport/forward-port: policy-driven cherry-pick with conflict plans.

Repo health score: drift, test gaps, dependency risk, bus factor.

All stored in Git notes or a sidecar .zap/notes.sqlite so Git remains the source of truth.

Zap v3 (experimental DVCS path—opt-in, not default)

If you ever choose to go beyond Git:

CAS engine with content-defined chunking for huge monorepos.

First-class refactor ops (rename/move tracked semantically).

Partial clone/sparse checkouts with AI-guided materialization (“fetch just the parts needed to fix this test”).

Reconciliation shim to keep mirroring to .git for interop.

This is future-you; don’t block v1 on it.

MVP plan (2–3 weeks)

Week 1

zap commit, zap explain, .zap.toml style learning

Switchboard integration (local models: Qwen-Coder 7B + Llama-3.1 8B)

Week 2

zap merge assistant (conflict parser + patch suggester)

zap changelog from commit trailers/Conventional Commits

zap guard (secrets, TODOs, license headers)

Week 3

zap review with inline suggestions (unified diff patches)

zap sync smart pull

Cache/telemetry (latency, local vs cloud hit rate)

CLI feels
# generate message from staged changes
zap commit -a

# summarize a PR range
zap explain origin/main..HEAD

# conflict help on current merge
zap merge --assist

# generate release notes since last tag
zap changelog v0.7.2..HEAD

# safe pull with preview
zap sync --preview

Why this wins

Day-1 useful on every repo you touch.

Private by default, blazing on a 4090, yet smart enough to escalate when needed.

Clear path to innovate (semantic history, smarter diffs) without fighting Git’s ecosystem.
