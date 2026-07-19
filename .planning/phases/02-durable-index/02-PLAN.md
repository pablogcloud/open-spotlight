---
phase: 2
mode: mvp
goal: Resume indexing after pause, cancellation, crash, or relaunch without data loss
verification: required
---

# Phase 2 Plan - Durable resumable index

## Deliverables

1. Add versioned migrations for `index_roots`, `index_runs`, `index_queue`,
   documents/generations, chunks/FTS, embeddings/version, and extraction errors.
2. Persist approved roots with security-scoped bookmarks and handle stale or
   revoked bookmarks visibly.
3. Inventory into a durable queue with idempotent jobs, attempt counts, priority,
   coalescing keys, and transactional state changes.
4. Use generational rebuilds: upsert a new generation, retain the old searchable
   generation, mark seen documents, and prune stale rows only after a successful
   inventory/commit.
5. Implement pause, resume and cancel across app relaunch. On startup, reclaim
   abandoned `processing` jobs and continue `pending` work.
6. Add schema migration, interrupted transaction, corrupt database backup/rebuild,
   and index deletion tests.

## Acceptance gates

- In a 10,000-file corpus, force-kill at 25%, 50%, and 90%; relaunch resumes and
  finishes with no duplicate documents/chunks and no missing expected files.
- Pause/cancel acknowledges within one second and persists correct state.
- The old generation remains searchable until the new generation commits.
- Revoked folder access stops work, reports the root, and does not escape scope.
- Schema upgrade and corruption recovery preserve or safely rebuild user data.

## Verification

Run deterministic crash/restart and migration harnesses plus full build/test;
exercise pause/relaunch/resume in the app. Record `02-VERIFICATION.md`, then run
the bounded Grok audit.

