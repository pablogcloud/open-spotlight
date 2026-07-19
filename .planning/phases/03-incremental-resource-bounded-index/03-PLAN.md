---
phase: 3
mode: mvp
goal: Keep the index current without sustained foreground-level resource use
verification: required
---

# Phase 3 Plan - Incremental and resource-bounded indexing

## Pre-registered resource fixture

- Reference machine: Pablo's current 12-logical-core Mac, recorded by model/OS in
  the verification file.
- Corpus: 10,000 supported files, 1 GiB normalized extracted UTF-8 text, with
  embeddings enabled after the FTS lane.
- Active sample: 10 minutes after a 60-second warm-up; process CPU p95 at or below
  100% in Activity Monitor semantics.
- Idle sample: five minutes beginning 60 seconds after the queue drains; average
  process CPU at or below 1% and p95 at or below 2%.
- Memory: peak RSS increase over the pre-index idle baseline at or below 256 MiB.
- Storage: database plus WAL/SHM at or below `4 x` normalized extracted bytes plus
  64 MiB on the fixture after checkpoint/compaction.

These thresholds may be changed only before Phase 3 implementation, with the
reason and user approval recorded; they cannot be relaxed after measurements.

## Deliverables

1. Seed each root once, then subscribe to FSEvents using a persisted event cursor.
2. Coalesce bursts and map create/modify/rename/move/delete events to idempotent
   queue work; recover from dropped-event/full-rescan conditions.
3. Track file resource identifier, canonical path, size/mtime and content
   fingerprint so renames do not duplicate extraction or embeddings.
4. Run at utility priority with configurable worker limits; default to at most one
   logical core and reduce/pause for battery, Low Power Mode or thermal pressure.
5. Publish phase, current file, throughput, ETA, queue depth, storage use and last
   successful update without polling loops that create idle CPU load.
6. Add storage quotas, compaction, orphan cleanup and explicit rebuild/delete.

## Acceptance gates

- Create/edit/rename/move/delete appears in search within five seconds after the
  settled event; repeated event bursts produce one final document state.
- Lost-event simulation triggers a safe scoped reconciliation.
- Default active process CPU p95 stays at or below 100%; after the queue drains,
  idle CPU average is at or below 1% and p95 at or below 2%; memory and storage
  satisfy the pre-registered fixture thresholds above.
- Battery/thermal tests demonstrate reduced or paused work.
- No rename creates duplicate chunks or embeddings.

## Verification

Run FSEvents integration, resource sampling, burst/coalescing, storage and idle-
CPU tests on a controlled corpus. Record `03-VERIFICATION.md`, then run the
focused Grok audit.
