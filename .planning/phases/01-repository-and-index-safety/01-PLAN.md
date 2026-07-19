---
phase: 1
mode: mvp
goal: Make the repository reproducible and prevent unsafe indexing behavior
verification: required
---

# Phase 1 Plan - Repository truth and index safety

## Deliverables

1. Create the first clean feature-branch commit only after a secret/personal-data
   scrub; activate repository hooks and record the clean-checkout build path.
2. Replace raw path preferences with an approved-root policy that rejects `/`,
   system/private/volume roots, hidden credentials, packages, caches, dependency
   trees, and symlink escapes. Provide sensible user-folder suggestions.
3. Add an explicit expert override only if it can display consequences and still
   preserve hard-denied security paths.
4. Stop deleting the usable index at rebuild start. Distinguish `idle`,
   `inventorying`, `indexing`, `paused`, `cancelled`, `partial`, `complete`,
   `failed`, and `corrupt` in the model and settings UI.
5. Surface discovered/processed/indexed/skipped/failed counts and representative
   errors; remove blanket error swallowing.
6. Add the synthetic scope corpus and tests for denied roots, packages, hidden
   paths, credentials, symlinks, permissions and malformed files.
7. Lock the local-versus-AI routing rule immediately: opening a file or pressing
   Return on an ordinary search can never invoke a provider; Ask-AI remains an
   explicit action even when local search is empty.
8. Add a one-time legacy-root migration. At startup, cancel work for persisted
   forbidden roots such as `/`, quarantine the contaminated generation, remove
   the forbidden preference, exclude its rows from search immediately, preserve
   a recoverable database backup, and offer reindexing only approved user roots.

## Acceptance gates

- Selecting `/`, `/System`, `/Library`, `/private`, or a volume root is rejected
  in model and UI tests; denied descendants never reach extraction/storage.
- Starting, cancelling or failing a rebuild leaves the prior index searchable.
- All skipped/failed items affect counters and bounded error reporting.
- A clean checkout regenerates, builds and tests without personal configuration.
- Real settings UI accurately distinguishes partial from complete indexing.
- Routing tests prove ordinary app/file/folder/command search never falls through
  to provider execution.
- A fixture containing persisted root `/` plus mixed `/Library` and user rows is
  quarantined on launch: no contaminated row is searchable, no crawl continues,
  the backup exists, and only newly approved roots can seed the replacement.

## Verification

Run scope/property tests, a destructive-rebuild regression test, full build/test,
and the real folder-picker/status flow. Record `01-VERIFICATION.md`, then use the
focused Grok audit.
