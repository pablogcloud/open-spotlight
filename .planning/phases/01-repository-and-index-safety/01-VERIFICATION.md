# Phase 1 verification - Repository truth and index safety

**Status:** local gates passed; blocked on Grok audit verdict
**Commit:** `3a243b2`

## Claims and gates

| Gate | Result | Evidence |
|---|---|---|
| G1 root and scope safety | PASS | Model tests reject `/`, system/private roots and volume roots; hidden, credential, dependency, package and symlink-escape candidates never reach storage. |
| G2 usable-index preservation | PASS | Rebuild no longer deletes first; cancellation/failure preserves scoped rows; regression tests retain and retrieve sentinel content. |
| G3 honest run state | PASS | Settings exposes scanning/cancelled/partial/complete/failed/quarantined states, counts, bounded representative errors, cancellation, and explicit early-index limitations. |
| G4 reproducible repository | PASS | Secret/personal-path scan found no matches; hooks are active; root commit exists; a clean detached worktree regenerated and passed all 83 tests. |
| G5 local/AI routing | PASS | Ordinary Return selects only a non-provider suggestion; no-result and recent-AI Return tests prove no provider process starts; Ask remains explicit. |
| G6 legacy migration | PASS | Unit integration test verifies recoverable backup and empty replacement; real app removed `/`, stopped the crawl, preserved the full database, and cleared the migration marker. |
| G7 running-app resource safety | PASS | Updated standalone app remained idle at 0.0% CPU after migration, with no active index database and no approved roots. |

## Implementation evidence

- `LocalIndexRootPolicy` validates every root before rebuild, search, statistics, or clearing.
- `LocalIndexScope` resolves symlinks and rejects hidden components, credential/config directories, dependency trees, packages, explicit exclusions and unsupported types.
- SQL applies approved-root predicates before result limits and statistics counts, preventing stale contaminated rows from crowding current results.
- Rebuild updates rows in place and reports discovered, processed, indexed, skipped, failed, current path and up to five errors; cancellation retains the prior index.
- Persisted forbidden roots move into a durable pending-quarantine preference before any index task can start.
- Quarantine atomically moves the SQLite database plus WAL/SHM companions on the same volume, avoiding duplicate-space failure while keeping a recoverable generation.
- Provider output EOF coordination replaced a blocking termination drain found by the expanded suite; 4,000-line stdout plus 3,000-line stderr now drains before termination.

## Verification commands

- `swift test`: 85 tests, zero failures after the audit-evidence additions.
- Clean detached worktree at `3a243b2`: `xcodegen generate` passed; `swift test` built and ran 83 tests, zero failures.
- Strict Swift 6 app typecheck with complete concurrency checking: passed.
- Optimized standalone arm64 app compile: passed; `codesign --verify --deep --strict` passed after ad-hoc signing.
- `xcodebuild` remains blocked by the host CoreSimulator/Xcode mismatch recorded in Phase 0; this is not represented as a passing native Xcode gate.

## Real-app migration evidence

1. Pre-migration preference: `indexedFolderPaths = ["/"]`.
2. Pre-migration database: SQLite `quick_check=ok`, 2,932 documents, 45,697 chunks, 292 MB.
3. Updated app launch: active roots became empty; `pendingLegacyIndexQuarantinePaths` became empty; no crawl remained.
4. Active `LocalIndex.sqlite` is absent until an approved root is added.
5. Quarantined database `LocalIndex-legacy-44CE33C7-1FAD-48D8-BB20-26A216C479E0.sqlite`: `quick_check=ok`, 2,932 documents, 45,697 chunks, 292 MB, with WAL/SHM companions preserved.
6. Running app process: 0.0% CPU after migration. The earlier failed 3.3 MB backup was confirmed invalid and deleted; the original database was untouched before the successful atomic-move retry.

## Known limitations carried to later phases

- Index runs are not durable or resumable across relaunches; there is no persistent queue/generation state or FSEvents pipeline.
- Removed/deleted source rows are retained but excluded by current scope until a later generational cleanup; this is deliberate safety behavior, not final storage hygiene.
- Extraction remains UTF-8 text-only with a 2 MB limit; PDF, Office, metadata-only fallback and encrypted-file handling are absent.
- The real folder-picker rejection path and complete Settings visuals still need Phase 7 UI UAT, though model/UI code and unit gates are green.
- Xcode's native build/test service is host-blocked; SwiftPM, strict typecheck, optimized compilation, signing verification, and the running app are green.

## Grok audit

- CLI: Grok 0.2.103
- Prompt bytes: 1,359
- Prompt SHA-256: `b69a414c53a223f36af4f8abd80b248285dc6da24c5719988e7bfeec23cb0679`
- Exact CLI output before termination:

  ```text
  Verifying cited evidence against phase claims.
  ```

- Disposition: `NOT RUN`. The single invocation produced no verdict and remained
  hung for more than 90 seconds with tools, web, memory and subagents disabled;
  it was terminated. No automatic retry was made. Completion requires a later
  audit or Pablo's explicit waiver.

### User-authorized retry

- Prompt bytes: 1,530 (recorded for traceability; prompt size is not a pass/fail
  criterion under the revised audit policy)
- Prompt SHA-256: `478250427cc108ca6d8f933635d17c773bf8d108a1b93bff93f8b5733541d2b0`
- Exact response:

  ```text
  INSUFFICIENT
  1. No evidence that scope is applied before SQL limits
  2. No evidence for G3 honest state/counters
  3. Cancellation retention not shown (only rebuild/failure)
  ```

- Disposition: blocked because Grok returned `INSUFFICIENT`, not because of the
  prompt length. The scope-before-limit regression already existed but was not
  cited precisely. Two stronger integration tests were added afterward:
  `testCancelledRebuildLeavesPriorIndexSearchable` and
  `testRebuildReportsDeterministicRunCounters`. The LocalIndex suite now passes
  16/16 and the full suite passes 85/85. No further Grok call was made. Pablo
  removed fixed audit size and count caps after this run because they encouraged
  evidence omission; future audits prioritize complete decisive evidence.
