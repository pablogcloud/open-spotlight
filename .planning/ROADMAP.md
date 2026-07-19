# Open Spotlight Roadmap

The public-MVP roadmap is evidence-gated. A capability is not complete because a
screen, type, database table, or unit test exists; it is complete only after its
phase verification record proves the end-to-end behavior in the built app.

## Phase 0 - Existing walking skeleton (re-baseline only)

Inventory the current launcher, search, provider, attachment, animation, and
partial local-index code. Replace stale claims with a capability ledger using
`absent`, `partial`, `implemented-unverified`, or `verified`.

## Phase 1 - Repository truth and index safety

Establish a reproducible baseline, block unsafe whole-volume indexing, define
approved-root policy, preserve partial indexes, expose honest status/errors, and
create the deterministic file corpus used by later phases.

## Phase 2 - Durable resumable index

Add versioned SQLite migrations, persistent approved roots, security-scoped
bookmarks, durable run/queue state, generational rebuilds, pause/resume/cancel,
and crash recovery without deleting the last usable index.

## Phase 3 - Incremental and resource-bounded indexing

Add FSEvents updates, event coalescing, rename/delete handling, file identity and
fingerprints, utility-priority scheduling, CPU/thermal/battery budgets, progress,
ETA, storage accounting, and corruption recovery.

## Phase 4 - Extraction and hybrid retrieval

Introduce extractor adapters for text, Markdown, PDF, and common office files;
metadata-only fallback; FTS-first availability; optional versioned embeddings;
deterministic date/type/root filters; hybrid ranking; and retrieval benchmarks.

## Phase 5 - File-aware AI answers and citations

Turn retrieval results into a multi-document context proposal, disclose exact
outgoing excerpts and destination provider, require confirmation, isolate
untrusted document text, stream cited answers, and support Open, Reveal, and
Quick Look actions without accidental agent execution.

## Phase 6 - Provider and authentication hardening

Harden Claude, Codex, and Grok adapters with version fixtures, executable and
authentication states, official login flows, safe environment construction,
ambient-context disclosure, tool restrictions where supported, process-tree
cancellation, and isolated failures.

## Phase 7 - Launcher completeness and native quality

Finish deterministic app/file/command search, suggestions, history and routing;
settings and menu-bar controls; multi-display placement; response and permission
UX; Liquid Glass/reduced-motion behavior; VoiceOver; keyboard UAT; launch latency;
frame pacing; and duplicate-hotkey prevention.

## Phase 8 - Constrained extension SDK

Ship one declarative, permissioned command format with schema validation,
installation and removal, explicit executable/network/file declarations,
examples, and security tests. No marketplace or arbitrary renderer runtime.

## Phase 9 - Open-source repository and source preview

Resolve project naming and asset rights, select licenses and contributor terms,
scrub the repository, reconcile documentation, add community/security files and
CI, create clean build instructions, and prepare a clearly labelled source-only
pre-alpha. Making the GitHub repository public remains an explicit user gate.

## Phase 10 - Signed public beta

Add Developer ID signing, Hardened Runtime, notarization and stapling, packaging,
versioning, signed updates or an explicit no-updater policy, migrations, privacy
controls, opt-in redacted diagnostics, SBOM/notices/checksums, clean-Mac testing,
and a rollback procedure.

## Critical path

```text
0 -> 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 ---\
      \-> 9 (source preview) --------------------> 10
```

Phases may be researched in parallel, but implementation does not advance past a
dependency until its verification record and short Grok audit are present.
